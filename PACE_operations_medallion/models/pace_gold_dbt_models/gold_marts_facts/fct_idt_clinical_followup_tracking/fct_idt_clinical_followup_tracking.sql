/*
  FCT_IDT_CLINICAL_FOLLOWUP_TRACKING
  ------------------------------------------------------------------------------
  Purpose:
    Tracks follow-up activity and compliance for participants based on
    IDT clinical visits.

  Grain:
    One row per participant per center

  Description:
    This model aggregates clinical visit data to monitor follow-up requirements,
    identify overdue follow-ups, and support operational and audit reporting.

  Key Metrics:
    - total_followups       → total visits contributing to follow-up tracking
    - required_followups    → visits where follow-up is required
    - overdue_followups     → follow-ups that are overdue

  Use Cases:
    - UC-7: Audit response (compliance tracking)
    - UC-13: Participant lifecycle monitoring
    - Operational dashboards for follow-up compliance
------------------------------------------------------------------------------*/

select
    participant_id,
    center_id,

    -- Follow-up metrics
    count(*) as total_followups,

    count_if(follow_up_required) as required_followups,

    count_if(is_follow_up_overdue_flag) as overdue_followups,

    -- Metadata
    current_timestamp as dbt_updated_timestamp

from {{ ref('fct_idt_clinical_visit') }}

group by
    participant_id,
    center_id