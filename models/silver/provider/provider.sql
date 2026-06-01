select
    provider_id,
    upper(provider_name) as provider_name,
    upper(provider_type) as provider_type,
    upper(city) as city,
    upper(state) as state,
    current_timestamp() as load_ts
from {{ source('bronze','provider_raw') }}