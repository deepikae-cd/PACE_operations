
/*
  ENTERPRISE_SILVER_NOTIFICATION
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('staging_notification_service') }}
  Purpose : Cleanse, deduplicate and enrich notification records.
            Adds surrogate key, standardised vocabularies, computed flags for:
            delivery success/failure, read status, send delay, retry risk,
            recipient type, and entity domain tagging.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select * from {{ ref('staging_notification_service') }}

    {% if is_incremental() %}
        where _loaded_at > (select max(loaded_timestamp) from {{ this }})
    {% endif %}

),

deduplicated as (

    select *,
           row_number() over (
               partition by notification_id
               order by _loaded_at desc
           ) as _rn
    from source

),

cleaned as (

    select
        -- Surrogate key
        sha2(concat_ws('||', notification_id, cast(_loaded_at as varchar))) as notification_sk,

        -- Natural keys (normalised)
        trim(upper(notification_id))   as notification_id,
        trim(upper(participant_id))    as participant_id,
        trim(upper(caregiver_id))      as caregiver_id,
        trim(upper(center_id))         as center_id,

        -- Recipient type — mutually exclusive classification
        case
            when participant_id is not null and caregiver_id is null     then 'PARTICIPANT'
            when caregiver_id   is not null and participant_id is null   then 'STAFF'
            when participant_id is not null and caregiver_id is not null then 'BOTH'
            else 'SYSTEM'
        end as recipient_type,

        -- Notification type (controlled vocabulary)
        case
            when upper(trim(notification_type)) in (
                'APPOINTMENT_REMINDER', 'CARE_ALERT', 'MED_REFILL',
                'COMPLIANCE_ALERT', 'FOLLOW_UP_DUE', 'LAB_RESULT',
                'TRANSPORTATION_UPDATE', 'MEAL_DELIVERY_UPDATE', 'SYSTEM_ALERT'
            ) then upper(trim(notification_type))
            when notification_type is null then 'UNKNOWN'
            else 'OTHER'
        end as notification_type,

        -- Notification category (controlled vocabulary)
        case
            when upper(trim(notification_category)) in
                ('CLINICAL', 'OPERATIONAL', 'COMPLIANCE', 'SYSTEM')
            then upper(trim(notification_category))
            when notification_category is null then 'UNKNOWN'
            else 'OTHER'
        end as notification_category,

        -- Boolean category flags — useful for dashboard filtering
        (upper(trim(notification_category)) = 'CLINICAL')     as is_clinical_flag,
        (upper(trim(notification_category)) = 'COMPLIANCE')   as is_compliance_flag,
        (upper(trim(notification_category)) = 'OPERATIONAL')  as is_operational_flag,

        -- Channel (controlled vocabulary)
        case
            when upper(trim(channel)) in
                ('SMS', 'EMAIL', 'PHONE', 'IN_APP', 'PORTAL')
            then upper(trim(channel))
            when channel is null then 'UNKNOWN'
            else 'OTHER'
        end as channel,

        -- Recipient contact (masked for PII — last 4 digits / domain only)
        case
            when recipient_phone is not null
            then concat('***-***-', right(trim(recipient_phone), 4))
        end as recipient_phone_masked,

        case
            when recipient_email is not null
            then concat('***@', split_part(trim(recipient_email), '@', 2))
        end as recipient_email_masked,

        -- Message (kept for audit; downstream marts should restrict access)
        trim(message_subject) as message_subject,
        trim(message_body)    as message_body,

        -- Related entity
        case
            when upper(trim(related_entity_type)) in (
                'APPOINTMENT', 'CLINICAL_VISIT', 'TRANSPORTATION',
                'MEDICATION', 'MEAL_DELIVERY', 'COMPLIANCE_VIOLATION'
            ) then upper(trim(related_entity_type))
            when related_entity_type is null then 'NONE'
            else 'OTHER'
        end as related_entity_type,

        trim(upper(related_entity_id)) as related_entity_id,

        -- Delivery status (controlled vocabulary)
        case
            when upper(trim(delivery_status)) in
                ('SENT', 'DELIVERED', 'FAILED', 'BOUNCED', 'READ')
            then upper(trim(delivery_status))
            when delivery_status is null then 'UNKNOWN'
            else 'OTHER'
        end as delivery_status,

        -- Boolean delivery flags
        (upper(trim(delivery_status)) = 'DELIVERED') as is_delivered_flag,
        (upper(trim(delivery_status)) = 'READ')      as is_read_flag,
        (upper(trim(delivery_status)) in ('FAILED', 'BOUNCED')) as is_failed_flag,

        -- Timestamps
        scheduled_send_at,
        sent_at,
        read_at,

        -- Send delay in minutes (scheduled vs actually sent)
        case
            when scheduled_send_at is not null and sent_at is not null
            then datediff('minute', scheduled_send_at, sent_at)
        end as send_delay_minutes,

        -- Late send flag (sent > 15 min after scheduled)
        case
            when scheduled_send_at is not null
             and sent_at is not null
             and datediff('minute', scheduled_send_at, sent_at) > 15
            then true
            else false
        end as is_late_send_flag,

        -- Time to read in hours (sent → read)
        case
            when sent_at is not null and read_at is not null
            then datediff('hour', sent_at, read_at)
        end as hours_to_read,

        -- Unread flag (delivered but never read)
        case
            when upper(trim(delivery_status)) = 'DELIVERED'
             and read_at is null
            then true
            else false
        end as is_unread_flag,

        -- Notification not yet sent (scheduled in future or stuck)
        case
            when sent_at is null
             and scheduled_send_at is not null
             and scheduled_send_at < current_timestamp()
            then true
            else false
        end as is_stuck_flag,

        -- Retry fields
        coalesce(retry_count, 0) as retry_count,

        -- High retry flag (>= 3 retries signals delivery problem)
        (coalesce(retry_count, 0) >= 3) as is_high_retry_flag,

        -- Metadata
        upper(trim(source_system))  as source_system,
        _loaded_at                  as loaded_timestamp,
        _source_file                as source_file,
        current_timestamp()         as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned