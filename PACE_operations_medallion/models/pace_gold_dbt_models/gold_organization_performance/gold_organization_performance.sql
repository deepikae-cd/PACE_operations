/*
===============================================================================
Model: gold_organization_performance
Purpose:
  Organization-level KPI rollup across all centers.

Grain:
  organization_id
===============================================================================
*/

with base as (

    select *
    from {{ ref('staging_organization') }}

),

aggregated as (

    select
        organization_id,

        count(distinct center_id) as total_centers,
        sum(enrolled_count) as total_enrolled,
        sum(enrollment_capacity) as total_capacity,

        avg(quality_rating) as avg_quality_rating,

        max(accreditation_status) as accreditation_status

    from base
    group by organization_id

),

final as (

    select
        *,

        total_enrolled / nullif(total_capacity, 0) as utilization_rate,
        current_timestamp() as dbt_updated_timestamp

    from aggregated

)

select * from final