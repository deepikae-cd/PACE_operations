/*
===============================================================================
MODEL NAME  : gold_provider_compliance
LAYER       : GOLD
DOMAIN      : PROVIDER / COMPLIANCE
OWNER       : DATA ENGINEERING
VERSION     : 1.1

-------------------------------------------------------------------------------
DESCRIPTION:
  Provides provider-level compliance tracking including contract lifecycle,
  expiry monitoring, and risk classification.

  This model enriches provider data with business logic to support:
    - UC-14: Provider lifecycle and credentialing
    - Compliance reporting
    - Operational risk monitoring

GRAIN:
  One row per provider_id

DEPENDENCIES:
  - enterprise_silver_provider
  - gold_provider_credential (future integration)
-------------------------------------------------------------------------------
*/

{{ config(
    materialized='table',
    tags=['gold', 'provider', 'compliance'],
    cluster_by=['center_id'],
    persist_docs={"relation": true, "columns": true}
) }}

with base as (

    select *
    from {{ ref('enterprise_silver_provider') }}

),

final as (

    select

        -- Surrogate Key
        sha2(concat_ws('||', provider_id), 256) as provider_sk,

        -- Business keys
        provider_id,
        provider_name,
        center_id,

        -- Network
        network_status,
        is_in_network_flag,
        is_preferred_flag,

        -- Contract
        contract_start_date,
        contract_end_date,

        is_contract_active_flag,
        is_contract_expiring_soon_flag,
        days_until_contract_expiry,

        -- ✅ Compliance classification
        case
            when is_contract_active_flag = false then 'INACTIVE'
            when is_contract_expiring_soon_flag then 'EXPIRING_SOON'
            else 'ACTIVE'
        end as compliance_status,

        -- ✅ Risk level (NEW)
        case
            when is_contract_active_flag = false then 'HIGH'
            when is_contract_expiring_soon_flag then 'MEDIUM'
            else 'LOW'
        end as compliance_risk_level,

        -- ✅ Flags for BI / filtering
        (not is_contract_active_flag or is_contract_expiring_soon_flag)
            as is_compliance_at_risk_flag,

        (is_contract_active_flag = true and is_contract_expiring_soon_flag = false)
            as is_fully_compliant_flag,

        -- Metadata
        upper(trim(source_system)) as source_system,
        _loaded_at as loaded_timestamp,

        current_timestamp() as dbt_updated_timestamp

    from base

)

select * from final
