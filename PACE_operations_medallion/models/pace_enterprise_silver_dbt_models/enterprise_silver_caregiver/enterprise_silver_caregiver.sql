/*
  ENTERPRISE_SILVER_CAREGIVER
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_caregiver', 'RAW_CAREGIVER') }}
  Purpose : Cleanse, cast, deduplicate caregiver records.
  ──────────────────────────────────────────────────────────────────────────────
*/

with

source as (

    select * from {{ source('bronze_caregiver', 'RAW_CAREGIVER') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by caregiver_id
               order by _loaded_at desc
           ) as _rn
    from source
    where caregiver_id is not null

),

cleaned as (

    select
        -- ── Surrogate key ───────────────────────────────────────────────────
        sha2(concat_ws('||', caregiver_id, cast(_loaded_at as varchar)))    as caregiver_sk,

        -- ── Natural key ─────────────────────────────────────────────────────
        trim(upper(caregiver_id))                                           as caregiver_id,

        -- ── Name ────────────────────────────────────────────────────────────
        trim(initcap(coalesce(first_name, '')))                             as first_name,
        trim(initcap(coalesce(last_name,  '')))                             as last_name,
        trim(initcap(coalesce(first_name,'') || ' ' || coalesce(last_name,''))) as full_name,

        -- ── Type normalisation ───────────────────────────────────────────────
        case
            when upper(trim(caregiver_type)) in ('RN','LPN','NURSE')        then 'NURSE'
            when upper(trim(caregiver_type)) = 'SOCIAL_WORKER'              then 'SOCIAL_WORKER'
            when upper(trim(caregiver_type)) in ('PT','OT','SLP','THERAPIST') then 'THERAPIST'
            when upper(trim(caregiver_type)) in ('HOME_AIDE','CNA','HHA')   then 'HOME_AIDE'
            when upper(trim(caregiver_type)) in ('MD','DO','PHYSICIAN')     then 'PHYSICIAN'
            when upper(trim(caregiver_type)) in ('RD','DIETITIAN')          then 'DIETITIAN'
            when caregiver_type is null                                      then 'UNKNOWN'
            else 'OTHER'
        end                                                                  as caregiver_type,

        -- ── License ─────────────────────────────────────────────────────────
        trim(upper(license_number))                                         as license_number,
        upper(trim(license_state))                                          as license_state,
        try_cast(license_expiry_date as date)                              as license_expiry_date,
        (try_cast(license_expiry_date as date) < current_date())           as is_license_expired,
        trim(specialty)                                                     as specialty,

        -- ── Employment ──────────────────────────────────────────────────────
        trim(upper(center_id))                                              as center_id,
        try_cast(hire_date as date)                                        as hire_date,
        try_cast(termination_date as date)                                 as termination_date,

        case
            when upper(trim(employment_status)) in ('ACTIVE','TERMINATED','ON_LEAVE')
                then upper(trim(employment_status))
            else 'UNKNOWN'
        end                                                                  as employment_status,

        trim(upper(supervisor_id))                                          as supervisor_id,
        coalesce(max_participant_load, 0)                                   as max_participant_load,

        -- ── Metadata ────────────────────────────────────────────────────────
        upper(trim(source_system))                                          as source_system,
        _loaded_at                                                          as loaded_at,
        current_timestamp()                                                 as dbt_updated_at

    from deduplicated
    where _rn = 1

)

select * from cleaned
