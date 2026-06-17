/*
  GOLD_NOTIFICATION_BY_ENTITY
  ─────────────────────────────────────────────────────────────
  Purpose:
    Enables use-case driven analytics based on entity relationships.

  Grain:
    related_entity_type + related_entity_id

*/

with base as (

    select *
    from {{ ref('enterprise_silver_notification_service') }}

),

aggregated as (

    select
        related_entity_type,
        related_entity_id,

        count(*) as total_notifications,
        sum(case when is_delivered_flag then 1 else 0 end) as delivered_count,
        sum(case when is_failed_flag then 1 else 0 end)    as failed_count

    from base
    where related_entity_type != 'NONE'
    group by 1, 2

)

select * from aggregated