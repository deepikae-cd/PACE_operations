/*
===============================================================================
Model: fact_tasks
Purpose:
  Core fact table capturing task execution events enriched with task metadata.

Grain:
  One row per task_instance_id

Inputs:
  - staging_task_instance (execution details)
  - staging_task_template (task metadata)

Key Features:
  - Joins task executions with template metadata
  - Computes task duration
  - Standardizes keys
  - Adds classification fields for analytics

===============================================================================
*/

with task_instance as (

    select *
    from {{ ref('staging_task_instance') }}

),

task_template as (

    select *
    from {{ ref('staging_task_template') }}

),

joined as (

    select

        -- Keys
        ti.task_instance_id        as task_id,
        ti.care_plan_activity_id,
        ti.task_template_id,

        -- Template enrichment
        tt.task_name,
        tt.task_category,

        -- Metrics
        ti.actual_duration_minutes,
        ti.performed_at,

        -- Derived time fields
        date_trunc('day', ti.performed_at) as performed_date,

        -- Flags
        (ti.actual_duration_minutes is not null) as is_completed_flag,

        -- Metadata
        ti.source_system,
        ti.loaded_at,
        ti.source_file,

        current_timestamp() as dbt_updated_timestamp

    from task_instance ti
    left join task_template tt
        on ti.task_template_id = tt.task_template_id

),

final as (

    select
        *,
        
        -- Optional normalization for analytics
        coalesce(task_category, 'UNKNOWN') as task_category_clean,
        coalesce(task_name, 'UNKNOWN') as task_name_clean

    from joined

)

select * from final
