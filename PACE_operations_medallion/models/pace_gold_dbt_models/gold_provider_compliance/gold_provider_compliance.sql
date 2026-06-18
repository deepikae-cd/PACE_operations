/*
===============================================================================
Model: gold_provider_compliance
Purpose:
  Tracks contract lifecycle, expiry, and compliance risk.

Grain:
  provider_id
===============================================================================
*/

with base as (

    select *
    from {{ ref('enterprise_silver_provider') }}

),

final as (

    select

        provider_id,
        provider_name,
        center_id,

        network_status,
        is_in_network_flag,
        is_preferred_flag,

        contract_start_date,
        contract_end_date,

        is_contract_active_flag,
        is_contract_expiring_soon_flag,
        days_until_contract_expiry,

        -- 🚩 Compliance flags
        case
            when is_contract_active_flag = false then 'INACTIVE'
            when is_contract_expiring_soon_flag then 'EXPIRING_SOON'
            else 'ACTIVE'
        end as compliance_status,

        current_timestamp() as dbt_updated_timestamp

    from base

)

select * from final