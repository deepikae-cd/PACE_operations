/*
  GOLD_HOSPITALIZATION_RISK_SUMMARY
  ------------------------------------------------------------------------------
  Purpose:
    Provides high-level summary metrics for participant risk levels
    based on hospitalization risk classification.

  Grain:
    One row (overall population summary)

  Description:
    This model aggregates participant-level risk data into an executive
    summary view, enabling quick assessment of population risk distribution.

  Key Metrics:
    - total_participants → total number of participants
    - high_risk          → participants classified as HIGH_RISK
    - medium_risk        → participants classified as MEDIUM_RISK
    - low_risk           → participants classified as LOW_RISK

  Use Cases:
    - UC-17: Hospitalization prevention analytics
    - Executive dashboards
    - Risk distribution reporting
------------------------------------------------------------------------------*/

select
  count(*) as total_participants,

  count_if(risk_level = 'HIGH_RISK') as high_risk,
  count_if(risk_level = 'MEDIUM_RISK') as medium_risk,
  count_if(risk_level = 'LOW_RISK') as low_risk,

  current_timestamp as dbt_updated_timestamp

from {{ ref('gold_hospitalization_risk') }}