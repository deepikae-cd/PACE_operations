/*
===============================================================================
Model: gold_organization_performance
Purpose:
  Aggregates performance metrics at the organization level across centers.

Grain:
  1 row per organization_id
===============================================================================
*/

with base as (

    select *
    from {{ ref('enterprise_silver_organization') }}

),

aggregated as (

    select
        organization_id,

        -- Structural metrics
        count(distinct center_id) as total_centers,
        count(distinct service_area_id) as total_service_areas,

        -- Enrollment metrics
        sum(enrolled_count) as total_enrolled,
        sum(enrollment_capacity) as total_capacity,

        -- Quality & compliance
        avg(quality_rating) as avg_quality_rating,
        max(accreditation_status) as accreditation_status,

        max(is_accreditation_expired_flag) as is_accreditation_expired_flag,
        max(is_contract_active_flag) as is_contract_active_flag,

        max(is_cms_audit_overdue_flag) as is_cms_audit_overdue_flag,
        max(is_state_audit_overdue_flag) as is_state_audit_overdue_flag

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
