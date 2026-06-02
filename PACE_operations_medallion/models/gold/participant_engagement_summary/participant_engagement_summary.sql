with appt as (
    select participant_id, appointment_id
    from {{ ref('appointment') }}
),

meal as (
    select participant_id
    from {{ ref('meal_delivery') }}
),

transport as (
    select participant_id
    from {{ ref('transportation') }}
)

select
    p.participant_id,

    count(distinct appt.appointment_id) as total_appointments,

    -- FIX: do NOT use transportation_id
    count(distinct transport.participant_id) as total_transport_trips,

    -- FIX: do NOT use meal_delivery_id either
    count(distinct meal.participant_id) as total_meals,

    (
        count(distinct appt.appointment_id)
      + count(distinct transport.participant_id)
      + count(distinct meal.participant_id)
    ) as total_services_used,

    case
        when (
            count(distinct appt.appointment_id)
          + count(distinct transport.participant_id)
          + count(distinct meal.participant_id)
        ) >= 10 then 'HIGH'

        when (
            count(distinct appt.appointment_id)
          + count(distinct transport.participant_id)
          + count(distinct meal.participant_id)
        ) >= 5 then 'MEDIUM'

        else 'LOW'
    end as engagement_level,

    current_timestamp() as load_ts

from {{ ref('participant') }} p

left join appt
    on p.participant_id = appt.participant_id

left join meal
    on p.participant_id = meal.participant_id

left join transport
    on p.participant_id = transport.participant_id

group by p.participant_id