/*
  INT_FAMILY_SUPPORT_STATUS
  ──────────────────────────────────────────────────────────────────────────────
  Purpose : Aggregate family support into participant-level flag.
  ──────────────────────────────────────────────────────────────────────────────
*/

with base as (

    select
        participant_id,

        case
            when lower(can_administer_meds) in ('yes','y','true','1')
            then 1 else 0
        end as can_administer_flag

    from {{ ref('staging_family_support') }}

)

select
    participant_id,
    max(can_administer_flag) as can_administer_meds

from base
group by participant_id