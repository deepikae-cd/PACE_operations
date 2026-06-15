/*
  GOLD_CAREGIVER_UTILIZATION
  ------------------------------------------------------------------------------
  Purpose:
    Provides aggregated caregiver utilization metrics based on caregiving activity.

  Grain:
    One row per caregiver per center

  Description:
    This model summarizes caregiver workload by calculating total task time,
    number of tasks, and average duration. It helps evaluate how effectively
    caregivers are utilized.

  Key Metrics:
    - total_task_minutes → total caregiving effort
    - total_tasks        → volume of work
    - avg_task_minutes   → efficiency indicator

  Use Cases:
    - Caregiver utilization analysis
    - Workload balancing
    - Performance monitoring
------------------------------------------------------------------------------*/

select
    caregiver_id,
    center_id,

    -- Aggregated workload metrics
    count(task_instance_id) as total_tasks,
    sum(task_minutes) as total_task_minutes,

    -- Average effort per task
    avg(task_minutes) as avg_task_minutes,

    -- Metadata
    current_timestamp as dbt_updated_timestamp

from {{ ref('fct_caregiver_activity') }}

group by
    caregiver_id,
    center_id