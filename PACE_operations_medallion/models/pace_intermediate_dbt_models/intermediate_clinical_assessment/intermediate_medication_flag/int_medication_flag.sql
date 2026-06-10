/*
  INT_MEDICATION_FLAGS
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('stg_medication') }}
  Purpose : Identify participants with at least one HIGH-RISK TIMED medication.
            Builds reusable participant-level flag for downstream analytics.
            No cohort filtering here.
  ──────────────────────────────────────────────────────────────────────────────
*/

with base as (

    select
        -- Keys
        participant_id,

        -- Normalize only what's needed for logic (allowed in intermediate)
        lower(trim(risk_class))                as risk_class,
        lower(trim(administration_complexity)) as administration_complexity

    from {{ ref('staging_medication') }}

),

flagged as (

    select
        participant_id,

        case
            when risk_class = 'high'
             and administration_complexity = 'timed'
            then 1
            else 0
        end as is_high_risk_timed

    from base

),

aggregated as (

    select
        participant_id,

        -- participant qualifies if ANY medication meets criteria
        max(is_high_risk_timed) as has_high_risk_timed_med

    from flagged
    group by participant_id

)

select * from aggregated