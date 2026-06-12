/*
  GOLD_SITE_LEVEL_TASK_VARIANCE
  ──────────────────────────────────────────────────────────────────────────────
  Purpose : Analyze variation in task duration across centers and task types.
            Helps identify operational inefficiencies, standardization gaps,
            and performance differences across sites.

  Grain   : One row per (center_id, task_type)

  Inputs  :
            - enterprise_silver_task_instance  (actual task execution data)
            - enterprise_silver_task_template  (task classification)
            - enterprise_silver_pace_center    (site metadata)

  Metrics :
            - avg_time → Average duration per task
            - min_time → Minimum observed duration
            - max_time → Maximum observed duration

  Usage   :
            - Power BI dashboards for site comparison
            - Identify high-variance task types
            - Drive process standardization efforts

  Notes   :
            - Assumes duration_minutes is clean and standardized in Silver
            - Extreme values may indicate data issues (outliers)
  ──────────────────────────────────────────────────────────────────────────────
*/

select
    -- Dimensions
    c.center_id,
    tt.task_type,

    -- Metrics
    avg(t.duration_minutes) as avg_time,
    min(t.duration_minutes) as min_time,
    max(t.duration_minutes) as max_time

from {{ ref('enterprise_silver_task_instance') }} t

join {{ ref('enterprise_silver_task_template') }} tt
    on t.task_template_id = tt.task_template_id

join {{ ref('enterprise_silver_pace_center') }} c
    on t.center_id = c.center_id

group by
    c.center_id,
    tt.task_type