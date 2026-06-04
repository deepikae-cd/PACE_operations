{{
    config(
        schema        = 'silver_participant',
        materialized  = 'table',
        tags          = ['silver', 'participant'],
        on_schema_change = 'sync_all_columns'
    )
}}

/*
  Silver_PARTICIPANT
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_participant', 'raw_participant') }}
  Purpose : Cleanse, cast, deduplicate and standardise participant records.
            Downstream: DIM_PARTICIPANT (SCD2) and Silver-Combined joins.

  Deduplication strategy:
    - Natural key  : PARTICIPANT_ID
    - Tie-breaker  : latest _LOADED_AT (most recent pipeline load wins)
  ──────────────────────────────────────────────────────────────────────────────
*/

with

source as (

    select * from {{ source('bronze_participant', 'raw_participant') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by participant_id
               order by _loaded_at desc
           ) as _rn
    from source
    where participant_id is not null      -- hard requirement: drop orphan rows

),

cleaned as (

    select
        -- ── Surrogate key ───────────────────────────────────────────────────
        sha2(concat_ws('||', participant_id, cast(_loaded_at as varchar))) as participant_sk,

        -- ── Natural / business key ──────────────────────────────────────────
        trim(upper(participant_id))                                         as participant_id,

        -- ── Name ────────────────────────────────────────────────────────────
        trim(initcap(coalesce(first_name, '')))                             as first_name,
        trim(initcap(coalesce(last_name,  '')))                             as last_name,
        trim(initcap(coalesce(first_name, '') || ' ' || coalesce(last_name, ''))) as full_name,

        -- ── Demographics ────────────────────────────────────────────────────
        try_cast(date_of_birth as date)                                     as date_of_birth,
        datediff(
            'year',
            try_cast(date_of_birth as date),
            current_date()
        )                                                                   as age_years,

        case
            when upper(trim(gender)) in ('M', 'MALE')                      then 'MALE'
            when upper(trim(gender)) in ('F', 'FEMALE')                    then 'FEMALE'
            when upper(trim(gender)) in ('NB', 'NON_BINARY', 'NONBINARY')  then 'NON_BINARY'
            else 'UNKNOWN'
        end                                                                  as gender,

        upper(trim(coalesce(preferred_language, 'UNKNOWN')))               as preferred_language,

        -- ── Enrollment ──────────────────────────────────────────────────────
        try_cast(enrollment_date      as date)                             as enrollment_date,
        try_cast(disenrollment_date   as date)                             as disenrollment_date,

        case
            when upper(trim(program_status)) in ('ACTIVE', 'DISENROLLED', 'DECEASED', 'ON_LEAVE')
                then upper(trim(program_status))
            else 'UNKNOWN'
        end                                                                  as program_status,

        -- ── Clinical identifiers ────────────────────────────────────────────
        trim(primary_diagnosis)                                             as primary_diagnosis,
        trim(secondary_diagnoses)                                           as secondary_diagnoses,

        -- ── Insurance ───────────────────────────────────────────────────────
        trim(upper(insurance_id))                                           as insurance_id,
        trim(upper(medicare_id))                                            as medicare_id,
        trim(upper(medicaid_id))                                            as medicaid_id,

        -- ── Organisation ────────────────────────────────────────────────────
        trim(upper(center_id))                                              as center_id,

        -- ── Address ─────────────────────────────────────────────────────────
        trim(address_line1)                                                 as address_line1,
        trim(address_line2)                                                 as address_line2,
        trim(city)                                                          as city,
        upper(trim(state))                                                  as state,
        left(regexp_replace(zip_code, '[^0-9]', ''), 5)                    as zip_code,
        trim(concat_ws(', ',
            nullif(trim(address_line1),''),
            nullif(trim(address_line2),''),
            nullif(trim(city),''),
            nullif(upper(trim(state)),''),
            nullif(left(regexp_replace(zip_code,'[^0-9]',''),5),'')
        ))                                                                   as full_address,

        -- ── Contact ─────────────────────────────────────────────────────────
        regexp_replace(phone_number, '[^0-9+]', '')                        as phone_number,
        trim(emergency_contact_name)                                        as emergency_contact_name,
        regexp_replace(emergency_contact_phone, '[^0-9+]', '')             as emergency_contact_phone,
        upper(trim(emergency_contact_relation))                             as emergency_contact_relation,

        -- ── Metadata ────────────────────────────────────────────────────────
        upper(trim(source_system))                                          as source_system,
        _loaded_at                                                          as loaded_at,
        current_timestamp()                                                 as dbt_updated_at

    from deduplicated
    where _rn = 1

)

select * from cleaned
