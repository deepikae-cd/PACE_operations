/*
  STAGING_FAMILY_SUPPORT
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_family_support', 'RAW_FAMILY_SUPPORT') }}
  Purpose : Thin staging layer — select, rename, and basic null filtering only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select
        -- Keys
        support_id,
        participant_id,

        -- Descriptors (raw)
        relationship,
        can_administer_meds,
        support_frequency,

        -- Metadata
        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_family_support', 'RAW_FAMILY_SUPPORT') }}

),

filtered as (

    select *
    from source
    where support_id     is not null
      and participant_id is not null

)

select * from filtered