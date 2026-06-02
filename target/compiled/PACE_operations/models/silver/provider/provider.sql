select

    provider_id,

    upper(trim(provider_name)) as provider_name,

    upper(trim(specialty)) as specialty,

    license_number,

    regexp_replace(phone,'[^0-9]','') as phone,

    upper(coalesce(status,'ACTIVE')) as provider_status,

    created_ts,

    current_timestamp() as load_ts

from PACE_DW.BRONZE.provider_raw

qualify row_number()
over (
    partition by provider_id
    order by created_ts desc
) = 1