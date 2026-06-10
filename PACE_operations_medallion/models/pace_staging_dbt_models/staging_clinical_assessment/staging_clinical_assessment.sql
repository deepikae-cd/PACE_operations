/*
  STAGING_CLINICAL_ASSESSMENT
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_clinical_assessment', 'RAW_BRONZE_CLINICAL_ASSESSMENT') }}
  Purpose : Thin staging layer — select, rename, and basic null filtering only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select
        -- Keys
        assessment_id,
        participant_id,

        -- Timestamps
        assessment_date,

        -- Raw measures (light casting allowed, no interpretation)
        cast(cognitive_score as double)  as cognitive_score,
        cast(functional_score as double) as functional_score,

        -- Descriptors
        assessment_type,
        clinician_id,

        -- Metadata
        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_clinical_assessment', 'RAW_BRONZE_CLINICAL_ASSESSMENT') }}

),

filtered as (

    -- Drop unusable records only
    select *
    from source
    where assessment_id  is not null
      and participant_id is not null

)

select * from filtered