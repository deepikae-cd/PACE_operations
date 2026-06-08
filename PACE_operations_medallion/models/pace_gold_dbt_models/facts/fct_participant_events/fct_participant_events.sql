select

    participant_id,

    enrollment_date,
    disenrollment_date,

    case when enrollment_date is not null then 1 else 0 end as enrolled_flag,
    case when disenrollment_date is not null then 1 else 0 end as disenrolled_flag

from {{ ref('staging_participant') }}
