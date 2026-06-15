/*
  MART_CENTER_OPERATIONS
  ------------------------------------------------------------------------------
  Purpose:
    Provides center-level operational metrics for planning and reporting.

  Grain:
    One row per center

  Use Cases:
    - Capacity planning
    - Operational dashboards
    - Workload monitoring
------------------------------------------------------------------------------*/

select

    -- Dimension
    center_id,

    -- Metrics
    count(distinct caregiver_id) as total_caregivers,
    count(task_instance_id) as total_tasks,
    sum(task_minutes) as total_task_minutes,

    -- Metadata
    current_timestamp as dbt_updated_timestamp

from {{ ref('fct_caregiver_activity') }}

group by center_id