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

with base as (

    select *
    from {{ ref('fct_idt_clinical_visit') }}

),

aggregated as (

    select
        caregiver_id,

        count(*) as total_visits,
        sum(visit_duration_minutes) as total_visit_minutes,
        avg(visit_duration_minutes) as avg_visit_minutes

    from base
    where caregiver_id is not null
    group by caregiver_id

)

select
    *,
    total_visit_minutes / nullif(total_visits, 0) as avg_time_per_visit,
    current_timestamp() as dbt_updated_timestamp
from aggregated
