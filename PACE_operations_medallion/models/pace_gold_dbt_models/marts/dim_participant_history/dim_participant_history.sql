
select

    participant_id,
    center_id,
    program_status,
    primary_diagnosis,
    preferred_language,
    disenrollment_date,
    address_line1,
    zip_code,
    phone_number,

    dbt_valid_from as record_start_date,
    dbt_valid_to as record_end_date,

    case
        when dbt_valid_to is null then 'CURRENT'
        else 'HISTORICAL'
    end as record_status

from {{ ref('snap_participant') }}