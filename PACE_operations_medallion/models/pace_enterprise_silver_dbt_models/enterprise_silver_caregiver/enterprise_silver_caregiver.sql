/*
  ENTERPRISE_SILVER_CAREGIVER
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('staging_caregiver') }}
  Purpose : Cleanse, deduplicate and enrich caregiver records.
            Adds surrogate key, standardised vocabularies, computed flags:
            license expiry status, employment tenure, and capacity flags.
  ──────────────────────────────────────────────────────────────────────────────
*/



with source as (

    select * from {{ ref('staging_caregiver') }}

    {% if is_incremental() %}
        where _loaded_at > (select max(loaded_timestamp) from {{ this }})
    {% endif %}

),

deduplicated as (

    select *,
           row_number() over (
               partition by caregiver_id
               order by _loaded_at desc
           ) as _rn
    from source

),

cleaned as (

    select
        -- Surrogate key
        sha2(concat_ws('||', caregiver_id, cast(_loaded_at as varchar))) as caregiver_sk,

        -- Natural keys (normalised)
        trim(upper(caregiver_id))   as caregiver_id,
        trim(upper(center_id))      as center_id,
        trim(upper(supervisor_id))  as supervisor_id,

        -- Personal
        initcap(trim(first_name))   as first_name,
        initcap(trim(last_name))    as last_name,
        initcap(trim(first_name))
            || ' ' ||
        initcap(trim(last_name))    as full_name,

        -- Caregiver type (controlled vocabulary)
        case
            when upper(trim(caregiver_type)) in (
                'NURSE', 'SOCIAL_WORKER', 'THERAPIST',
                'HOME_AIDE', 'PHYSICIAN', 'DIETITIAN', 'DRIVER'
            ) then upper(trim(caregiver_type))
            when caregiver_type is null then 'UNKNOWN'
            else 'OTHER'
        end as caregiver_type,

        initcap(trim(specialty)) as specialty,

        -- License
        trim(upper(license_number)) as license_number,
        trim(upper(license_state))  as license_state,
        license_expiry_date,

        -- License status as of today
        case
            when license_expiry_date is null                    then 'NO_LICENSE'
            when license_expiry_date < current_date()          then 'EXPIRED'
            when license_expiry_date < dateadd('day', 30, current_date()) then 'EXPIRING_SOON'
            else 'VALID'
        end as license_status,

        (license_expiry_date is not null
            and license_expiry_date < current_date())          as is_license_expired_flag,

        (license_expiry_date is not null
            and license_expiry_date
                between current_date()
                and dateadd('day', 30, current_date()))        as is_license_expiring_soon_flag,

        -- Employment
        hire_date,
        termination_date,

        case
            when upper(trim(employment_status)) in
                ('ACTIVE', 'TERMINATED', 'ON_LEAVE')
            then upper(trim(employment_status))
            when employment_status is null then 'UNKNOWN'
            else 'OTHER'
        end as employment_status,

        -- Boolean employment flags
        (upper(trim(employment_status)) = 'ACTIVE')      as is_active_flag,
        (upper(trim(employment_status)) = 'TERMINATED')  as is_terminated_flag,
        (upper(trim(employment_status)) = 'ON_LEAVE')    as is_on_leave_flag,

        -- Tenure in days (null if not yet terminated = still active)
        case
            when hire_date is not null and termination_date is not null
            then datediff('day', hire_date, termination_date)
            when hire_date is not null
            then datediff('day', hire_date, current_date())
        end as tenure_days,

        -- Capacity
        max_participant_load,
        (max_participant_load is null or max_participant_load = 0) as is_capacity_undefined_flag,

        -- Metadata
        upper(trim(source_system))  as source_system,
        _loaded_at                  as loaded_timestamp,
        _source_file                as source_file,
        current_timestamp()         as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned