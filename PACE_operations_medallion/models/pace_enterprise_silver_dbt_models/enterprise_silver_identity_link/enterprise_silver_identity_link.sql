/*
===============================================================================
MODEL NAME  : enterprise_silver_identity_link
LAYER       : SILVER
DOMAIN      : IDENTITY / MASTER DATA

DESCRIPTION:
  Cleanses and deduplicates identity link records across systems.
  Adds surrogate keys, standardization, and match confidence classification.

GRAIN:
  One row per participant_id + source_system (latest record)

SOURCE:
  - staging_identity_link
===============================================================================
*/



with source as (

    select *
    from {{ ref('staging_identity_link') }}

    {% if is_incremental() %}
        where _loaded_at > (select max(loaded_timestamp) from {{ this }})
    {% endif %}

),

deduplicated as (

    select *,
        row_number() over (
            partition by participant_id, source_system
            order by _loaded_at desc
        ) as _rn
    from source

),

cleaned as (

    select

        -- ✅ Surrogate key
        sha2(concat_ws('||', participant_id, source_system, cast(_loaded_at as varchar)), 256)
            as identity_link_sk,

        -- ✅ Keys
        trim(upper(participant_id)) as participant_id,
        trim(upper(ehr_id)) as ehr_id,
        trim(upper(careliva_id)) as careliva_id,

        trim(upper(source_system)) as source_system,

        -- ✅ Match fields
        match_type,
        match_confidence_score,

        -- ✅ Standard classification
        case
            when match_confidence_score >= 0.9 then 'HIGH'
            when match_confidence_score >= 0.7 then 'MEDIUM'
            else 'LOW'
        end as match_confidence_level,

        (match_confidence_score >= 0.8) as is_strong_match_flag,

        case
            when ehr_id is not null and careliva_id is not null
            then true else false
        end as is_cross_system_link_flag,

        -- Metadata
        _loaded_at as loaded_timestamp,
        _source_file,
        current_timestamp() as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned