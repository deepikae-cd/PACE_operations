select
    trim(upper(pace_center_id)) as pace_center_id,
    trim(center_name)           as center_name,
    trim(region)                as region,

    _loaded_at                  as loaded_at,
    current_timestamp           as stg_loaded_at

from {{ source('bronze_organization', 'RAW_PACE_CENTER') }}
