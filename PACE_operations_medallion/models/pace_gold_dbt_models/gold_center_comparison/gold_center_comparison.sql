/*
===============================================================================
Model: gold_center_comparison
Purpose:
  Benchmark centers within the same organization.

Grain:
  center_id
===============================================================================
*/

with base as (

    select *
    from {{ ref('enterprise_silver_organization') }}

),

aggregated as (

    select
        organization_id,
        center_id,

        avg(enrollment_utilisation_rate) as utilization_rate,
        avg(quality_rating) as avg_quality_rating,

        count(*) as record_count

    from base
    group by organization_id, center_id

),

ranked as (

    select
        *,
        rank() over (
            partition by organization_id
            order by utilization_rate desc
        ) as utilization_rank

    from aggregated

),

final as (

    select
        *,
        current_timestamp() as dbt_updated_timestamp
    from ranked

)

select * from final