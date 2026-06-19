/*
===============================================================================
MODEL NAME  : staging_provider_credential
LAYER       : STAGING (BRONZE → STANDARDIZED)
DOMAIN      : PROVIDER / CREDENTIALING
OWNER       : DATA ENGINEERING
VERSION     : 1.0

-------------------------------------------------------------------------------
DESCRIPTION:
  Ingests raw provider credential data from source systems and applies
  minimal transformation including column selection, renaming, and
  basic normalization.

  This model acts as the standardized staging layer before silver processing.

GRAIN:
  One row per raw record (no deduplication applied)

SOURCE:
  - raw_provider_credential (source table)
-------------------------------------------------------------------------------
*/

{{ config(
    materialized='view',
    tags=['staging', 'provider', 'credential']
) }}

select

    -- ✅ Raw identifiers
    cast(provider_id as varchar)   as provider_id,
    cast(credential_id as varchar) as credential_id,

    -- ✅ Credential fields
    credential_type,
    credential_name,
    credential_status,

    -- ✅ Dates
    cast(issue_date as date)       as issue_date,
    cast(expiration_date as date)  as expiration_date,

    -- ✅ Metadata
    source_system,
    _loaded_at,
    _source_file

from {{ source('raw', 'provider_credential') }}