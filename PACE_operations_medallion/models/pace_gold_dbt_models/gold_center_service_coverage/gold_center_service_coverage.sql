/*
===============================================================================
Model: gold_center_service_coverage
Purpose:
  Provides geographic and service coverage metrics.

Grain:
  center_id + service_area_id
===============================================================================
*/

with base as (

    select *
    from {{ ref('enterprise_silver_organization') }}

),

final as (

    select
        center_id,
        service_area_id,

        service_area_name,
        service_area_type,

        coverage_radius_miles,
        state_served,

        zip_codes_served,
        counties_served,

        current_timestamp() as dbt_updated_timestamp

    from base

)

select * from final
