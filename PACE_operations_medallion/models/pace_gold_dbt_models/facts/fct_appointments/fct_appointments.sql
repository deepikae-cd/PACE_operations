select

    appointment_id,

    -- Foreign keys
    participant_id,
    provider_id,
    center_id,

    -- Metrics
    appointment_date,
    appointment_status,

    case when appointment_status = 'completed' then 1 else 0 end as completed_flag,
    case when appointment_status = 'no_show' then 1 else 0 end as no_show_flag,

    current_timestamp as loaded_at

from {{ ref('staging_appointment') }}