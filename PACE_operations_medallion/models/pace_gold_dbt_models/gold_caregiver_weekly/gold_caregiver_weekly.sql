/*
  GOLD_CAREGIVER_WEEKLY
  ------------------------------------------------------------------------------
  Purpose:
    Provides weekly aggregated caregiver activity metrics for trend analysis
    and reporting.

  Grain:
    One row per caregiver per center per week
------------------------------------------------------------------------------*/

select
    caregiver_id,
    center_id,
    date_trunc('week', activity_date) as week_start_date,

    sum(daily_tasks) as weekly_tasks,
    sum(daily_task_minutes) as weekly_task_minutes,

    current_timestamp as dbt_updated_timestamp

from {{ ref('gold_caregiver_daily') }}

group by
    caregiver_id,
    center_id,
    date_trunc('week', activity_date)
