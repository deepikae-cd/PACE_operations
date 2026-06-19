/*
===============================================================================
MODEL NAME  : enterprise_silver_provider_credential
LAYER       : SILVER
DOMAIN      : PROVIDER / CREDENTIALING
OWNER       : DATA ENGINEERING
VERSION     : 1.0

-------------------------------------------------------------------------------
DESCRIPTION:
  Cleanses, standardizes, and deduplicates provider credential records.
  Applies normalization, lifecycle flags, and expiry logic.

  Adds:
    - Surrogate key
    - Standardized credential status
    - Expiry calculations
    - Compliance flags

GRAIN:
  One row per provider_id + credential_id (latest record)

SOURCE:
  - staging_provider_credential
-------------------------------------------------------------------------------
*/

{{ config(
    materialized='incremental',
    unique_key='provider_credential_sk',
    tags=['silver', 'provider', 'credential']
) }}

with source as (

    select *
    from {{ ref('staging_provider_credential') }}

    {% if is_incremental() %}
        where _loaded_at > (select max(loaded_timestamp) from {{ this }})
    {% endif %}

),

deduplicated as (

    select *,
        row_number() over (
            partition by provider_id, credential_id
            order by _loaded_at desc
        ) as _rn

    from source

),

cleaned as (

    select

        -- ✅ Surrogate key
        sha2(concat_ws('||', provider_id, credential_id, cast(_loaded_at as varchar)), 256)
            as provider_credential_sk,

        -- ✅ Business keys
        trim(upper(provider_id))   as provider_id,
        trim(upper(credential_id)) as credential_id,

        -- ✅ Credential info
        trim(upper(credential_type)) as credential_type,
        initcap(trim(credential_name)) as credential_name,

        -- ✅ Status standardization
        case
            when upper(trim(credential_status)) in ('ACTIVE','INACTIVE','EXPIRED','SUSPENDED')
                then upper(trim(credential_status))
            when credential_status is null then 'UNKNOWN'
            else 'OTHER'
        end as credential_status,

        -- ✅ Dates
        to_date(issue_date)      as issue_date,
        to_date(expiration_date) as expiration_date,

        -- ✅ Expiry calculations
        case
            when expiration_date is not null
                then datediff('day', current_date(), expiration_date)
        end as days_until_expiry,

        case
            when expiration_date < current_date() then true
            else false
        end as is_expired_flag,

        case
            when expiration_date between current_date() and dateadd('day', 30, current_date())
                then true else false
        end as is_expiring_soon_flag,

        -- ✅ Active validity
        case
            when expiration_date >= current_date()
             and upper(trim(credential_status)) = 'ACTIVE'
            then true else false
        end as is_valid_flag,

        -- ✅ Compliance flags
        (expiration_date is null) as is_missing_expiration_flag,

        -- Metadata
        upper(trim(source_system)) as source_system,
        _loaded_at as loaded_timestamp,
        _source_file as source_file,

        current_timestamp() as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned
