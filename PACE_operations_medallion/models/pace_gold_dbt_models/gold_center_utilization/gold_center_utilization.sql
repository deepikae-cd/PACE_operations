/*
===============================================================================
Model: gold_center_utilization
Purpose:
  Capacity and utilization metrics at the center level.

Grain:
  center_id
===============================================================================
*/

with base as (

    select *
    from {{ ref('staging_organization') }}

),

final as (

    select
        center_id,

        max(enrollment_capacity) as enrollment_capacity,
        max(enrolled_count) as enrolled_count,
        max(population_served) as population_served,
        max(eligible_population) as eligible_population,

        enrolled_count / nullif(enrollment_capacity, 0) as utilization_rate,
        enrolled_count / nullif(eligible_population, 0) as enrollment_conversion_rate,

        current_timestamp() as dbt_updated_timestamp

    from base
    group by center_id, enrolled_count

)

select * from final