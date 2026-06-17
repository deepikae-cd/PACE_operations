/*
===============================================================================
Model: gold_clinical_performance
Purpose:
  Clinical KPIs at center level.

Grain:
  center_id + date
===============================================================================
*/

with base as (

    select *
    from {{ ref('fct_idt_clinical_visit') }}

),

aggregated as (

    select
        center_id,
        visit_date,

        count(*) as total_visits,
        avg(visit_duration_minutes) as avg_visit_duration,

        sum(case when is_long_visit_flag then 1 else 0 end) as long_visit_count,
        sum(case when follow_up_required then 1 else 0 end) as follow_up_count

    from base
    group by 1,2

)

select
    *,
    follow_up_count / nullif(total_visits, 0) as follow_up_rate,
    current_timestamp() as dbt_updated_timestamp
from aggregated