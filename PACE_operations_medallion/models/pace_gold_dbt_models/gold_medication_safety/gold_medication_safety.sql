/*
  MODEL: GOLD_MEDICATION_SAFETY
  ------------------------------------------------------------------------------
  PURPOSE:
    Provides participant-level medication safety indicators to identify
    high-risk prescriptions and clinical safety concerns.

  GRAIN:
    1 row per participant_id

  SOURCE:
    {{ ref('enterprise_silver_medication') }}

  USE CASES:
    - Audit response (UC-7)
    - Hospitalization prevention (UC-17)
*/

with safety_metrics as (

    select
        participant_id,

        count(*) as total_medications,

        -- Controlled substances
        sum(case when is_controlled_substance_flag then 1 else 0 end) as controlled_med_count,

        -- High-risk controlled
        sum(case when is_high_risk_controlled_flag then 1 else 0 end) as high_risk_controlled_count,

        -- Clinical safety
        sum(case when has_interaction_alerts_flag then 1 else 0 end) as interaction_alerts_count,
        sum(case when has_adverse_reactions_flag then 1 else 0 end) as adverse_reactions_count

    from {{ ref('enterprise_silver_medication') }}
    group by participant_id

)

select
    *,
    controlled_med_count / nullif(total_medications, 0) as controlled_med_rate,
    high_risk_controlled_count / nullif(total_medications, 0) as high_risk_med_rate,

    current_timestamp() as dbt_updated_timestamp

from safety_metrics