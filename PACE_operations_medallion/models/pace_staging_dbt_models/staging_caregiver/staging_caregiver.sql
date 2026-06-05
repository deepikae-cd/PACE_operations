/*
  STG_CAREGIVER
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_caregiver', 'RAW_CAREGIVER') }}
  Purpose : Thin staging layer — select, rename, and basic null filtering only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/



with source as (

    select
        -- Keys
        caregiver_id,
        center_id,
        supervisor_id,

        -- Personal
        first_name,
        last_name,

        -- Role
        caregiver_type,
        specialty,

        -- License
        license_number,
        license_state,
        license_expiry_date,

        -- Employment
        hire_date,
        termination_date,
        employment_status,
        max_participant_load,

        -- Metadata
        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_caregiver', 'RAW_CAREGIVER') }}

),

filtered as (

    -- Drop records that can never be meaningful downstream
    select *
    from source
    where caregiver_id is not null

)

select * from filtered