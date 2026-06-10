/*
  INT_CLINICAL_ASSESSMENT
  ──────────────────────────────────────────────────────────────────────────────
  Purpose : Select most recent clinical assessment per participant.
            No business thresholds applied here.
  ──────────────────────────────────────────────────────────────────────────────
*/

with ranked as (

    select
        participant_id,
        assessment_id,
        assessment_date,
        cognitive_score,
        functional_score,

        row_number() over (
            partition by participant_id
            order by assessment_date desc
        ) as rn

    from {{ ref('staging_clinical_assessment') }}

)

select *
from ranked
where rn = 1