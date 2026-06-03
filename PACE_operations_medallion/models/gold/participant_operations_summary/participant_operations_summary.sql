{{ config(
    materialized='table'
) }}

with participants as (

    select *
    from {{ ref('participant') }}

),

appointments as (

    select
        participant_id,
        count(*) as total_appointments,
        sum(completed_flag) as completed_appointments,
        sum(cancelled_flag) as cancelled_appointments
    from {{ ref('appointment') }}
    group by participant_id

),

clinical_visits as (

    select
        participant_id,
        count(*) as total_visits
    from {{ ref('clinical_visit') }}
    group by participant_id

),

transportation as (

    select
        participant_id,
        count(*) as total_transports,
        sum(completed_flag) as completed_transports
    from {{ ref('transportation') }}
    group by participant_id

),

meal_delivery as (

    select
        participant_id,
        count(*) as total_meals,
        sum(delivered_flag) as delivered_meals
    from {{ ref('meal_delivery') }}
    group by participant_id

),

notifications as (

    select
        participant_id,
        count(*) as total_notifications,
        sum(delivered_flag) as successful_notifications
    from {{ ref('notification') }}
    group by participant_id

)

select

    p.participant_id,
    p.first_name,
    p.last_name,
    p.participant_status,

    coalesce(a.total_appointments,0) as total_appointments,
    coalesce(a.completed_appointments,0) as completed_appointments,
    coalesce(a.cancelled_appointments,0) as cancelled_appointments,

    coalesce(cv.total_visits,0) as total_clinical_visits,

    coalesce(t.total_transports,0) as total_transports,
    coalesce(t.completed_transports,0) as completed_transports,

    coalesce(m.total_meals,0) as total_meals,
    coalesce(m.delivered_meals,0) as delivered_meals,

    coalesce(n.total_notifications,0) as total_notifications,
    coalesce(n.successful_notifications,0) as successful_notifications,

    current_timestamp() as load_ts

from participants p

left join appointments a
    on p.participant_id = a.participant_id

left join clinical_visits cv
    on p.participant_id = cv.participant_id

left join transportation t
    on p.participant_id = t.participant_id

left join meal_delivery m
    on p.participant_id = m.participant_id

left join notifications n
    on p.participant_id = n.participant_id