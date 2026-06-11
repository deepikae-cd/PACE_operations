/*
  ENTERPRISE_SILVER_MEDICATION_FLAG
  ──────────────────────────────────────────────────────────────────────────────
  Purpose : Participant-level medication risk flag
  ──────────────────────────────────────────────────────────────────────────────
*/

select
    participant_id,
    cast(has_high_risk_timed_med as integer) as has_high_risk_timed_med
from {{ ref('int_medication_flag') }}