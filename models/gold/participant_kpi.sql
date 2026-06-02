select
    count(*) as total_participants
from {{ ref('participant') }}