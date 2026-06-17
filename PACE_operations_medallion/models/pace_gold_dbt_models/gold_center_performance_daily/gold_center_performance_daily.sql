/*
===============================================================================
Model: gold_center_performance_daily
Purpose:
  Daily KPIs for center-level operational performance.

Grain:
  date + center_id
===============================================================================
*/

with base as (

    select *
    from {{ ref('enterprise_silver_notification') }}

),

aggregated as (

    select
        date_trunc('day', sent_at) as metric_date,
        center_id,

        count(*) as total_notifications,

        sum(case when is_delivered_flag then 1 else 0 end) as delivered_count,
        sum(case when is_failed_flag then 1 else 0 end) as failed_count,
        sum(case when is_read_flag then 1 else 0 end) as read_count,

        avg(send_delay_minutes) as avg_send_delay_minutes,
        avg(hours_to_read) as avg_hours_to_read

    from base
    where center_id is not null
    group by 1, 2

),

final as (

    select
        *,
        delivered_count / nullif(total_notifications, 0) as delivery_rate,
        failed_count / nullif(total_notifications, 0) as failure_rate,
        read_count / nullif(delivered_count, 0) as read_rate,
        current_timestamp() as dbt_updated_timestamp
    from aggregated

)

select * from final