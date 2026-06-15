select
    provider_id,
    center_id,
    date(visit_date) as activity_date,

    count(visit_id) as daily_visits,
    sum(visit_duration_minutes) as total_minutes,

    count_if(is_high_acuity_location_flag) as high_acuity_visits,

    current_timestamp as dbt_updated_timestamp

from {{ ref('fact_idt_clinical_visit') }}

group by
    provider_id,
    center_id,
    date(visit_date)