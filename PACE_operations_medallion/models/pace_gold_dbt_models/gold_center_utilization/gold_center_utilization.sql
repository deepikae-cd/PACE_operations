/*
===============================================================================
Model: gold_center_utilization
Purpose:
  Provides center-level capacity, enrollment, and utilization metrics.

Grain:
  1 row per center_id
===============================================================================
*/

with base as (

    select *
    from {{ ref('enterprise_silver_organization') }}

),

aggregated as (

    select
        center_id,

        -- Capacity metrics
        max(enrollment_capacity) as enrollment_capacity,
        max(enrolled_count) as enrolled_count,
        max(population_served) as population_served,
        max(eligible_population) as eligible_population,

        -- Derived metrics
        max(enrollment_utilisation_rate) as utilization_rate,

        max(eligible_not_enrolled_count) as eligible_not_enrolled_count,

        max(enrollment_capacity_status) as capacity_status,

        -- Flags
        max(is_at_capacity_flag) as is_at_capacity_flag

    from base
    group by center_id

),

final as (

    select
        *,
        current_timestamp() as dbt_updated_timestamp
    from aggregated

)

select * from final
