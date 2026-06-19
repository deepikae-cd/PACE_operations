/*
===============================================================================
MODEL NAME  : gold_provider_credential
LAYER       : GOLD
DOMAIN      : PROVIDER / CREDENTIALING
OWNER       : DATA ENGINEERING
VERSION     : 1.0

-------------------------------------------------------------------------------
DESCRIPTION:
  Gold-layer model that tracks provider credential lifecycle, status, and
  compliance risk. Provides standardized credential information including
  license type, issue/expiry dates, and risk classification.

  This model supports:
    - UC-14: Provider lifecycle and credentialing
    - Compliance monitoring
    - Expiry tracking and operational alerts

GRAIN:
  One row per provider_id + credential_type

DEPENDENCIES:
  - enterprise_silver_provider_credential
-------------------------------------------------------------------------------
*/

{{ config(
    materialized='table',
    tags=['gold', 'provider', 'credential'],
    cluster_by=['provider_id'],
    persist_docs={"relation": true, "columns": true}
) }}

with base as (

    select *
    from {{ ref('enterprise_silver_provider_credential') }}

),

cleaned as (

    select

        -- Surrogate Key
        sha2(concat_ws('||', provider_id, credential_type), 256) as provider_credential_sk,

        -- Business keys
        provider_id,
        trim(upper(credential_type)) as credential_type,

        -- Credential attributes
        trim(credential_name) as credential_name,
        trim(upper(credential_status)) as credential_status,

        -- Dates
        issue_date,
        expiration_date,

        -- ✅ Derived expiry logic
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
                then true
            else false
        end as is_expiring_soon_flag,

        -- ✅ Active flag
        case
            when expiration_date >= current_date()
             and upper(credential_status) = 'ACTIVE'
            then true else false
        end as is_currently_active_flag

    from base

),

final as (

    select

        provider_credential_sk,
        provider_id,
        credential_type,
        credential_name,
        credential_status,

        issue_date,
        expiration_date,
        days_until_expiry,

        is_expired_flag,
        is_expiring_soon_flag,
        is_currently_active_flag,

        -- ✅ Compliance status
        case
            when is_expired_flag then 'EXPIRED'
            when is_expiring_soon_flag then 'EXPIRING_SOON'
            when is_currently_active_flag then 'ACTIVE'
            else 'UNKNOWN'
        end as credential_compliance_status,

        -- ✅ Risk level
        case
            when is_expired_flag then 'HIGH'
            when is_expiring_soon_flag then 'MEDIUM'
            else 'LOW'
        end as credential_risk_level,

        -- ✅ BI-friendly flags
        (is_expired_flag or is_expiring_soon_flag)
            as is_credential_at_risk_flag,

        (is_currently_active_flag and not is_expiring_soon_flag)
            as is_fully_compliant_flag,

        -- Metadata
        current_timestamp() as dbt_updated_timestamp

    from cleaned

)

select * from final
