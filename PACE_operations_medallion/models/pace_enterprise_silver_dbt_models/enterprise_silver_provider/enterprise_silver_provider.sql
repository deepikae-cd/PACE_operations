/*
  ENTERPRISE_SILVER_PROVIDER
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_provider', 'RAW_PROVIDER') }}

  Purpose : Cleanse, deduplicate, and standardise provider (external vendor)
            records. Normalises provider type, network status, and contract
            attributes. Computes active contract flag for downstream analysis.

  Logic   :
            - Deduplicates using latest _loaded_at per provider_id
            - Standardises categorical fields (provider_type, network_status)
            - Generates surrogate key (provider_sk)
            - Computes contract active flag based on date range
            - Cleans address and contact fields

  Grain   : One record per provider_id (latest version)

  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select * from {{ source('bronze_provider', 'RAW_PROVIDER') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by provider_id
               order by _loaded_at desc
           ) as _rn
    from source
    where provider_id   is not null
      and provider_name is not null

),

cleaned as (

    select
        -- Keys
        sha2(concat_ws('||', provider_id, cast(_loaded_at as varchar))) as provider_sk,
        trim(upper(provider_id))  as provider_id,
        trim(initcap(provider_name)) as provider_name,

        -- Provider classification
        case
            when upper(trim(provider_type)) in
                ('SPECIALIST','HOSPITAL','LAB','PHARMACY','SNF',
                 'HOME_HEALTH','DURABLE_MEDICAL')
            then upper(trim(provider_type))
            when provider_type is null then 'UNKNOWN'
            else 'OTHER'
        end as provider_type,

        trim(provider_subtype) as provider_subtype,
        trim(upper(npi_number)) as npi_number,
        trim(upper(tax_id))     as tax_id,
        trim(specialty)         as specialty,

        -- Network status
        case
            when upper(trim(network_status)) in
                ('IN_NETWORK','OUT_OF_NETWORK','PREFERRED')
            then upper(trim(network_status))
            else 'UNKNOWN'
        end as network_status,
        try_cast(contract_start_date as date) as contract_start_date,
        try_cast(contract_end_date   as date) as contract_end_date,

        -- Contract flag
        (
            try_cast(contract_start_date as date) <= current_date()
            and (
                contract_end_date is null
                or try_cast(contract_end_date as date) >= current_date()
            )
        ) as is_contract_active_flag,

        -- Capabilities
        coalesce(accepts_telehealth, false)     as accepts_telehealth,
        coalesce(accepts_pace_patients, false)  as accepts_pace_patients,

        -- Address and contact
        trim(address_line1) as address_line1,
        trim(city)          as city,
        upper(trim(state))  as state,
        left(regexp_replace(zip_code, '[^0-9]', ''), 5) as zip_code,

        regexp_replace(phone_number, '[^0-9+]', '') as phone_number,
        regexp_replace(fax_number,  '[^0-9+]', '') as fax_number,

        trim(upper(center_id)) as center_id,

        -- Metadata
        upper(trim(source_system)) as source_system,
        _loaded_at                as loaded_timestamp,
        current_timestamp()       as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned