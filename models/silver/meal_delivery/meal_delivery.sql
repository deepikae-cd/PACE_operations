select
  meal_id,
  participant_id,
  delivery_date,
 upper(trim(meal_type)) as meal_type,

    upper(trim(status)) as meal_status,

    created_ts as source_created_ts,

    current_timestamp() as load_ts,

    datediff(
        day,
        delivery_date,
        current_date()
    ) as days_since_delivery,

    case
        when upper(status) = 'DELIVERED' then 1
        else 0
    end as delivered_flag,

    case
        when upper(status) = 'PENDING' then 1
        else 0
    end as pending_flag,

    case
        when upper(status) = 'CANCELLED' then 1
        else 0
    end as cancelled_flag,

    case
        when delivery_date < current_date()
             and upper(status) <> 'DELIVERED'
        then 'MISSED'

        when delivery_date = current_date()
        then 'TODAY'

        when delivery_date > current_date()
        then 'UPCOMING'

        else 'COMPLETED'
    end as delivery_category

from {{ source('bronze','meal_delivery_raw') }}