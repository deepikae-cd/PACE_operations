select
    participant_id,

    count_if(is_high_acuity_location_flag) as hospital_visits,

    count_if(is_follow_up_overdue_flag) as missed_followups,

    count_if(is_o2_low_flag) as respiratory_risk,

    case
        when count_if(is_high_acuity_location_flag) > 2 then 'HIGH_RISK'
        when count_if(is_follow_up_overdue_flag) > 1 then 'MEDIUM_RISK'
        else 'LOW_RISK'
    end as risk_level

from {{ ref('fact_idt_clinical_visit') }}

group by participant_id
