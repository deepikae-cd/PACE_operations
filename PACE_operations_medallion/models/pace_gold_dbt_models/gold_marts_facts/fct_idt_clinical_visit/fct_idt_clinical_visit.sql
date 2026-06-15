/*
  FACT_IDT_CLINICAL_VISIT
  ------------------------------------------------------------------------------
  Purpose:
    Fact table capturing clinical visits performed by providers and IDT team.

  Grain:
    One row per visit_id
------------------------------------------------------------------------------*/

select
    visit_sk,
    visit_id,
    participant_id,
    provider_id,
    caregiver_id,
    center_id,

    visit_date,
    visit_type,
    location_type,

    visit_duration_minutes,

    -- Clinical metrics
    primary_diagnosis_code,
    primary_diagnosis_chapter,

    secondary_diagnosis_count,
    procedure_count,

    -- Flags
    is_high_acuity_location_flag,
    is_long_visit_flag,
    has_procedures_flag,
    is_vitals_complete_flag,

    is_heart_rate_abnormal_flag,
    is_temperature_abnormal_flag,
    is_o2_low_flag,

    follow_up_required,
    follow_up_due_date,
    is_follow_up_overdue_flag,

    current_timestamp as dbt_updated_timestamp

from {{ ref('enterprise_silver_clinical_visit') }}
