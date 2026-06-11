/*
  GOLD_MEDICATION__CARE_ANALYTICS
  ──────────────────────────────────────────────────────────────────────────────
  Purpose : Identify participants eligible for automated medication dispensers
            based on cognitive status, medication risk, and family support.
  ──────────────────────────────────────────────────────────────────────────────
*/

with base as (

    select
        p.participant_id,

        ca.cognitive_score,
        ca.functional_score,

        m.has_high_risk_timed_med,

        coalesce(fs.can_administer_meds, 0) as can_administer_meds

    from {{ ref('enterprise_silver_participant') }} p

    join {{ ref('enterprise_silver_clinical_assessment') }} ca
        on p.participant_id = ca.participant_id

    join {{ ref('enterprise_silver_medication_flag') }} m
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
            when cognitive_score between 10 and 22
             and has_high_risk_timed_med = 1
             and can_administer_meds = 0
            then 1 else 0
        end as eligible_flag,

        case
            when cognitive_score < 15 then 'high_priority'
            when cognitive_score between 15 and 22 then 'medium_priority'
            else 'low_priority'
        end as priority_band

    from base

)

select * from final