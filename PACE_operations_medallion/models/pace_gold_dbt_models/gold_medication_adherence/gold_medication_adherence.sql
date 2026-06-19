/*
  MODEL NAME  : gold_medication_adherence
  LAYER       : GOLD
  DOMAIN      : CLINICAL / MEDICATION ANALYTICS
  OWNER       : DATA ENGINEERING
  VERSION     : 1.0

  ──────────────────────────────────────────────────────────────────────────────
  DESCRIPTION:
  Aggregated participant-level medication metrics used for operational and
  analytical decision-making. Produces adherence proxies, refill risk,
  medication load, and dispenser size recommendations.

  This model supports:
    - UC-2: Medication dispenser sizing
    - Risk stratification
    - Refill management workflows

  GRAIN:
    One row per participant_id

  DEPENDENCIES:
    - gold_medication

  ──────────────────────────────────────────────────────────────────────────────
*/

{{ config(
    materialized = 'table',
    tags = ['gold', 'medication', 'analytics'],
    cluster_by = ['participant_id'],
    persist_docs = {"relation": true, "columns": true}
) }}

with active_medications as (

    select *
    from {{ ref('gold_medication') }}
    where is_currently_active_flag = true

),

aggregated as (

    select
        participant_id,

        count(*) as total_active_medications,

        sum(case when is_controlled_substance_flag then 1 else 0 end)
            as controlled_medication_count,

        sum(case when is_high_risk_controlled_flag then 1 else 0 end)
            as high_risk_medication_count,

        sum(case when needs_refill_attention_flag then 1 else 0 end)
            as medications_needing_refill_count,

        sum(case when is_prior_auth_at_risk_flag then 1 else 0 end)
            as prior_auth_risk_count,

        sum(case when has_interaction_alerts_flag then 1 else 0 end)
            as interaction_alert_count,

        sum(total_cost) as total_medication_cost,
        avg(total_cost) as avg_medication_cost

    from active_medications
    group by participant_id

),

final as (

    select
        participant_id,

        total_active_medications,

        case
            when total_active_medications <= 5 then 'SMALL'
            when total_active_medications <= 10 then 'MEDIUM'
            else 'LARGE'
        end as recommended_dispenser_size,

        case
            when high_risk_medication_count > 0 then 'HIGH'
            when interaction_alert_count > 2 then 'HIGH'
            else 'NORMAL'
        end as medication_risk_level,

        medications_needing_refill_count,
        prior_auth_risk_count,
        total_medication_cost,
        avg_medication_cost

    from aggregated

)

select * from final
