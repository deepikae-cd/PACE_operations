/*
  MODEL NAME  : gold_medication
  LAYER       : GOLD
  DOMAIN      : CLINICAL / MEDICATION
  OWNER       : DATA ENGINEERING
  VERSION     : 1.0

  ──────────────────────────────────────────────────────────────────────────────
  DESCRIPTION:
  Curated medication dataset derived from enterprise_silver_medication.
  Provides a standardized, analytics-ready view of participant medications with
  enriched business flags for lifecycle status, refill attention, risk signals,
  formulary compliance, and cost classification.

  This model supports:
    - UC-2: Medication dispenser sizing
    - Clinical reporting and analytics
    - Operational workflows (refill monitoring, risk monitoring)

  GRAIN:
    One row per medication_id (latest record)

  DEPENDENCIES:
    - enterprise_silver_medication

  ──────────────────────────────────────────────────────────────────────────────
*/

with base as (

    select *
    from {{ ref('enterprise_silver_medication') }}

),

final as (

    select
        -- Keys
        medication_sk,
        medication_id,
        participant_id,
        provider_id,
        center_id,

        -- Drug identity
        medication_name,
        generic_name,
        brand_name,
        drug_class,
        ndc_code,

        -- Dosage & administration
        dosage,
        dosage_unit,
        frequency,
        route_of_administration,

        prescribed_date,
        start_date,
        end_date,

        -- Status
        medication_status,
        is_active_flag,
        is_currently_active_flag,
        is_stale_active_flag,

        -- Refill intelligence
        refills_remaining,
        days_supply,
        is_refills_exhausted_flag,
        is_refill_due_soon_flag,

        -- Risk signals
        is_controlled_substance_flag,
        is_high_risk_controlled_flag,
        has_interaction_alerts_flag,
        has_contraindications_flag,

        -- Prior auth
        is_prior_auth_required_flag,
        is_prior_auth_at_risk_flag,

        -- Formulary
        is_pace_formulary_flag,
        is_off_formulary_flag,

        -- Cost
        total_cost,
        cost_tier,
        coverage_type,

        -- Business derived fields
        case
            when is_currently_active_flag then 'ACTIVE'
            when is_stale_active_flag then 'STALE'
            else 'INACTIVE'
        end as medication_lifecycle_status,

        case
            when is_refill_due_soon_flag or is_refills_exhausted_flag
            then true else false
        end as needs_refill_attention_flag,

        -- Metadata
        source_system,
        loaded_timestamp

    from base

)

select * from final
