/*
  STAGING_NOTIFICATION_SERVICE
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_notification', 'RAW_NOTIFICATION') }}
  Purpose : Thin staging layer — select, rename, and basic null filtering only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/


with source as (

    select
        -- Keys
        notification_id,
        participant_id,
        caregiver_id,
        center_id,

        -- Related entity linkage
        related_entity_type,
        related_entity_id,

        -- Notification descriptors (raw — no business logic here)
        notification_type,
        notification_category,
        channel,
        delivery_status,

        -- Recipient contact (raw)
        recipient_phone,
        recipient_email,

        -- Message content
        message_subject,
        message_body,

        -- Timestamps
        scheduled_send_at,
        sent_at,
        read_at,

        -- Retry
        retry_count,

        -- Metadata
        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_notification', 'RAW_NOTIFICATION') }}

),

filtered as (

    -- Drop records that can never be meaningful downstream
    select *
    from source
    where notification_id is not null

)

select * from filtered