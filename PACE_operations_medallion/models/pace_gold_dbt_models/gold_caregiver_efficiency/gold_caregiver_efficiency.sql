/*
===============================================================================
Model: gold_caregiver_efficiency
Purpose:
  Estimates caregiver efficiency using available visit and task data.

  Note:
    Since travel/tracking data is unavailable, this model provides
    a proxy view of caregiver efficiency based on care delivery time.

Grain:
  caregiver_id
===============================================================================
*/

with visits as (

    select *
    from {{ ref('fct_idt_clinical_visit') }}

),

tasks as (

    select *
    from {{ ref('fct_tasks') }}

),

visit_agg as (

    select
        caregiver_id,

        count(*) as total_visits,
        sum(visit_duration_minutes) as total_visit_minutes,
        avg(visit_duration_minutes) as avg_visit_minutes

    from visits
    where caregiver_id is not null
    group by caregiver_id

),

task_agg as (

    select
        caregiver_id,

        count(*) as total_tasks,
        avg(task_duration_minutes) as avg_task_duration

    from tasks
    where caregiver_id is not null
    group by caregiver_id

),

final as (

    select
        v.caregiver_id,

        v.total_visits,
        v.total_visit_minutes,
        v.avg_visit_minutes,

        t.total_tasks,
        t.avg_task_duration,

        -- Efficiency proxies
        v.total_visit_minutes / nullif(v.total_visits, 0) as avg_time_per_visit,

        t.total_tasks / nullif(v.total_visits, 0) as tasks_per_visit,

        current_timestamp() as dbt_updated_timestamp

    from visit_agg v
    left join task_agg t
        on v.caregiver_id = t.caregiver_id

)

select * from final