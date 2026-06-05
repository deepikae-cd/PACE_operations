/*
  ENTERPRISE_SILVER_COMPLIANCE_VIOLATIONS
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('staging_compliance_violation') }}
  Purpose : Cleanse, deduplicate and enrich compliance violation records.
            Adds surrogate key, standardised vocabularies, computed flags
            for open/critical violations, and time-to-resolution metrics.
  ──────────────────────────────────────────────────────────────────────────────
*/



with source as (

    select * from {{ ref('staging_compliance_violation') }}

    {% if is_incremental() %}
        where _loaded_at > (select max(loaded_timestamp) from {{ this }})
    {% endif %}

),

deduplicated as (

    select *,
           row_number() over (
               partition by violation_id
               order by _loaded_at desc
           ) as _rn
    from source

),

cleaned as (

    select
        -- Surrogate key
        sha2(concat_ws('||', violation_id, cast(_loaded_at as varchar))) as violation_sk,

        -- Natural keys (normalised)
        trim(upper(violation_id))  as violation_id,
        trim(upper(rule_id))       as rule_id,
        trim(upper(entity_id))     as entity_id,
        trim(upper(center_id))     as center_id,

        -- Entity type (controlled vocabulary)
        case
            when upper(trim(entity_type)) in (
                'PARTICIPANT', 'APPOINTMENT', 'CLINICAL_VISIT',
                'CAREGIVER', 'MEDICATION', 'CARE_PLAN'
            ) then upper(trim(entity_type))
            when entity_type is null then 'UNKNOWN'
            else 'OTHER'
        end as entity_type,

        trim(violation_description) as violation_description,

        -- Severity (controlled vocabulary — ordered for sort/filter)
        case
            when upper(trim(severity)) in
                ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW')
            then upper(trim(severity))
            when severity is null then 'UNKNOWN'
            else 'OTHER'
        end as severity,

        -- Severity rank (useful for ordering in reports)
        case
            when upper(trim(severity)) = 'CRITICAL' then 1
            when upper(trim(severity)) = 'HIGH'     then 2
            when upper(trim(severity)) = 'MEDIUM'   then 3
            when upper(trim(severity)) = 'LOW'      then 4
            else 99
        end as severity_rank,

        -- Status (controlled vocabulary)
        case
            when upper(trim(status)) in
                ('OPEN', 'RESOLVED', 'WAIVED', 'ESCALATED')
            then upper(trim(status))
            when status is null then 'UNKNOWN'
            else 'OTHER'
        end as status,

        -- Boolean status flags
        (upper(trim(status)) = 'OPEN')       as is_open_flag,
        (upper(trim(status)) = 'RESOLVED')   as is_resolved_flag,
        (upper(trim(status)) = 'WAIVED')     as is_waived_flag,
        (upper(trim(status)) = 'ESCALATED')  as is_escalated_flag,

        -- Boolean severity flags
        (upper(trim(severity)) = 'CRITICAL') as is_critical_flag,
        (upper(trim(severity)) = 'HIGH')     as is_high_severity_flag,

        -- Open + critical combined — highest priority for ops dashboards
        (
            upper(trim(status))   = 'OPEN'
            and upper(trim(severity)) in ('CRITICAL', 'HIGH')
        ) as is_open_critical_flag,

        -- Timestamps
        violation_date,
        resolved_at,
        trim(resolved_by) as resolved_by,

        -- Time to resolution in hours (null if still open)
        case
            when violation_date is not null and resolved_at is not null
            then datediff('hour', violation_date, resolved_at)
        end as resolution_hours,

        -- Time to resolution in days
        case
            when violation_date is not null and resolved_at is not null
            then datediff('day', violation_date, resolved_at)
        end as resolution_days,

        -- Age of violation in days (open violations only)
        case
            when upper(trim(status)) = 'OPEN'
             and violation_date is not null
            then datediff('day', violation_date, current_date())
        end as open_age_days,

        -- SLA breach flag — CRITICAL > 1 day, HIGH > 3 days, others > 7 days
        case
            when upper(trim(status)) != 'OPEN' then false
            when upper(trim(severity)) = 'CRITICAL'
             and datediff('day', violation_date, current_date()) > 1  then true
            when upper(trim(severity)) = 'HIGH'
             and datediff('day', violation_date, current_date()) > 3  then true
            when upper(trim(severity)) in ('MEDIUM', 'LOW')
             and datediff('day', violation_date, current_date()) > 7  then true
            else false
        end as is_sla_breached_flag,

        -- Metadata
        upper(trim(source_system))  as source_system,
        _loaded_at                  as loaded_timestamp,
        _source_file                as source_file,
        current_timestamp()         as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned