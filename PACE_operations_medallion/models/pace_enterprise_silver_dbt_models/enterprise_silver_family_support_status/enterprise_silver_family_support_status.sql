/*
  ENTERPRISE_SILVER_FAMILY_SUPPORT_STATUS
  ──────────────────────────────────────────────────────────────────────────────
  Purpose : Participant-level caregiver support status
  ──────────────────────────────────────────────────────────────────────────────
*/

select
    participant_id,
    cast(can_administer_meds as integer) as can_administer_meds
from {{ ref('int_family_support_status') }};
