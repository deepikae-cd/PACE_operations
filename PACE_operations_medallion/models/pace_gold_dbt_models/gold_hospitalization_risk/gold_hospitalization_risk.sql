/*
 GOLD_HOSPITALIZATION_RISK
  ------------------------------------------------------------------------------
  Purpose:
    Identifies participant-level hospitalization and clinical risk indicators
    based on IDT clinical visit data.

  Grain:
    One row per participant

  Description:
    This model aggregates clinical visit data to evaluate participant risk
    levels using high-acuity visits, missed follow-ups, and abnormal vitals.

  Key Metrics:
    - hospital_visits     → visits in ER/Hospital (high acuity)
    - missed_followups    → overdue follow-up visits
    - respiratory_risk    → visits with low oxygen saturation

  Risk Logic:
    - HIGH_RISK   → > 2 hospital visits
    - MEDIUM_RISK → > 1 missed follow-ups
    - LOW_RISK    → otherwise

  Use Cases:
    - UC-17: Hospitalization prevention analytics
    - Risk stratification for care management
    - Proactive intervention planning
------------------------------------------------------------------------------*/

select
    participant_id,

    -- Risk indicators
    count_if(is_high_acuity_location_flag) as hospital_visits,

    count_if(is_follow_up_overdue_flag) as missed_followups,

    count_if(is_o2_low_flag) as respiratory_risk,

    -- Risk classification
    case
        when count_if(is_high_acuity_location_flag) > 2 then 'HIGH_RISK'
        when count_if(is_follow_up_overdue_flag) > 1 then 'MEDIUM_RISK'
        else 'LOW_RISK'
    end as risk_level,

    -- Metadata
    current_timestamp as dbt_updated_timestamp

from {{ ref('fct_idt_clinical_visit') }}

group by participant_id
