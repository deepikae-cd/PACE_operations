/*
  STAGING_CAREGIVER_ASSIGNMENT
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_caregiver', 'RAW_CAREGIVER_ASSIGNMENT') }}
  Purpose : Thin staging layer — select, rename, and basic null filtering only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/


with source as (

    select
        -- Keys
        assignment_id,
        caregiver_id,
        participant_id,

        -- Descriptors (raw — no business logic here)
        assignment_type,
        is_active,

        -- Dates
        effective_date,
        end_date,

        -- Metadata
        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_caregiver', 'RAW_CAREGIVER_ASSIGNMENT') }}

),

filtered as (

    -- Drop records that can never be meaningful downstream
    select *
    from source
    where assignment_id  is not null
      and caregiver_id   is not null
      and participant_id is not null

)

select * from filtered