/*
  STAGING_APPOINTMENT
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_appointment', 'RAW_APPOINTMENT') }}
  Purpose : Thin staging layer — rename, cast, and basic null filtering only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select
        -- Keys
        appointment_id,
        participant_id,
        caregiver_id,
        provider_id,
        center_id,
        parent_appointment_id,

        -- Descriptors (raw — no business logic here)
        appointment_type,
        appointment_status,
        cancellation_reason,
        location_type,
        location_address,
        recurrence_pattern,
        notes,

        -- Timestamps
        scheduled_date,
        actual_start_time,
        actual_end_time,

        -- Metadata
        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_appointment', 'RAW_APPOINTMENT') }}

),

filtered as (

    -- Drop records that can never be meaningful downstream
    select *
    from source
    where appointment_id is not null
      and participant_id is not null
      and scheduled_date  is not null

)

select * from filtered