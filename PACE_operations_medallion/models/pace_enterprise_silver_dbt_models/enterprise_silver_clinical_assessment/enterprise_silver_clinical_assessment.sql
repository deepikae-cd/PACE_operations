/*
  ENTERPRISE_SILVER_CLINICAL_ASSESSMENT
  ──────────────────────────────────────────────────────────────────────────────
  Purpose : Trusted latest clinical state per participant
  ──────────────────────────────────────────────────────────────────────────────
*/

select
    participant_id,
    cognitive_score,
    functional_score,
    assessment_date
from {{ ref('int_clinical_assessment') }}