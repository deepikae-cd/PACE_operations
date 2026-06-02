select

    notification_id,

    participant_id,

    upper(trim(notification_type)) as notification_type,

    upper(trim(channel)) as notification_channel,

    upper(trim(status)) as notification_status,

    created_ts as source_created_ts,

    current_timestamp() as load_ts,

    case
        when upper(status) = 'SENT' then 1
        else 0
    end as sent_flag,

    case
        when upper(status) = 'DELIVERED' then 1
        else 0
    end as delivered_flag,

    case
        when upper(status) = 'FAILED' then 1
        else 0
    end as failed_flag,

    case
        when upper(channel) = 'SMS' then 1
        else 0
    end as sms_flag,

    case
        when upper(channel) = 'EMAIL' then 1
        else 0
    end as email_flag,

    case
        when upper(channel) = 'PHONE' then 1
        else 0
    end as phone_flag,

    case
        when upper(channel) not in ('SMS','EMAIL','PHONE')
        then 'OTHER'
        else upper(channel)
    end as channel_category,

    case
        when upper(status) in ('SENT','DELIVERED')
        then 'SUCCESS'

        when upper(status) = 'FAILED'
        then 'FAILURE'

        else 'PENDING'
    end as notification_outcome

from PACE_DW.BRONZE.notification_raw