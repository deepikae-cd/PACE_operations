/*
===============================================================================
Model: gold_medication_complexity
Purpose:
  Measures medication complexity per participant for dispenser sizing.

Grain:
  participant_id
===============================================================================
*/

with base as (

    select *
    from {{ ref('fct_medication') }}

),

aggregated as (

    select
        participant_id,

        count(*) as total_medications,
        count(distinct drug_class) as unique_drug_classes,

        avg(days_supply) as avg_days_supply,

        sum(case when is_controlled_substance then 1 else 0 end) as controlled_medications,

        sum(case when is_refill_required_flag then 1 else 0 end) as refill_pressure

    from base
    group by participant_id

),

final as (

    select
        *,

        -- Complexity score (simple weighted metric)
        (total_medications
         + unique_drug_classes
         + controlled_medications
         + refill_pressure) as medication_complexity_score,

        current_timestamp() as dbt_updated_timestamp

    from aggregated

)

select * from final
