select

    -- Keys
    trim(upper(audit_log_id))             as audit_log_id,

    -- Core timestamps
    cast(event_timestamp as timestamp)    as event_timestamp,

    --  Actor info
    trim(upper(actor_id))                 as actor_id,
    upper(trim(actor_type))               as actor_type,
    upper(trim(actor_role))               as actor_role,
    trim(actor_name)                      as actor_name,

    --  Action + entity
    upper(trim(action))                   as action,
    upper(trim(entity_type))              as entity_type,
    trim(upper(entity_id))                as entity_id,

    --  Participant context
    trim(upper(participant_id))           as participant_id,

    --  Event details
    trim(event_description)               as event_description,
    trim(upper(field_changed))            as field_changed,
    trim(old_value)                       as old_value,
    trim(new_value)                       as new_value,
    trim(change_reason)                   as change_reason,

    -- Technical metadata
    trim(ip_address)                      as ip_address,
    trim(user_agent)                      as user_agent,
    trim(session_id)                      as session_id,
    trim(request_id)                      as request_id,

    -- Module + org
    upper(trim(module))                   as module,
    trim(upper(center_id))                as center_id,

    --  Flags
    coalesce(is_phi_access, false)        as is_phi_access,
    coalesce(is_sensitive, false)         as is_sensitive,

    --  Source tracking
    upper(trim(source_system))            as source_system,

    _loaded_at                            as loaded_at,
    _source_file                          as source_file,

    current_timestamp                     as stg_loaded_at

from {{ source('bronze_audit', 'RAW_AUDIT_LOG') }}