/*
  ENTERPRISE_SILVER_CLINICAL_VISIT
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('stg_clinical_visit') }}
  Purpose : Cleanse, deduplicate and enrich clinical visit records.
            Adds surrogate key, standardised vocabularies, vitals range
            validation flags, diagnosis/procedure count derivations,
            follow-up due date, and appointment linkage flag.
  ──────────────────────────────────────────────────────────────────────────────
*/

{{ config(
    materialized         = 'incremental',
    unique_key           = 'visit_sk',
    incremental_strategy = 'merge',
    tags                 = ['silver', 'clinical']
) }}

with source as (

    select * from {{ ref('stg_clinical_visit') }}

    {% if is_incremental() %}
        where _loaded_at > (select max(loaded_timestamp) from {{ this }})
    {% endif %}

),

deduplicated as (

    select *,
           row_number() over (
               partition by visit_id
               order by _loaded_at desc
           ) as _rn
    from source

),

cleaned as (

    select
        -- Surrogate key
        sha2(concat_ws('||', visit_id, cast(_loaded_at as varchar))) as visit_sk,

        -- Natural keys (normalised)
        trim(upper(visit_id))        as visit_id,
        trim(upper(appointment_id))  as appointment_id,
        trim(upper(participant_id))  as participant_id,
        trim(upper(provider_id))     as provider_id,
        trim(upper(caregiver_id))    as caregiver_id,
        trim(upper(center_id))       as center_id,

        -- Appointment linkage flag
        (appointment_id is not null) as is_scheduled_visit_flag,

        -- Visit type (controlled vocabulary)
        case
            when upper(trim(visit_type)) in (
                'ASSESSMENT', 'FOLLOW_UP', 'URGENT',
                'SPECIALIST', 'ROUTINE', 'TELEHEALTH'
            ) then upper(trim(visit_type))
            when visit_type is null then 'UNKNOWN'
            else 'OTHER'
        end as visit_type,

        -- Location type (controlled vocabulary)
        case
            when upper(trim(location_type)) in (
                'CENTER', 'HOME', 'ER', 'HOSPITAL', 'TELEHEALTH'
            ) then upper(trim(location_type))
            when location_type is null then 'UNKNOWN'
            else 'OTHER'
        end as location_type,

        -- High-acuity location flag (ER or HOSPITAL)
        (upper(trim(location_type)) in ('ER', 'HOSPITAL')) as is_high_acuity_location_flag,

        -- Chief complaint
        trim(chief_complaint) as chief_complaint,

        -- Primary diagnosis (ICD-10 normalised)
        trim(upper(primary_diagnosis_code)) as primary_diagnosis_code,
        trim(primary_diagnosis_desc)        as primary_diagnosis_desc,

        -- ICD-10 chapter derived from first character of primary code
        case
            when primary_diagnosis_code like 'A%' or primary_diagnosis_code like 'B%' then 'INFECTIOUS_PARASITIC'
            when primary_diagnosis_code like 'C%'                                      then 'NEOPLASMS'
            when primary_diagnosis_code like 'D%'                                      then 'BLOOD_IMMUNE'
            when primary_diagnosis_code like 'E%'                                      then 'ENDOCRINE_METABOLIC'
            when primary_diagnosis_code like 'F%'                                      then 'MENTAL_BEHAVIORAL'
            when primary_diagnosis_code like 'G%'                                      then 'NERVOUS_SYSTEM'
            when primary_diagnosis_code like 'H%'                                      then 'EYE_EAR'
            when primary_diagnosis_code like 'I%'                                      then 'CIRCULATORY'
            when primary_diagnosis_code like 'J%'                                      then 'RESPIRATORY'
            when primary_diagnosis_code like 'K%'                                      then 'DIGESTIVE'
            when primary_diagnosis_code like 'L%'                                      then 'SKIN'
            when primary_diagnosis_code like 'M%'                                      then 'MUSCULOSKELETAL'
            when primary_diagnosis_code like 'N%'                                      then 'GENITOURINARY'
            when primary_diagnosis_code like 'Z%'                                      then 'FACTORS_HEALTH_STATUS'
            when primary_diagnosis_code is null                                        then 'UNKNOWN'
            else 'OTHER'
        end as primary_diagnosis_chapter,

        -- Raw pipe-delimited fields passed through for mart-level parsing
        secondary_diagnosis_codes,
        procedures_performed,
        medications_prescribed,

        -- Secondary diagnosis count (pipe count + 1 if not null)
        case
            when secondary_diagnosis_codes is null then 0
            else array_size(split(secondary_diagnosis_codes, '|'))
        end as secondary_diagnosis_count,

        -- Procedure count
        case
            when procedures_performed is null then 0
            else array_size(split(procedures_performed, '|'))
        end as procedure_count,

        -- Visit has procedures flag
        (procedures_performed is not null) as has_procedures_flag,

        -- Vitals (passed through — range flags added below)
        vitals_blood_pressure,
        vitals_heart_rate,
        vitals_temperature,
        vitals_weight_lbs,
        vitals_o2_saturation,

        -- Vitals completeness flag
        (
            vitals_heart_rate    is not null
            and vitals_temperature   is not null
            and vitals_weight_lbs    is not null
            and vitals_o2_saturation is not null
        ) as is_vitals_complete_flag,

        -- Vitals out-of-range flags (clinically standard thresholds)
        (vitals_heart_rate < 60 or vitals_heart_rate > 100)           as is_heart_rate_abnormal_flag,
        (vitals_temperature < 96.8 or vitals_temperature > 100.4)     as is_temperature_abnormal_flag,
        (vitals_o2_saturation is not null
            and vitals_o2_saturation < 95)                            as is_o2_low_flag,

        -- Clinical notes
        trim(clinical_notes) as clinical_notes,

        -- Follow-up
        follow_up_required,
        follow_up_timeframe_days,

        -- Follow-up due date derived from visit date + timeframe
        case
            when follow_up_required = true
             and visit_date is not null
             and follow_up_timeframe_days is not null
            then dateadd('day', follow_up_timeframe_days, visit_date::date)
        end as follow_up_due_date,

        -- Follow-up overdue flag (required but due date has passed)
        case
            when follow_up_required = true
             and visit_date is not null
             and follow_up_timeframe_days is not null
             and dateadd('day', follow_up_timeframe_days, visit_date::date) < current_date()
            then true
            else false
        end as is_follow_up_overdue_flag,

        -- Visit timing
        visit_date,
        visit_duration_minutes,

        -- Long visit flag (> 60 min)
        (visit_duration_minutes is not null
            and visit_duration_minutes > 60) as is_long_visit_flag,

        -- Metadata
        upper(trim(source_system))  as source_system,
        _loaded_at                  as loaded_timestamp,
        _source_file                as source_file,
        current_timestamp()         as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned