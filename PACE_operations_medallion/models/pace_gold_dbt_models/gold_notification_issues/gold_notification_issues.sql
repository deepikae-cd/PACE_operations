/*
  GOLD_NOTIFICATION_ISSUES
  ─────────────────────────────────────────────────────────────
  Purpose:
    Identifies problematic notifications for operational monitoring.

  Grain:
    notification_id

  Used For:
    - Alerting
    - SLA breaches
    - Retry failures
*/

with base as (

    select *
    from {{ ref('enterprise_silver_notification') }}

),

filtered as (

    select
        notification_id,
        center_id,
        channel,
        delivery_status,
        retry_count,
        send_delay_minutes,

        is_failed_flag,
        is_high_retry_flag,
        is_stuck_flag,
        is_late_send_flag,

        sent_at,
        scheduled_send_at

    from base
    where
        is_failed_flag
        or is_high_retry_flag
        or is_stuck_flag
        or is_late_send_flag

),

final as (

    select
        *,
        current_timestamp() as dbt_updated_timestamp
    from filtered

)

select * from final