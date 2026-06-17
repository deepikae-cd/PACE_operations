/*
  MODEL: GOLD_MEDICATION_ADHERENCE
  ------------------------------------------------------------------------------
  PURPOSE:
    Tracks medication adherence patterns using refill and active flags.

  GRAIN:
    1 row per participant_id
*/

with adherence_metrics as (

    select
        participant_id,

        count(*) as total_meds,

        -- Active medications
        sum(case when is_currently_active_flag then 1 else 0 end) as active_meds,

        -- Refill risks
        sum(case when is_refill_due_soon_flag then 1 else 0 end) as refill_due_soon,
        sum(case when is_refills_exhausted_flag then 1 else 0 end) as exhausted_refills,

        -- Stale meds
        sum(case when is_stale_active_flag then 1 else 0 end) as stale_active_meds

    from {{ ref('enterprise_silver_medication') }}
    group by participant_id

)

select
    *,
    refill_due_soon / nullif(total_meds, 0) as refill_risk_rate,
    stale_active_meds / nullif(total_meds, 0) as stale_rate,

    current_timestamp() as dbt_updated_timestamp

from adherence_metrics