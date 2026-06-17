/*
===============================================================================
Model: gold_organization_compliance
Purpose:
  Tracks compliance, accreditation, and audit readiness.

Grain:
  organization_id
===============================================================================
*/

with base as (

    select *
    from {{ ref('enterprise_silver_organization') }}

),

aggregated as (

    select
        organization_id,

        max(accreditation_status) as accreditation_status,
        max(is_accredited_flag) as is_accredited_flag,

        max(is_accreditation_expired_flag) as is_expired,
        max(is_accreditation_expiring_soon_flag) as is_expiring_soon,

        max(is_contract_active_flag) as is_contract_active,

        max(is_cms_audit_overdue_flag) as cms_audit_overdue,
        max(is_state_audit_overdue_flag) as state_audit_overdue

    from base
    group by organization_id

),

final as (

    select
        *,
        current_timestamp() as dbt_updated_timestamp
    from aggregated

)

select * from final
