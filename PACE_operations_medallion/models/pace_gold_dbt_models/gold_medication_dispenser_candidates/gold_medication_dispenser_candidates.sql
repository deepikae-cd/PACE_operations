/*
  GOLD_MEDICATION__DISPENSER_CANDIDATES
  ------------------------------------------------------------------------------
  Purpose:
    Identify participants eligible for automated medication dispensers based on:
      - Cognitive status
      - Medication risk
      - Family support availability

  Grain:
    One row per participant

  Key Logic:
    - Uses LEFT JOIN to retain full population
    - Applies corrected cognitive score thresholds (40–100 scale)
    - Adds explainability via decision_reason
------------------------------------------------------------------------------*/

with base as (

    select
        p.participant_id,

        -- Clinical scores
        ca.cognitive_score,
        ca.functional_score,

        -- Medication + support flags (null-safe)
        coalesce(m.has_high_risk_timed_med, 0) as has_high_risk_timed_med,
        coalesce(fs.can_administer_meds, 0) as can_administer_meds

    from {{ ref('enterprise_silver_participant') }} p

    left join {{ ref('enterprise_silver_clinical_assessment') }} ca
        on p.participant_id = ca.participant_id

    left join {{ ref('enterprise_silver_medication_flag') }} m
        on p.participant_id = m.participant_id

    left join {{ ref('enterprise_silver_family_support_status') }} fs
        on p.participant_id = fs.participant_id

),

final as (

    select
        participant_id,
        cognitive_score,
        functional_score,
        has_high_risk_timed_med,
        can_administer_meds,


        case
            when cognitive_score between 40 and 65
             and has_high_risk_timed_med = 1
             and can_administer_meds = 0
            then 1 else 0
        end as eligible_flag,

 
        case
            when cognitive_score <= 55 then 'high_priority'
            when cognitive_score between 56 and 70 then 'medium_priority'
            else 'low_priority'
        end as priority_band,

 
        case
            when cognitive_score is null then 'missing_cognitive'
            when cognitive_score < 40 then 'invalid_range'
            when cognitive_score > 65 then 'too_high_function'
            when has_high_risk_timed_med != 1 then 'no_med_risk'
            when can_administer_meds != 0 then 'has_family_support'
            when cognitive_score between 40 and 65
                 and has_high_risk_timed_med = 1
                 and can_administer_meds = 0
            then 'eligible'
            else 'other'
        end as decision_reason

    from base

)

select * from final