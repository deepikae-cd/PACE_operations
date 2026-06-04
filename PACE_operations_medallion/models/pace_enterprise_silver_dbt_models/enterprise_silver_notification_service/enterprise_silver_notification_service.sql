/*
  ENTERPRISE_SILVER_NOTIFICATION
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_notification', 'RAW_NOTIFICATION') }}

  Purpose : Cleanse, deduplicate, and standardise notification delivery records.
            Normalises notification type, category, channel, and delivery status.
            Computes delivery flags and latency metrics for analysis.

  Logic   :
            - Deduplicates using latest _loaded_at per notification_id
            - Standardises categorical fields (type, category, channel, status)
            - Generates surrogate key (notification_sk)
            - Flags delivery outcomes (is_delivered_flag, is_failed_flag)
            - Computes delivery latency in minutes (scheduled → sent)
            - Cleans contact fields (phone, email)

  Grain   : One record per notification_id (latest version)

  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select * from {{ source('bronze_notification', 'RAW_NOTIFICATION') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by notification_id
               order by _loaded_at desc
           ) as _rn
    from source
    where notification_id   is not null
      and scheduled_send_at is not null

),

cleaned as (

    select
        sha2(concat_ws('||', notification_id, cast(_loaded_at as varchar))) as notification_sk,
        trim(upper(notification_id)) as notification_id,
        trim(upper(participant_id))  as participant_id,
        trim(upper(caregiver_id))    as caregiver_id,
        trim(upper(center_id))       as center_id,

        case
            when upper(trim(notification_type)) in
                ('APPOINTMENT_REMINDER','CARE_ALERT','MED_REFILL',
                 'COMPLIANCE_ALERT','TRANSPORTATION_UPDATE','MEAL_UPDATE')
            then upper(trim(notification_type))
            when notification_type is null then 'UNKNOWN'
            else 'OTHER'
        end as notification_type,

        case
            when upper(trim(notification_category)) in
                ('CLINICAL','OPERATIONAL','COMPLIANCE','SYSTEM')
            then upper(trim(notification_category))
            else 'UNKNOWN'
        end as notification_category,

        case
            when upper(trim(channel)) in
                ('SMS','EMAIL','PHONE','IN_APP','PORTAL')
            then upper(trim(channel))
            else 'UNKNOWN'
        end as channel,

        case
            when upper(trim(delivery_status)) in
                ('SENT','DELIVERED','FAILED','BOUNCED','READ')
            then upper(trim(delivery_status))
            else 'UNKNOWN'
        end as delivery_status,

        (upper(trim(delivery_status)) in ('DELIVERED','READ')) as is_delivered_flag,
        (upper(trim(delivery_status)) in ('FAILED','BOUNCED')) as is_failed_flag,
        scheduled_send_at,
        sent_at,
        read_at,

        case
            when sent_at is not null and scheduled_send_at is not null
            then datediff('minute', scheduled_send_at, sent_at)
        end as delivery_latency_minutes,

        trim(message_subject) as message_subject,
        trim(message_body)    as message_body,

        upper(trim(related_entity_type)) as related_entity_type,
        trim(upper(related_entity_id))   as related_entity_id,

        coalesce(try_cast(retry_count as number(3,0)), 0) as retry_count,

        regexp_replace(recipient_phone, '[^0-9+]', '') as recipient_phone,
        lower(trim(recipient_email)) as recipient_email,

        upper(trim(source_system)) as source_system,
        _loaded_at                as loaded_timestamp,
        current_timestamp()       as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned