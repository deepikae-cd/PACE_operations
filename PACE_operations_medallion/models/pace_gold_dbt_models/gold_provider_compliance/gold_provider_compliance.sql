/*
===============================================================================
MODEL NAME  : gold_provider_compliance
LAYER       : GOLD
DOMAIN      : PROVIDER / COMPLIANCE
OWNER       : DATA ENGINEERING
VERSION     : 1.1

-------------------------------------------------------------------------------
DESCRIPTION:
  Tracks provider contract lifecycle, compliance status, and risk levels.
  Provides business-friendly flags for monitoring expiring and inactive contracts.

  Supports:
    - UC-14: Provider lifecycle and credentialing
    - Compliance monitoring
    - Risk reporting

GRAIN:
  One row per provider_id

DEPENDENCIES:
  - enterprise_silver_provider
-------------------------------------------------------------------------------
*/

-- ============================================================================
-- STEP 1: SOURCE FROM SILVER
-- ============================================================================

with base as (

    select *
    from {{ ref('enterprise_silver_provider') }}

),

-- ============================================================================
-- STEP 2: BUSINESS LOGIC
-- ============================================================================

final as (

    select

        -- ✅ Surrogate key
        sha2(concat_ws('||', provider_id), 256) as provider_sk,

        -- ✅ Core identifiers
        provider_id,
        provider_name,
        center_id,

        -- ✅ Network info
        network_status,
        is_in_network_flag,
        is_preferred_flag,

        -- ✅ Contract lifecycle
        contract_start_date,
        contract_end_date,

        is_contract_active_flag,
        is_contract_expiring_soon_flag,
        days_until_contract_expiry,

        -- ✅ Compliance status
        case
            when is_contract_active_flag = false then 'INACTIVE'
            when is_contract_expiring_soon_flag then 'EXPIRING_SOON'
            else 'ACTIVE'
        end as compliance_status,

        -- ✅ Risk classification
        case
            when is_contract_active_flag = false then 'HIGH'
            when is_contract_expiring_soon_flag then 'MEDIUM'
            else 'LOW'
        end as compliance_risk_level,

        -- ✅ BI flags
        (not is_contract_active_flag or is_contract_expiring_soon_flag)
            as is_compliance_at_risk_flag,

        (is_contract_active_flag and not is_contract_expiring_soon_flag)
            as is_fully_compliant_flag,

        -- ✅ Metadata (FIXED ✅)
        source_system,
        loaded_timestamp,

        current_timestamp() as dbt_updated_timestamp

    from base

)

-- ============================================================================
-- FINAL SELECT
-- ============================================================================

select *
from final