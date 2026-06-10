/*
  STAGING_PACE_CENTER
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_organization', 'RAW_PACE_CENTER') }}
  Purpose : Thin staging layer — select, rename, and basic normalization only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select
        -- Keys
        trim(upper(pace_center_id)) as pace_center_id,

        -- Descriptors
        trim(center_name)            as center_name,
        trim(region)                 as region,

        -- Metadata
        _loaded_at                   as loaded_at,
        current_timestamp            as stg_loaded_at

    from {{ source('bronze_organization', 'RAW_PACE_CENTER') }}

),

filtered as (

    -- Drop unusable records
    select *
    from source
    where pace_center_id is not null

)

select * from filtered