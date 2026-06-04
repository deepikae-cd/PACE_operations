/*
  ENTERPRISE_SILVER_GOVERNANCE_VIOLATIONS
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_governance', 'RAW_COMPLIANCE_VIOLATIONS') }}

  Purpose : Cleanse, deduplicate, and standardise compliance violation records.
            Normalises entity type, severity, and status values.
            Computes lifecycle flags such as is_open.

  Logic   :
            - Deduplicates using latest _loaded_at per violation_id
            - Standardises categorical fields
            - Generates surrogate key (violation_sk)
            - Flags open violations (is_open_flag)

  Grain   : One record per violation_id (latest version)
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select * from {{ source('bronze_governance', 'RAW_COMPLIANCE_VIOLATIONS') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by violation_id
               order by _loaded_at desc
           ) as _rn
    from source
    where violation_id   is not null
      and rule_id        is not null
      and violation_date is not null

),

cleaned as (

    select
        -- Keys
        sha2(concat_ws('||', violation_id, cast(_loaded_at as varchar))) as violation_sk,
        trim(upper(violation_id)) as violation_id,
        trim(upper(rule_id))      as rule_id,

        -- Entity
        case
            when upper(trim(entity_type)) in
                ('PARTICIPANT','APPOINTMENT','CLINICAL_VISIT','MEAL_DELIVERY',
                 'TRANSPORTATION','CAREGIVER','PROVIDER','NOTIFICATION')
            then upper(trim(entity_type))
            else 'UNKNOWN'
        end as entity_type,

        trim(upper(entity_id)) as entity_id,
        violation_date,
        trim(violation_description) as violation_description,

        -- Severity
        case
            when upper(trim(severity)) in ('CRITICAL','HIGH','MEDIUM','LOW')
            then upper(trim(severity))
            else 'UNKNOWN'
        end as severity,

        -- Status
        case
            when upper(trim(status)) in ('OPEN','RESOLVED','WAIVED','ESCALATED')
            then upper(trim(status))
            else 'UNKNOWN'
        end as status,

        (upper(trim(status)) = 'OPEN') as is_open_flag,
        resolved_at as resolved_timestamp,

        trim(resolved_by) as resolved_by,
        trim(upper(center_id)) as center_id,

        upper(trim(source_system)) as source_system,
        _loaded_at as loaded_timestamp,
        current_timestamp() as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned