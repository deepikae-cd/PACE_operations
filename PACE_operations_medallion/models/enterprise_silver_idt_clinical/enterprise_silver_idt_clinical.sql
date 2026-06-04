/*
  ENTERPRISE_SILVER_IDT_CLINICAL
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_clinical_visit', 'RAW_CLINICAL_VISIT') }}
  Purpose : Cleanse, cast, deduplicate clinical encounter records.
            Parses BP string into systolic / diastolic numerics.
            Normalises visit type, location type, follow-up flags.
  ──────────────────────────────────────────────────────────────────────────────
*/

with

source as (

    select * from {{ source('bronze_clinical_visit', 'RAW_CLINICAL_VISIT') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by visit_id
               order by _loaded_at desc
           ) as _rn
    from source
    where visit_id       is not null
      and participant_id is not null
      and visit_date     is not null

),

cleaned as (

    select
        -- Keys
        sha2(concat_ws('||', visit_id, cast(_loaded_at as varchar))) as clinical_visit_sk,
        trim(upper(visit_id))       as clinical_visit_id,
        trim(upper(appointment_id)) as appointment_id,
        trim(upper(participant_id)) as participant_id,
        trim(upper(provider_id))    as provider_id,
        trim(upper(caregiver_id))   as caregiver_id,
        trim(upper(center_id))      as center_id,

        -- Visit type
        case
            when upper(trim(visit_type)) like '%ASSESS%' then 'ASSESSMENT'
            when upper(trim(visit_type)) like '%FOLLOW%' then 'FOLLOW_UP'
            when upper(trim(visit_type)) in ('URGENT','EMERGENCY','ER') then 'URGENT'
            when upper(trim(visit_type)) like '%SPEC%' then 'SPECIALIST'
            when upper(trim(visit_type)) in ('PREVENTIVE','WELLNESS') then 'PREVENTIVE'
            when visit_type is null then 'UNKNOWN'
            else 'OTHER'
        end as visit_type,

        -- ✅ NO TIMESTAMP CASTING
        visit_date,
        visit_duration_minutes,

        -- Diagnosis
        trim(upper(chief_complaint))        as chief_complaint,
        trim(upper(primary_diagnosis_code)) as primary_diagnosis_code,
        trim(primary_diagnosis_desc)        as primary_diagnosis_desc,
        trim(secondary_diagnosis_codes)     as secondary_diagnosis_codes,
        trim(procedures_performed)          as procedures_performed,
        trim(medications_prescribed)        as medications_prescribed,

        -- ✅ BP parsing (safe)
        try_cast(
            split_part(regexp_replace(vitals_blood_pressure,'[^0-9/]',''), '/', 1)
        as number(5,0)) as vitals_blood_pressure_systolic,

        try_cast(
            split_part(regexp_replace(vitals_blood_pressure,'[^0-9/]',''), '/', 2)
        as number(5,0)) as vitals_blood_pressure_diastolic,

        -- ✅ Numeric casts are ok
        try_cast(vitals_heart_rate as number(5,0))     as vitals_heart_rate,
        try_cast(vitals_temperature as number(5,2))    as vitals_temperature_f,
        try_cast(vitals_weight_lbs as number(6,2))     as vitals_weight_lbs,
        try_cast(vitals_o2_saturation as number(5,2))  as vitals_o2_saturation,

        -- Follow-up
        coalesce(follow_up_required, false) as follow_up_required,
        try_cast(follow_up_timeframe_days as number(5,0)) as follow_up_timeframe_days,

        -- Location
        case
            when upper(trim(location_type)) in
                ('CENTER','HOME','ER','HOSPITAL','TELEHEALTH')
            then upper(trim(location_type))
            when location_type is null then 'UNKNOWN'
            else 'OTHER'
        end as location_type,

        trim(clinical_notes) as clinical_notes,

        -- Metadata
        upper(trim(source_system)) as source_system,
        _loaded_at as loaded_at,
        current_timestamp() as dbt_updated_at

    from deduplicated
    where _rn = 1

)

select * from cleaned