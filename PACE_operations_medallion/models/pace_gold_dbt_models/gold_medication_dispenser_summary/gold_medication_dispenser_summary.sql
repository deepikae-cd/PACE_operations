/*
  GOLD_MEDICATION_DISPENSER_SUMMARY
  ──────────────────────────────────────────────────────────────────────────────
  Purpose : Provide cohort sizing metrics for operational decision making
  ──────────────────────────────────────────────────────────────────────────────
*/

select
    count(*) as total_participants,

    coalesce(sum(eligible_flag), 0) as total_candidates,

    round(
        100.0 * coalesce(sum(eligible_flag), 0) / nullif(count(*), 0),
        2
    ) as candidate_percentage

from {{ ref('gold_medication_dispenser_candidates') }}