/*
  MODEL: GOLD_MEDICATION_COST
  ------------------------------------------------------------------------------
  PURPOSE:
    Provides medication cost analytics for financial tracking and optimization.

  GRAIN:
    1 row per participant_id
*/

with cost_metrics as (

    select
        participant_id,

        count(*) as total_medications,
        sum(total_cost) as total_cost,
        avg(total_cost) as avg_cost,

        sum(case when cost_tier = 'HIGH' then 1 else 0 end) as high_cost_meds

    from {{ ref('enterprise_silver_medication') }}
    group by participant_id

)

select
    *,
    high_cost_meds / nullif(total_medications, 0) as high_cost_rate,
    current_timestamp() as dbt_updated_timestamp

from cost_metrics