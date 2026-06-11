/*
  GOLD_MEDICATION_DISPENSER_SUMMARY
  ──────────────────────────────────────────────────────────────────────────────
  Purpose : Provide cohort sizing metrics for operational decision making
  ──────────────────────────────────────────────────────────────────────────────
*/

select
    count(*) as total_participants,
    sum(eligible_flag) as total_candidates,

    round(
        100.0 * sum(eligible_flag) / nullif(count(*), 0),
        2
    ) as candidate_percentage

from {{ ref('gold_medication_dispenser_candidates') }}