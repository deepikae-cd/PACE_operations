select
    participant_id,
    center_id,

    count(*) as total_followups,
    count_if(is_follow_up_overdue_flag) as overdue_followups,

    count_if(follow_up_required) as required_followups,

    current_timestamp as dbt_updated_timestamp

from {{ ref('fct_idt_clinical_visit') }}

group by participant_id, center_id