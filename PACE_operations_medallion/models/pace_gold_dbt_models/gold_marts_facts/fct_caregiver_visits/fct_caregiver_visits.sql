select

    visit_id,
    caregiver_id,
    participant_id,
    visit_date,
    visit_type,
    duration_minutes

from {{ ref('staging_caregiver') }}
