/*
  MODEL: GOLD_CAREGIVER_TASK_PERFORMANCE
  ------------------------------------------------------------------------------
  PURPOSE:
    Provides aggregated caregiver-level task performance metrics for operational
    monitoring, workload analysis, and performance reporting.

  GRAIN:
    1 row per caregiver_id, center_id

  SOURCE:
    {{ ref('fct_caregiver_activity') }}

  METRICS:
    - total_tasks           → total tasks completed by caregiver
    - total_task_minutes    → total time spent on tasks
    - avg_task_minutes      → average time per task
    - long_tasks_count      → number of tasks exceeding expected duration

  USE CASES:
    - Workforce workload analysis
    - Caregiver efficiency evaluation
    - Operational dashboards
    - Task duration monitoring

  NOTES:
    - Uses curated caregiver activity fact table
    - Designed for BI/dashboard consumption
*/

with caregiver_task_metrics as (

    /*
      Aggregate caregiver task-level metrics
    */
    select
        -- Dimensions
        caregiver_id,
        center_id,

        -- Core metrics
        count(task_instance_id) as total_tasks,
        sum(task_minutes) as total_task_minutes,
        avg(task_minutes) as avg_task_minutes,

        -- Quality indicator (long tasks)
        sum(
            case
                when is_long_task_flag then 1
                else 0
            end
        ) as long_tasks_count

    from {{ ref('fct_caregiver_activity') }}

    group by caregiver_id, center_id

)

select
    caregiver_id,
    center_id,
    total_tasks,
    total_task_minutes,
    avg_task_minutes,
    long_tasks_count,

    /*
      Derived KPIs (optional, useful in production dashboards)
    */

    -- Average minutes per caregiver workload
    total_task_minutes / nullif(total_tasks, 0) as avg_minutes_per_task,

    -- Percentage of long tasks
    long_tasks_count / nullif(total_tasks, 0) as long_task_rate,

    -- Metadata
    current_timestamp() as dbt_updated_timestamp

from caregiver_task_metrics