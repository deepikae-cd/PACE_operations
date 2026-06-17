/*
===============================================================================
Model: gold_medication_demand
Purpose:
  Measures medication demand across centers and drug classes.

Grain:
  center_id + drug_class
===============================================================================
*/

with base as (

    select *
    from {{ ref('fct_medication') }}

),

aggregated as (

    select
        center_id,
        drug_class,

        count(*) as total_prescriptions,
        avg(days_supply) as avg_days_supply,

        sum(case when is_controlled_substance then 1 else 0 end) as controlled_count,
        sum(case when is_refill_required_flag then 1 else 0 end) as refill_needed_count

    from base
    group by 1,2

)

select
    *,
    current_timestamp() as dbt_updated_timestamp
from aggregated