select
    caregiver_id,
    upper(trim(caregiver_name)) as caregiver_name,

    regexp_replace(phone,'[^0-9]','') as phone,

    upper(trim(specialization)) as specialization,

    upper(trim(status)) as caregiver_status,

    created_ts as source_created_ts,

    current_timestamp() as load_ts,

    case
        when upper(status) = 'ACTIVE' then 1
        else 0
    end as active_flag,

    case
        when upper(status) = 'INACTIVE' then 1
        else 0
    end as inactive_flag

from PACE_DW.BRONZE.caregiver_raw