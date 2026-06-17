/*
===============================================================================
Model: fct_tasks
Purpose:
  Core fact table capturing task-level activity across participants,
  caregivers, and centers.

Grain:
  One row per task instance

===============================================================================
*/

with source as (

    select *
    from {{ ref('staging_task') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by task_id
               order by _loaded_at desc
           ) as _rn
    from source

),

final as (

    select

        -- Keys
        trim(upper(task_id)) as task_id,
        trim(upper(participant_id)) as participant_id,
        trim(upper(caregiver_id)) as caregiver_id,
        trim(upper(center_id)) as center_id,

        -- Attributes
        trim(upper(task_type)) as task_type,
        trim(upper(task_status)) as task_status,

        -- Timestamps
        scheduled_at,
        started_at,
        completed_at,

        -- Metrics
        datediff('minute', started_at, completed_at) as task_duration_minutes,

        -- Flags
        (task_status = 'COMPLETED') as is_completed_flag,

        -- Metadata
        _loaded_at as loaded_timestamp,
        current_timestamp() as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from final