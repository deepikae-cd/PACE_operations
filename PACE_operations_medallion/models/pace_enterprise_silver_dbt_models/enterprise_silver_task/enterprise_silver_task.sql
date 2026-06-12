/*
===============================================================================
Model       : enterprise_silver_task_with_center
Layer       : Silver
Description :
  Enriches task execution data with PACE center information by linking
  task instances to care plan activities.

  This model enables site-level analytics by attaching center_id to each
  task execution record, making it suitable for aggregation in Gold layer.

Grain:
  One row per task_instance_id

Inputs:
  - enterprise_silver_task
  - enterprise_silver_careplan_activity

Key Features:
  - Adds center_id to task data for site-level reporting
  - Preserves task-level granularity
  - Retains task classification (task_name, task_category)
  - Enables downstream models such as:
        • gold_site_level_task_variance
        • gold_home_care_task_breakdown

Usage:
  - Power BI dashboards (site efficiency, task comparison)
  - Operational analytics (center-wise performance)
  - Task standardization analysis

Notes:
  - left join ensures task records are not dropped if care_plan_activity is missing
  - center_id may be NULL if mapping is unavailable (data quality check recommended)

===============================================================================
*/

select

    -- Keys
    t.task_instance_id,
    t.care_plan_activity_id,
    t.task_template_id,

    -- Center ✅ CRITICAL for site analytics
    cpa.center_id,

    -- Task details
    t.task_name,
    t.task_category,

    -- Metrics
    t.duration_minutes,

    -- Time
    t.performed_at

from {{ ref('enterprise_silver_task') }} t

left join {{ ref('enterprise_silver_careplan_activity') }} cpa
    on t.care_plan_activity_id = cpa.care_plan_activity_id
