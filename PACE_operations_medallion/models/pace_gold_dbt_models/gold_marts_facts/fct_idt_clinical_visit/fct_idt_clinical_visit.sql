/*
===============================================================================
Model       : fct_idt_clinical_visit
Layer       : Fact
Description :
  Captures clinical visits performed by providers and interdisciplinary teams (IDT),
  including diagnosis, procedures, vitals, and follow-up indicators.

Grain:
  One row per visit_id

Source:
  - enterprise_silver_idt_clinical

Key Features:
  - Clinical diagnosis tracking
  - Visit duration metrics
  - Vitals-based health flags
  - Follow-up and care continuity indicators

===============================================================================
*/

with base as (

    select *
    from {{ ref('enterprise_silver_idt_clinical') }}

),

final as (

    select

        -- 🔑 Keys
        visit_sk,
        visit_id,
        participant_id,
        provider_id,
        caregiver_id,
        center_id,

        -- 📅 Visit details
        visit_date,
        visit_type,
        location_type,
        visit_duration_minutes,

        -- 🩺 Clinical metrics
        primary_diagnosis_code,
        primary_diagnosis_chapter,
        secondary_diagnosis_count,
        procedure_count,

        -- 🚩 Flags
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

        -- 🧾 Metadata
        current_timestamp() as dbt_updated_timestamp

    from base

)

select * from final
