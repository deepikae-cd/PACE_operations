/*
  STAGING_PARTICIPANT
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_participant', 'RAW_PARTICIPANT') }}
  Purpose : Thin staging layer — select, rename, and basic null filtering only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/


with source as (

    select
        -- Keys
        participant_id,
        center_id,
        insurance_id,
        medicare_id,
        medicaid_id,

        -- Demographics (raw — no business logic here)
        first_name,
        last_name,
        date_of_birth,
        gender,
        preferred_language,

        -- Enrollment
        enrollment_date,
        disenrollment_date,
        program_status,

        -- Clinical
        primary_diagnosis,
        secondary_diagnoses,

        -- Address
        address_line1,
        address_line2,
        city,
        state,
        zip_code,

        -- Contact
        phone_number,
        emergency_contact_name,
        emergency_contact_phone,
        emergency_contact_relation,

        -- Metadata
        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_participant', 'RAW_PARTICIPANT') }}

),

filtered as (

    -- Drop records that can never be meaningful downstream
    select *
    from source
    where participant_id is not null

)

select * from filtered