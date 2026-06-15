/*
  GOLD_CAREGIVER_DAILY
  ------------------------------------------------------------------------------
  Purpose:
    Provides daily aggregated caregiver activity metrics for time-series analysis.

  Grain:
    One row per caregiver per center per activity_date

  Description:
    This model summarizes caregiver activity data at a daily level,
    enabling trend analysis, workload monitoring, and operational reporting.

  Key Metrics:
    - daily_tasks        → number of tasks performed per day
    - daily_task_minutes → total caregiving time per day

  Use Cases:
    - Daily workload tracking
    - Trend analysis (weekly/monthly)
    - Peak vs low activity identification
------------------------------------------------------------------------------*/

select
    caregiver_id,
    center_id,
    date(performed_at) as activity_date,

    count(task_instance_id) as daily_tasks,
    sum(task_minutes) as daily_task_minutes,

    current_timestamp as dbt_updated_timestamp

from {{ ref('fct_caregiver_activity') }}

group by
    caregiver_id,
    center_id,
    date(performed_at)
