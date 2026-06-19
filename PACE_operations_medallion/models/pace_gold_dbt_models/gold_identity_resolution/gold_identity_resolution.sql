/*
===============================================================================
MODEL NAME  : gold_identity_resolution
LAYER       : GOLD
DOMAIN      : IDENTITY / MASTER DATA
OWNER       : DATA ENGINEERING
VERSION     : 1.0

-------------------------------------------------------------------------------
DESCRIPTION:
  Standardizes and resolves participant identities across multiple source
  systems (EHR, CareLiva, etc.). Produces unified identity mappings and match
  confidence scores for downstream reconciliation and analytics.

  Supports:
    - UC-15: CareLiva and EHR reconciliation
    - Cross-system joins
    - Deduplication and identity resolution

GRAIN:
  One row per participant_id per source_system

DEPENDENCIES:
  - enterprise_silver_identity_link
-------------------------------------------------------------------------------
*/


with base as (

    select *
    from {{ ref('enterprise_silver_identity_link') }}

),

cleaned as (

    select

        -- Surrogate key
        sha2(concat_ws('||', participant_id, source_system), 256)
            as identity_sk,

        -- Keys
        trim(upper(participant_id)) as participant_id,
        trim(upper(source_system))  as source_system,

        trim(upper(ehr_id))        as ehr_id,
        trim(upper(careliva_id))   as careliva_id,

        -- Matching logic
        match_type,
        match_confidence_score,

        -- ✅ Standard confidence bucket
        case
            when match_confidence_score >= 0.9 then 'HIGH'
            when match_confidence_score >= 0.7 then 'MEDIUM'
            else 'LOW'
        end as match_confidence_level,

        -- ✅ Flags
        (match_confidence_score >= 0.8) as is_strong_match_flag,

        case
            when ehr_id is not null and careliva_id is not null
            then true else false
        end as is_cross_system_link_flag,

        -- Metadata
        _loaded_at as loaded_timestamp,
        current_timestamp() as dbt_updated_timestamp

    from base

)

select * from cleaned
