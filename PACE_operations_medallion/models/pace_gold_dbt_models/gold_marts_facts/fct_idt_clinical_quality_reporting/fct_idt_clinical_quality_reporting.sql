/*
  FCT_IDT_CLINICAL_QUALITY_REPORTING
  ------------------------------------------------------------------------------
  Purpose:
    Provides center-level clinical quality metrics based on IDT clinical visits.

  Grain:
    One row per center

  Description:
    This model aggregates clinical visit data to evaluate care quality,
    focusing on vitals completeness and abnormality indicators.

  Key Metrics:
    - total_visits              → total clinical encounters
    - complete_vitals           → visits with all vitals recorded
    - abnormal_hr               → visits with abnormal heart rate
    - abnormal_temp             → visits with abnormal temperature
    - low_o2                    → visits with low oxygen levels
    - vitals_completeness_pct   → % of visits with complete vitals

  Use Cases:
    - UC-16: Quality measure reporting
    - Clinical audit readiness
    - Care quality monitoring across centers
------------------------------------------------------------------------------*/

select
    center_id,

    -- Total volume
    count(*) as total_visits,

    -- Quality metrics
    count_if(is_vitals_complete_flag) as complete_vitals,

    count_if(is_heart_rate_abnormal_flag) as abnormal_hr,
    count_if(is_temperature_abnormal_flag) as abnormal_temp,
    count_if(is_o2_low_flag) as low_o2,

    -- Completeness %
    round(
        100 * count_if(is_vitals_complete_flag) / count(*),
        2
    ) as vitals_completeness_pct,

    -- Metadata
    current_timestamp as dbt_updated_timestamp

from {{ ref('fct_idt_clinical_visit') }}

group by center_id
