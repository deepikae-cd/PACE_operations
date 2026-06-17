/*
===============================================================================
Model: fct_visits
Purpose:
  Captures visit-level activity performed by caregivers for participants.

Grain:
  One row per visit_id

Inputs:
  - staging_visit

===============================================================================
*/

with source as (

    select *
    from {{ ref('staging_visit') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by visit_id
               order by _loaded_at desc
           ) as _rn
    from source

),

final as (

    select

        -- Keys
        trim(upper(visit_id)) as visit_id,
        trim(upper(participant_id)) as participant_id,
        trim(upper(caregiver_id)) as caregiver_id,
        trim(upper(center_id)) as center_id,

        -- Attributes
        trim(upper(visit_type)) as visit_type,

        -- Timestamps
        scheduled_at,
        started_at,
        completed_at,

        -- Metrics
        datediff('minute', started_at, completed_at) as visit_duration_minutes,

        date_trunc('day', completed_at) as visit_date,

        -- Flags
        (completed_at is not null) as is_completed_flag,

        -- Metadata
        _loaded_at as loaded_timestamp,
        _source_file as source_file,
        current_timestamp() as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from final