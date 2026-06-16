/*
FCT_IDT_DAILY_OPERATIONS
  ------------------------------------------------------------------------------
  Purpose:
    Provides daily activity metrics for IDT providers and care teams.

  Grain:
    One row per provider per center per day

  Description:
    This model aggregates clinical visit data to track daily workload,
    time spent, and high-acuity visits for providers.

  Key Metrics:
    - daily_visits          → number of clinical visits per day
    - total_minutes         → total visit duration per day
    - high_acuity_visits    → number of ER/Hospital visits

  Use Cases:
    - UC-12: IDT day-to-day transactional activity
    - Provider workload analysis
    - Operational monitoring at center level
------------------------------------------------------------------------------*/

select
    provider_id,
    center_id,

    -- Time grain (daily)
    date(visit_date) as activity_date,

    -- Workload metrics
    count(visit_id) as daily_visits,
    sum(visit_duration_minutes) as total_minutes,

    -- Clinical intensity
    count_if(is_high_acuity_location_flag) as high_acuity_visits,

    -- Metadata
    current_timestamp as dbt_updated_timestamp

from {{ ref('fct_idt_clinical_visit') }}

group by
    provider_id,
    center_id,
    date(visit_date)