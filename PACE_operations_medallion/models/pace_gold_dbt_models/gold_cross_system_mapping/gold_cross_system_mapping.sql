/*
===============================================================================
MODEL NAME  : gold_cross_system_mapping
LAYER       : GOLD
DOMAIN      : IDENTITY / INTEGRATION
OWNER       : DATA ENGINEERING
VERSION     : 1.0

-------------------------------------------------------------------------------
DESCRIPTION:
  Provides unified participant mapping across EHR and CareLiva systems.
  Consolidates multiple identifiers into a single cross-system identity view
  for analytics and reporting consistency.

  Supports:
    - UC-15: CareLiva and EHR reconciliation
    - Unified participant analytics
    - Deduplication across systems

GRAIN:
  One row per unified participant_id

DEPENDENCIES:
  - gold_identity_resolution
-------------------------------------------------------------------------------
*/



with base as (

    select *
    from {{ ref('gold_identity_resolution') }}

),

aggregated as (

    select
        participant_id,

        max(ehr_id) as ehr_id,
        max(careliva_id) as careliva_id,

        max(match_confidence_score) as max_match_confidence_score,

        -- ✅ Derived mapping
        case
            when max(match_confidence_score) >= 0.9 then 'HIGH_CONFIDENCE'
            when max(match_confidence_score) >= 0.7 then 'MEDIUM_CONFIDENCE'
            else 'LOW_CONFIDENCE'
        end as mapping_confidence_level,

        -- ✅ Flags
        max(case when is_cross_system_link_flag then 1 else 0 end) = 1
            as is_cross_system_link_flag,

        max(case when is_strong_match_flag then 1 else 0 end) = 1
            as is_strong_match_flag

    from base
    group by participant_id

),

final as (

    select

        -- Surrogate key
        sha2(concat_ws('||', participant_id), 256)
            as unified_identity_sk,

        participant_id,
        ehr_id,
        careliva_id,

        mapping_confidence_level,
        max_match_confidence_score,

        is_cross_system_link_flag,
        is_strong_match_flag,

        current_timestamp() as dbt_updated_timestamp

    from aggregated

)

select * from final