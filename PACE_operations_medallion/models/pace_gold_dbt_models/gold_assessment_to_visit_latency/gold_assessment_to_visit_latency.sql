/*
===============================================================================
Model: gold_assessment_to_visit_latency
Purpose:
  Measures time between clinical assessment and first subsequent visit.

Grain:
  assessment_id
===============================================================================
*/

with assessment as (

    select *
    from {{ ref('fct_clinical_assessment') }}

),

visit as (

    select *
    from {{ ref('fct_idt_clinical_visit') }}

),

joined as (

    select
        a.assessment_id,
        a.participant_id,
        a.assessment_day,

        min(v.visit_date) as first_visit_date

    from assessment a
    left join visit v
        on a.participant_id = v.participant_id
        and v.visit_date >= a.assessment_day

    group by 1,2,3

),

final as (

    select

        assessment_id,
        participant_id,
        assessment_day,
        first_visit_date,

        -- ⏱️ CORE METRIC
        datediff('day', assessment_day, first_visit_date) as days_to_first_visit,

        --  Flags
        case
            when first_visit_date is null then true
            else false
        end as no_follow_up_visit_flag,

        case
            when datediff('day', assessment_day, first_visit_date) > 7 then true
            else false
        end as delayed_visit_flag,

        current_timestamp() as dbt_updated_timestamp

    from joined

)

select * from final
