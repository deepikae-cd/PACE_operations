/*
  ENTERPRISE_SILVER_PROVIDER
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('staging_provider') }}
  Purpose : Cleanse, deduplicate and enrich provider records.
            Adds surrogate key, standardised vocabularies, computed flags
            for network status / contract activity, and contract duration metrics.
  ──────────────────────────────────────────────────────────────────────────────
*/



with source as (

    select * from {{ ref('staging_provider') }}

    {% if is_incremental() %}
        where _loaded_at > (select max(loaded_timestamp) from {{ this }})
    {% endif %}

),

deduplicated as (

    select *,
           row_number() over (
               partition by provider_id
               order by _loaded_at desc
           ) as _rn
    from source

),

cleaned as (

    select
        -- Surrogate key
        sha2(concat_ws('||', provider_id, cast(_loaded_at as varchar))) as provider_sk,

        -- Natural keys (normalised)
        trim(upper(provider_id))  as provider_id,
        trim(upper(npi_number))   as npi_number,
        trim(upper(tax_id))       as tax_id,
        trim(upper(center_id))    as center_id,

        -- Provider name
        trim(provider_name) as provider_name,

        -- Provider type (controlled vocabulary)
        case
            when upper(trim(provider_type)) in (
                'SPECIALIST', 'HOSPITAL', 'LAB', 'PHARMACY', 'SNF'
            ) then upper(trim(provider_type))
            when provider_type is null then 'UNKNOWN'
            else 'OTHER'
        end as provider_type,

        -- Provider subtype (controlled vocabulary)
        case
            when upper(trim(provider_subtype)) in (
                'CARDIOLOGY', 'ORTHOPEDICS', 'DIALYSIS',
                'NEUROLOGY', 'ONCOLOGY', 'RADIOLOGY', 'PRIMARY_CARE'
            ) then upper(trim(provider_subtype))
            when provider_subtype is null then 'UNKNOWN'
            else 'OTHER'
        end as provider_subtype,

        trim(specialty) as specialty,

        -- Network status (controlled vocabulary)
        case
            when upper(trim(network_status)) in (
                'IN_NETWORK', 'OUT_OF_NETWORK', 'PREFERRED'
            ) then upper(trim(network_status))
            when network_status is null then 'UNKNOWN'
            else 'OTHER'
        end as network_status,

        -- Boolean network status flags
        (upper(trim(network_status)) = 'IN_NETWORK')      as is_in_network_flag,
        (upper(trim(network_status)) = 'OUT_OF_NETWORK')  as is_out_of_network_flag,
        (upper(trim(network_status)) = 'PREFERRED')       as is_preferred_flag,

        -- Contract dates
        contract_start_date,
        contract_end_date,

        -- Active contract flag — contract has started and not yet expired (or no end date)
        case
            when contract_start_date is null then false
            when contract_start_date > current_date() then false
            when contract_end_date is not null
             and contract_end_date < current_date() then false
            else true
        end as is_contract_active_flag,

        -- Contract duration in days (null if no end date)
        case
            when contract_start_date is not null and contract_end_date is not null
            then datediff('day', contract_start_date, contract_end_date)
        end as contract_duration_days,

        -- Days until contract expiry (null if no end date or already expired)
        case
            when contract_end_date is not null
             and contract_end_date >= current_date()
            then datediff('day', current_date(), contract_end_date)
        end as days_until_contract_expiry,

        -- Contract expiring soon flag — within 30 days
        case
            when contract_end_date is not null
             and contract_end_date >= current_date()
             and datediff('day', current_date(), contract_end_date) <= 30
            then true
            else false
        end as is_contract_expiring_soon_flag,

        -- Contact / address (normalised)
        trim(address_line1)  as address_line1,
        trim(city)           as city,
        trim(upper(state))   as state,
        trim(zip_code)       as zip_code,
        trim(phone_number)   as phone_number,
        trim(fax_number)     as fax_number,

        -- Boolean capability flags
        coalesce(accepts_telehealth,    false) as accepts_telehealth_flag,
        coalesce(accepts_pace_patients, false) as accepts_pace_patients_flag,

        -- High-priority combined flag — preferred, active, and accepts PACE
        (
            upper(trim(network_status)) = 'PREFERRED'
            and coalesce(accepts_pace_patients, false) = true
            and (
                contract_end_date is null
                or contract_end_date >= current_date()
            )
        ) as is_preferred_active_pace_flag,

        -- Metadata
        upper(trim(source_system))  as source_system,
        _loaded_at                  as loaded_timestamp,
        _source_file                as source_file,
        current_timestamp()         as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned