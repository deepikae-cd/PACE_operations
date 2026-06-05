/*
  STAGING_PROVIDER
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_provider', 'RAW_PROVIDER') }}
  Purpose : Thin staging layer — select, rename, and basic null filtering only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select
        -- Keys
        provider_id,
        npi_number,
        tax_id,
        center_id,

        -- Descriptors (raw — no business logic here)
        provider_name,
        provider_type,
        provider_subtype,
        specialty,
        network_status,

        -- Contract dates
        contract_start_date,
        contract_end_date,

        -- Contact / address
        address_line1,
        city,
        state,
        zip_code,
        phone_number,
        fax_number,

        -- Flags (raw)
        accepts_telehealth,
        accepts_pace_patients,

        -- Metadata
        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_provider', 'RAW_PROVIDER') }}

),

filtered as (

    -- Drop records that can never be meaningful downstream
    select *
    from source
    where provider_id is not null
      and provider_name is not null

)

select * from filtered