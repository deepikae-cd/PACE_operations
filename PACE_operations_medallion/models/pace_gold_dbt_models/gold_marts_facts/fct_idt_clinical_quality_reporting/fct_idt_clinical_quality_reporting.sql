select
    center_id,

    count(*) as total_visits,

    count_if(is_vitals_complete_flag) as complete_vitals,

    count_if(is_heart_rate_abnormal_flag) as abnormal_hr,
    count_if(is_temperature_abnormal_flag) as abnormal_temp,
    count_if(is_o2_low_flag) as low_o2,

    round(100 * count_if(is_vitals_complete_flag) / count(*), 2) as vitals_completeness_pct,

    current_timestamp as dbt_updated_timestamp

from {{ ref('fact_idt_clinical_visit') }}

group by center_id