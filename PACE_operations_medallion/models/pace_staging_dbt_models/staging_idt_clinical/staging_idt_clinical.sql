/*
  STAGING_CLINICAL_VISIT
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_clinical_visit', 'RAW_CLINICAL_VISIT') }}
  Purpose : Thin staging layer — select, rename, and basic null filtering only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/


with source as (

    select
        -- Keys
        visit_id,
        appointment_id,
        participant_id,
        provider_id,
        caregiver_id,
        center_id,

        -- Visit descriptors (raw — no business logic here)
        visit_type,
        location_type,
        chief_complaint,

        -- Diagnosis (raw codes — no parsing here)
        primary_diagnosis_code,
        primary_diagnosis_desc,
        secondary_diagnosis_codes,

        -- Procedures & medications (raw pipe-delimited — no parsing here)
        procedures_performed,
        medications_prescribed,

        -- Vitals (raw — no range validation here)
        vitals_blood_pressure,
        vitals_heart_rate,
        vitals_temperature,
        vitals_weight_lbs,
        vitals_o2_saturation,

        -- Clinical notes
        clinical_notes,

        -- Follow-up
        follow_up_required,
        follow_up_timeframe_days,

        -- Timestamps & duration
        visit_date,
        visit_duration_minutes,

        -- Metadata
        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_clinical_visit', 'RAW_CLINICAL_VISIT') }}

),

filtered as (

    -- Drop records that can never be meaningful downstream
    select *
    from source
    where visit_id       is not null
      and participant_id is not null

)

select * from filtered