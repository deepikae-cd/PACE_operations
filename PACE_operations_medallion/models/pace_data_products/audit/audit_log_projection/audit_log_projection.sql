

with source as (

    select *
    from {{ ref('audit_log') }}

    {% if is_incremental() %}
        where updated_at > (select coalesce(max(updated_at), '1900-01-01') from {{ this }})
    {% endif %}

),

-- ============================================================
-- Actor enrichment
-- ============================================================
actor_enriched as (

    select
        a.audit_log_id,
        a.participant_id,
        a.actor_id,

        u.full_name      as actor_name,
        u.role_name      as actor_role,

        a.event_type,
        a.event_subtype,
        a.event_timestamp,
        a.updated_at,
        a.metadata

    from source a

    left join {{ ref('dim_user') }} u
        on a.actor_id = u.user_id

),

-- ============================================================
-- Event description (precomputed)
-- ============================================================
final as (

    select

        audit_log_id,
        participant_id,
        actor_id,
        actor_name,
        actor_role,

        event_type,
        event_subtype,
        case
            when event_type = 'CREATE' then concat(actor_name, ' created record')
            when event_type = 'UPDATE' then concat(actor_name, ' updated record')
            when event_type = 'DELETE' then concat(actor_name, ' deleted record')
            when event_type = 'LOGIN'  then concat(actor_name, ' logged in')
            else concat(actor_name, ' performed action')
        end as event_description,

        event_timestamp,
        cast(event_timestamp as date) as partition_date,

        metadata,
        updated_at,

        current_timestamp as gold_loaded_at

    from actor_enriched

)

select * from final
