/*
 GOLD_CAREGIVER_PERFORMANCE
  ------------------------------------------------------------------------------
  Purpose:
    Aggregated caregiver-level performance metrics for reporting and dashboards.

  Grain:
    One row per caregiver per center
-------------------------------------------------------------------------------*/

select

    -- Dimensions
    f.caregiver_id,
    f.center_id,

    -- Metrics
    count(f.task_instance_id) as total_tasks,
    sum(f.task_minutes) as total_task_minutes,
    avg(f.task_minutes) as avg_task_minutes,

    -- Flags / quality
    sum(case when f.is_long_task_flag then 1 else 0 end) as long_tasks_count,

    -- Metadata
    current_timestamp as dbt_updated_timestamp

from {{ ref('fct_caregiver_activity') }} f

group by
    f.caregiver_id,
    f.center_id