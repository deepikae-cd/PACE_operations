/*
===============================================================================
MODEL NAME  : gold_identity_resolution
LAYER       : GOLD
DOMAIN      : IDENTITY / MASTER DATA
OWNER       : DATA ENGINEERING
VERSION     : 1.1

-------------------------------------------------------------------------------
DESCRIPTION:
  Gold-layer identity resolution model that standardizes and links participant
  identities across multiple systems (EHR, CareLiva, etc.).

  Provides:
    - Unified identity mappings
    - Match confidence scoring
    - Cross-system linkage indicators

  Supports:
    - UC-15: CareLiva and EHR reconciliation
    - Cross-system joins
    - Deduplication and analytics consistency

GRAIN:
  One row per participant_id per source_system

DEPENDENCIES:
  - enterprise_silver_identity_link
-------------------------------------------------------------------------------
*/

-- ============================================================================
-- STEP 1: SOURCE FROM SILVER (standardized + deduplicated input)
-- ============================================================================

with base as (

    select *
    from {{ ref('enterprise_silver_identity_link') }}

),

-- ============================================================================
-- STEP 2: BUSINESS ENRICHMENT AND STANDARDIZATION
-- ============================================================================

final as (

    select

        -- ✅ Surrogate key (stable gold identity key)
        sha2(concat_ws('||', participant_id, source_system), 256)
            as identity_sk,

        -- ✅ Core identifiers
        participant_id,
        source_system,

        -- ✅ Cross-system IDs
        ehr_id,
        careliva_id,

        -- ✅ Matching logic
        match_type,
        match_confidence_score,

        -- ✅ Standardized confidence classification
        case
            when match_confidence_score >= 0.9 then 'HIGH'
            when match_confidence_score >= 0.7 then 'MEDIUM'
            else 'LOW'
        end as match_confidence_level,

        -- ✅ Flags from silver (reuse, do NOT recompute unnecessarily)
        is_strong_match_flag,
        is_cross_system_link_flag,

        -- ✅ Additional gold-level flags
        case
            when is_cross_system_link_flag = true and is_strong_match_flag = true
                then 'STRONG_CROSS_SYSTEM_MATCH'
            when is_cross_system_link_flag = true
                then 'WEAK_CROSS_SYSTEM_MATCH'
            else 'SINGLE_SYSTEM_RECORD'
        end as identity_link_type,

        -- ✅ Data quality indicator
        case
            when match_confidence_score < 0.7 then true
            else false
        end as is_low_confidence_flag,

        -- ✅ Metadata (FIXED: using silver column, NOT _loaded_at)
        loaded_timestamp,

        -- ✅ Audit metadata
        current_timestamp() as dbt_updated_timestamp

    from base

)

-- ============================================================================
-- FINAL SELECT
-- ============================================================================

select *
from final