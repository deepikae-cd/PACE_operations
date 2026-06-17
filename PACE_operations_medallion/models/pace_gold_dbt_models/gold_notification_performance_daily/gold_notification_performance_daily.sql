/*
  GOLD_NOTIFICATION_PERFORMANCE_DAILY
  ─────────────────────────────────────────────────────────────
  Purpose:
    Aggregated KPI table for notification delivery performance.
    Used in dashboards for tracking success rate, failures,
    delays, and engagement by day, center, and channel.

  Grain:
    1 row per (date, center_id, channel)

  Key Metrics:
    - total notifications
    - delivery success rate
    - failure rate
    - avg send delay
    - avg read time

  Notes:
    - Built from silver model (clean + standardized)
    - Optimized for BI queries (no heavy joins needed)
*/

with base as (

    select *
    from {{ ref('enterprise_silver_notification_service') }}

),

aggregated as (

    select
        date_trunc('day', sent_at) as notification_date,

        center_id,
        channel,

        -- Volume metrics
        count(*) as total_notifications,

        -- Delivery metrics
        sum(case when is_delivered_flag then 1 else 0 end) as delivered_count,
        sum(case when is_failed_flag then 1 else 0 end)    as failed_count,

        -- Engagement metrics
        sum(case when is_read_flag then 1 else 0 end)      as read_count,

        -- Time metrics
        avg(send_delay_minutes) as avg_send_delay_minutes,
        avg(hours_to_read)      as avg_hours_to_read,

        -- Reliability metrics
        sum(case when is_high_retry_flag then 1 else 0 end) as high_retry_count,
        sum(case when is_stuck_flag then 1 else 0 end) as stuck_count

    from base
    where sent_at is not null
    group by 1, 2, 3

),

final as (

    select
        *,

        -- KPIs
        delivered_count / nullif(total_notifications, 0) as delivery_rate,
        failed_count / nullif(total_notifications, 0)    as failure_rate,
        read_count / nullif(delivered_count, 0)          as read_rate,

        current_timestamp() as dbt_updated_timestamp

    from aggregated

)

select * from final
