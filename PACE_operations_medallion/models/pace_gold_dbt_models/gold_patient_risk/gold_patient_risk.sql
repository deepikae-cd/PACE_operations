/*
===============================================================================
Model: gold_patient_risk
Purpose:
  Identifies high-risk patients based on vitals and clinical patterns.

Grain:
  participant_id
===============================================================================
*/

with base as (

    select *
    from {{ ref('fct_idt_clinical_visit') }}

),

aggregated as (

    select
        participant_id,

        sum(case when is_heart_rate_abnormal_flag then 1 else 0 end) as hr_abnormal_count,
        sum(case when is_temperature_abnormal_flag then 1 else 0 end) as temp_abnormal_count,
        sum(case when is_o2_low_flag then 1 else 0 end) as o2_low_count,

        count(*) as total_visits

    from base
    group by participant_id

)

select
    *,
    (hr_abnormal_count + temp_abnormal_count + o2_low_count) as total_risk_events,
    current_timestamp() as dbt_updated_timestamp
from aggregated