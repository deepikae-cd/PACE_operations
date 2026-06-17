/*
  GOLD_NOTIFICATION_ENGAGEMENT
  ─────────────────────────────────────────────────────────────
  Purpose:
    Measures user interaction with notifications.
    Used for product analytics and engagement tracking.

  Grain:
    notification_type + category + channel

*/

with base as (

    select *
    from {{ ref('enterprise_silver_notification') }}

),

aggregated as (

    select
        notification_type,
        notification_category,
        channel,

        count(*) as total_notifications,

        sum(case when is_delivered_flag then 1 else 0 end) as delivered_count,
        sum(case when is_read_flag then 1 else 0 end)      as read_count,
        sum(case when is_unread_flag then 1 else 0 end)    as unread_count,

        avg(hours_to_read) as avg_time_to_read_hours

    from base
    group by 1, 2, 3

),

final as (

    select
        *,

        read_count / nullif(delivered_count, 0) as read_rate,
        unread_count / nullif(delivered_count, 0) as unread_rate,

        current_timestamp() as dbt_updated_timestamp

    from aggregated

)

select * from final