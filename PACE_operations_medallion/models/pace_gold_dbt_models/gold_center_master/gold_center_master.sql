/*
===============================================================================
Model: gold_center_master
Purpose:
  Unified dimension combining center and organization attributes.

Grain:
  1 row per center_id
===============================================================================
*/

with org as (

    select *
    from {{ ref('enterprise_silver_organization') }}

),

center as (

    select *
    from {{ ref('enterprise_silver_pace_center') }}

),

final as (

    select
        c.center_id,

        -- Center attributes
        c.center_name,
        c.region,

        -- Organization attributes
        o.organization_id,
        o.organization_name,
        o.organization_type,

        o.center_city,
        o.center_state,
        o.center_zip_code,

        o.center_full_address,

        o.center_status,
        o.is_center_active_flag,

        current_timestamp() as dbt_updated_timestamp

    from center c
    left join org o
        on c.center_id = o.center_id

)

select * from final