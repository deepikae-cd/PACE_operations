/*
  ENTERPRISE_SILVER_CAREGIVER_ASSIGNMENT
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('stg_caregiver_assignment') }}
  Purpose : Cleanse, deduplicate and enrich caregiver assignment records.
            Adds surrogate key, standardised assignment type, computed flags
            for active/expired assignments, and assignment duration in days.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select * from {{ ref('staging_caregiver_assignment') }}

    {% if is_incremental() %}
        where _loaded_at > (select max(loaded_timestamp) from {{ this }})
    {% endif %}

),

deduplicated as (

    select *,
           row_number() over (
               partition by assignment_id
               order by _loaded_at desc
           ) as _rn
    from source

),

cleaned as (

    select
        -- Surrogate key
        sha2(concat_ws('||', assignment_id, cast(_loaded_at as varchar))) as assignment_sk,

        -- Natural keys (normalised)
        trim(upper(assignment_id))   as assignment_id,
        trim(upper(caregiver_id))    as caregiver_id,
        trim(upper(participant_id))  as participant_id,

        -- Assignment type (controlled vocabulary)
        case
            when upper(trim(assignment_type)) in
                ('PRIMARY', 'BACKUP', 'SPECIALIST')
            then upper(trim(assignment_type))
            when assignment_type is null then 'UNKNOWN'
            else 'OTHER'
        end as assignment_type,

        -- Boolean flags
        -- Prefer source is_active but cross-check with end_date for safety
        case
            when is_active = true
             and (end_date is null or end_date >= current_date()) then true
            else false
        end as is_active_flag,

        -- Assignment has ended based on end_date regardless of is_active flag
        (end_date is not null and end_date < current_date()) as is_expired_flag,

        -- Primary caregiver flag — useful shortcut for downstream joins
        (upper(trim(assignment_type)) = 'PRIMARY') as is_primary_flag,

        -- Dates
        effective_date,
        end_date,

        -- Assignment duration
        case
            when effective_date is not null and end_date is not null
            then datediff('day', effective_date, end_date)
            when effective_date is not null
            then datediff('day', effective_date, current_date())
        end as assignment_duration_days,

        -- Long-tenured assignment flag (> 365 days)
        case
            when effective_date is not null
             and datediff(
                'day',
                effective_date,
                coalesce(end_date, current_date())
             ) > 365
            then true
            else false
        end as is_long_term_assignment_flag,

        -- Metadata
        upper(trim(source_system))  as source_system,
        _loaded_at                  as loaded_timestamp,
        _source_file                as source_file,
        current_timestamp()         as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned