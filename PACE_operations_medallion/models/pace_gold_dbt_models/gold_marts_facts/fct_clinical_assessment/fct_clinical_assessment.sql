/*
===============================================================================
Model: fct_clinical_assessment
Purpose:
  Captures clinical assessments performed for participants, including
  cognitive and functional indicators.

Grain:
  One row per assessment_id
===============================================================================
*/

with source as (

    select *
    from {{ ref('staging_clinical_assessment') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by assessment_id
               order by _loaded_at desc
           ) as _rn
    from source

),

final as (

    select

        -- 🔑 Keys
        trim(upper(assessment_id)) as assessment_id,
        trim(upper(participant_id)) as participant_id,
        trim(upper(clinician_id)) as clinician_id,

        -- 📅 Time
        assessment_date,
        date_trunc('day', assessment_date) as assessment_day,

        -- 📊 Metrics
        cognitive_score,
        functional_score,

        -- 🧠 Derived indicators
        case
            when cognitive_score is null then 'UNKNOWN'
            when cognitive_score >= 80 then 'HIGH'
            when cognitive_score >= 50 then 'MODERATE'
            else 'LOW'
        end as cognitive_band,

        case
            when functional_score is null then 'UNKNOWN'
            when functional_score >= 80 then 'HIGH'
            when functional_score >= 50 then 'MODERATE'
            else 'LOW'
        end as functional_band,

        -- 🧾 Metadata
        source_system,
        _loaded_at as loaded_timestamp,
        current_timestamp() as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from final