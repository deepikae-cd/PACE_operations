select

    rule_id,

    upper(trim(rule_name)) as rule_name,

    upper(trim(rule_type)) as rule_type,

    trim(description) as rule_description,

    effective_date,

    upper(trim(status)) as rule_status,

    created_ts as source_created_ts,

    current_timestamp() as load_ts,

    case
        when upper(status) = 'ACTIVE' then 1
        else 0
    end as active_flag,

    case
        when upper(status) = 'INACTIVE' then 1
        else 0
    end as inactive_flag,

    case
        when effective_date <= current_date()
             and upper(status) = 'ACTIVE'
        then 'CURRENT'

        when effective_date > current_date()
        then 'FUTURE'

        else 'EXPIRED'
    end as rule_lifecycle_status,

    datediff(
        day,
        effective_date,
        current_date()
    ) as days_since_effective

from {{ source('bronze','governance_rules_raw') }}