/*
===============================================================================
MODEL NAME  : staging_identity_link
LAYER       : STAGING
DOMAIN      : IDENTITY / INTEGRATION

DESCRIPTION:
  Standardizes raw identity link data between systems such as EHR and CareLiva.
  Minimal transformation applied.

SOURCE:
  - bronze_identity.RAW_IDENTITY_LINK

GRAIN:
  One row per raw identity mapping record
===============================================================================
*/

select

    cast(participant_id as varchar) as participant_id,
    cast(ehr_id as varchar) as ehr_id,
    cast(careliva_id as varchar) as careliva_id,

    match_type,
    match_confidence_score,

    source_system,
    _loaded_at,
    _source_file

from {{ source('bronze_identity', 'RAW_IDENTITY_LINK') }}