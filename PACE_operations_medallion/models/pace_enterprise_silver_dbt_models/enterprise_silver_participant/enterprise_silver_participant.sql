

/*
  ENTERPRISE_SILVER_PARTICIPANT
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('staging_participant') }}
  Purpose : Cleanse, deduplicate and enrich participant records.
            Adds surrogate key, standardised vocabularies, computed flags
            for enrollment status, insurance coverage, risk segmentation,
            and time-based metrics.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select * from {{ ref('staging_participant') }}

    {% if is_incremental() %}
        where _loaded_at > (select max(loaded_timestamp) from {{ this }})
    {% endif %}

),

deduplicated as (

    select *,
           row_number() over (
               partition by participant_id
               order by _loaded_at desc
           ) as _rn
    from source

),

cleaned as (

    select
        -- ── Surrogate key ──────────────────────────────────────────────────
        sha2(concat_ws('||', participant_id, cast(_loaded_at as varchar))) as participant_sk,

        -- ── Natural / business keys (normalised) ───────────────────────────
        trim(upper(participant_id))  as participant_id,
        trim(upper(center_id))       as center_id,
        trim(upper(insurance_id))    as insurance_id,
        trim(upper(medicare_id))     as medicare_id,
        trim(upper(medicaid_id))     as medicaid_id,

        -- ── Demographics ───────────────────────────────────────────────────
        initcap(trim(first_name))    as first_name,
        initcap(trim(last_name))     as last_name,
        trim(initcap(first_name) || ' ' || initcap(last_name)) as full_name,

        -- DOB: keep only if plausible (post-1900, not in the future)
        case
            when date_of_birth > '1900-01-01'
             and date_of_birth <= current_date()
            then date_of_birth
        end as date_of_birth,

        -- Age in full years at load time
        datediff('year', date_of_birth, current_date()) as age_at_load,

        -- Gender (controlled vocabulary)
        case
            when upper(trim(gender)) in ('MALE', 'FEMALE', 'NON_BINARY')
            then upper(trim(gender))
            when gender is null then 'UNKNOWN'
            else 'OTHER'
        end as gender,

        upper(trim(preferred_language)) as preferred_language,

        -- ── Enrollment ─────────────────────────────────────────────────────
        enrollment_date,
        disenrollment_date,

        -- Program status (controlled vocabulary)
        case
            when upper(trim(program_status)) in
                ('ACTIVE', 'DISENROLLED', 'DECEASED', 'ON_LEAVE')
            then upper(trim(program_status))
            when program_status is null then 'UNKNOWN'
            else 'OTHER'
        end as program_status,

        -- Boolean status flags
        (upper(trim(program_status)) = 'ACTIVE')       as is_active_flag,
        (upper(trim(program_status)) = 'DISENROLLED')  as is_disenrolled_flag,
        (upper(trim(program_status)) = 'DECEASED')     as is_deceased_flag,
        (upper(trim(program_status)) = 'ON_LEAVE')     as is_on_leave_flag,

        -- Active + no disenrollment date — primary operational filter
        (
            upper(trim(program_status)) = 'ACTIVE'
            and disenrollment_date is null
        ) as is_active_enrolled_flag,

        -- Enrollment duration in days (null if still active)
        case
            when enrollment_date is not null and disenrollment_date is not null
            then datediff('day', enrollment_date, disenrollment_date)
        end as enrollment_duration_days,

        -- Age of enrollment in days (active participants only)
        case
            when upper(trim(program_status)) = 'ACTIVE'
             and enrollment_date is not null
            then datediff('day', enrollment_date, current_date())
        end as enrollment_age_days,

        -- ── Clinical ───────────────────────────────────────────────────────
        trim(primary_diagnosis) as primary_diagnosis,
        trim(secondary_diagnoses) as secondary_diagnoses,

        -- Count of pipe-delimited secondary diagnoses
        case
            when nullif(trim(secondary_diagnoses), '') is null then 0
            else array_size(split(trim(secondary_diagnoses), '|'))
        end as secondary_diagnosis_count,

        -- ── Insurance ──────────────────────────────────────────────────────
        (nullif(trim(medicare_id), '') is not null) as has_medicare_flag,
        (nullif(trim(medicaid_id), '') is not null) as has_medicaid_flag,

        -- Dual-eligible — highest priority for care management
        (
            nullif(trim(medicare_id), '') is not null
            and nullif(trim(medicaid_id), '') is not null
        ) as is_dual_eligible_flag,

        -- ── Address ────────────────────────────────────────────────────────
        trim(address_line1)  as address_line1,
        trim(address_line2)  as address_line2,
        initcap(trim(city))  as city,
        upper(trim(state))   as state,

        -- ZIP: keep 5-digit or ZIP+4, else null
        case
            when regexp_like(trim(zip_code), '^[0-9]{5}(-[0-9]{4})?$')
            then trim(zip_code)
        end as zip_code,

        left(trim(zip_code), 5) as zip5,

        -- State validity flag (50 states + DC + territories)
        (upper(trim(state)) in (
            'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA',
            'HI','ID','IL','IN','IA','KS','KY','LA','ME','MD',
            'MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ',
            'NM','NY','NC','ND','OH','OK','OR','PA','RI','SC',
            'SD','TN','TX','UT','VT','VA','WA','WV','WI','WY',
            'DC','PR','VI','GU','AS','MP'
        )) as is_valid_state_flag,

        -- ── Contact ────────────────────────────────────────────────────────
        -- Normalised digits-only phone; raw value preserved
        regexp_replace(phone_number, '[^0-9]', '') as phone_number,
        phone_number                               as phone_number_raw,
        trim(emergency_contact_name)               as emergency_contact_name,
        trim(emergency_contact_phone)              as emergency_contact_phone,
        trim(emergency_contact_relation)           as emergency_contact_relation,

        -- ── Risk segmentation (enterprise-computed) ────────────────────────
        -- Age band
        case
            when datediff('year', date_of_birth, current_date()) < 65  then '55-64'
            when datediff('year', date_of_birth, current_date()) < 75  then '65-74'
            when datediff('year', date_of_birth, current_date()) < 85  then '75-84'
            else '85+'
        end as age_band,

        -- Enrollment tenure band
        case
            when datediff('day', enrollment_date, current_date()) < 365  then '<1Y'
            when datediff('day', enrollment_date, current_date()) < 1095 then '1-3Y'
            when datediff('day', enrollment_date, current_date()) < 1825 then '3-5Y'
            else '5Y+'
        end as enrollment_tenure_band,

        -- Complexity tier based on secondary diagnosis count
        case
            when array_size(split(nullif(trim(secondary_diagnoses),'NA'), '|')) <= 1 then 'LOW'
            when array_size(split(nullif(trim(secondary_diagnoses),'NA'), '|')) <= 4 then 'MEDIUM'
            else 'HIGH'
        end as complexity_tier,

        -- SLA flag — participants without a care plan review overdue
        -- CRITICAL age >= 85 > 30 days since enrollment, HIGH (75-84) > 60 days, others > 90 days
        case
            when upper(trim(program_status)) != 'ACTIVE' then false
            when datediff('year', date_of_birth, current_date()) >= 85
             and datediff('day', enrollment_date, current_date()) > 30  then true
            when datediff('year', date_of_birth, current_date()) >= 75
             and datediff('day', enrollment_date, current_date()) > 60  then true
            when datediff('day', enrollment_date, current_date()) > 90  then true
            else false
        end as is_care_review_overdue_flag,

        -- ── Metadata ───────────────────────────────────────────────────────
        upper(trim(source_system))  as source_system,
        _loaded_at                  as loaded_timestamp,
        _source_file                as source_file,
        current_timestamp()         as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned