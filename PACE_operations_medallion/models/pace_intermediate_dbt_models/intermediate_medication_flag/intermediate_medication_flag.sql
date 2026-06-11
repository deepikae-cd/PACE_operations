/*
  INT_MEDICATION_FLAG
  ──────────────────────────────────────────────────────────────────────────────
  Purpose : Derive medication risk and complexity flags using available fields
            from staging (drug_class, frequency).
  ──────────────────────────────────────────────────────────────────────────────
*/

with base as (

    select
        participant_id,

        lower(trim(drug_class)) as drug_class,
        lower(trim(frequency))  as frequency

    from {{ ref('staging_medication') }}

),

derived as (

    select
        participant_id,

        /* ✅ Derive risk_class (proxy logic) */
        case
            when drug_class like '%anticoagulant%'
              or drug_class like '%insulin%'
              or drug_class like '%opioid%'
            then 'high'
            else 'low'
        end as derived_risk_class,

        /* ✅ Derive administration complexity */
        case
            when frequency like '%daily%'
              or frequency like '%twice%'
              or frequency like '%every%'
            then 'timed'
            else 'prn'
        end as derived_administration_complexity

    from base

),

flagged as (

    select
        participant_id,

        case
            when derived_risk_class = 'high'
             and derived_administration_complexity = 'timed'
            then 1 else 0
        end as is_high_risk_timed

    from derived

),

aggregated as (

    select
        participant_id,
        max(is_high_risk_timed) as has_high_risk_timed_med

    from flagged
    group by participant_id

)

select * from aggregated