/*
===============================================================================
Model       : enterprise_silver_audit_log
Layer       : Silver
Description : 
  Trusted, deduplicated audit log model. Standardizes audit events,
  enforces controlled vocabularies, and prepares clean data for
  downstream gold projection and UI consumption.

Source:
  - {{ ref('staging_audit_log') }}

Key Features:
  - Deduplicates audit events (latest record per audit_log_id)
  - Standardizes action values (controlled vocabulary)
  - Derives event category (read/write/workflow)
  - Adds event_date for downstream partitioning
  - Preserves full audit traceability

Materialization:
  - incremental (configured in schema.yml)

===============================================================================
*/

with

-- ============================================================
-- Source: Staging audit log
-- Incremental load based on loaded_at timestamp
-- ============================================================
source as (

    select *
    from {{ ref('staging_audit_log') }}

    {% if is_incremental() %}
    where loaded_at > (
        select coalesce(max(updated_at), '1900-01-01')
        from {{ this }}
    )
    {% endif %}

),

-- ============================================================
-- Deduplication:
-- Keep latest version of each audit_log_id
-- ============================================================
deduplicated as (

    select *,
           row_number() over (
               partition by audit_log_id
               order by loaded_at desc
           ) as rn
    from source

),

-- ============================================================
-- Final Transformation:
-- Standardize fields, enforce business logic, and prepare
-- structured audit dataset for analytics and gold layer
-- ============================================================
final as (

    select

        -- ─────────────────────────────────────────────
        -- Keys
        -- ─────────────────────────────────────────────
        audit_log_id,
        participant_id,
        actor_id,

        -- ─────────────────────────────────────────────
        -- Actor Information (trusted from staging)
        -- ─────────────────────────────────────────────
        actor_type,
        actor_role,
        actor_name,

        -- ─────────────────────────────────────────────
        -- Action (Controlled Vocabulary)
        -- Ensures consistent downstream reporting
        -- ─────────────────────────────────────────────
        case
            when action in ('CREATE','UPDATE','DELETE','VIEW','APPROVE','REJECT')
                then action
            else 'OTHER'
        end as action,

        -- ─────────────────────────────────────────────
        -- Entity Context
        -- ─────────────────────────────────────────────
        entity_type,
        entity_id,

        -- ─────────────────────────────────────────────
        -- Event Category (Derived)
        -- Helps UI filtering + analytics segmentation
        -- ─────────────────────────────────────────────
        case
            when action in ('CREATE','UPDATE','DELETE') then 'write'
            when action = 'VIEW' then 'read'
            when action in ('APPROVE','REJECT') then 'workflow'
            else 'other'
        end as event_category,

        -- ─────────────────────────────────────────────
        -- Timestamp fields
        -- ─────────────────────────────────────────────
        event_timestamp,
        cast(event_timestamp as date) as event_date,   -- used for partitioning in gold

        -- ─────────────────────────────────────────────
        -- Change Tracking (Field-level audit)
        -- ─────────────────────────────────────────────
        field_changed,
        old_value,
        new_value,
        change_reason,

        -- ─────────────────────────────────────────────
        -- Compliance + Sensitivity Flags
        -- ─────────────────────────────────────────────
        is_phi_access,
        is_sensitive,

        -- ─────────────────────────────────────────────
        -- Organizational Context
        -- ─────────────────────────────────────────────
        module,
        center_id,

        -- ─────────────────────────────────────────────
        -- Technical Metadata (traceability/debugging)
        -- ─────────────────────────────────────────────
        ip_address,
        user_agent,
        session_id,
        request_id,

        -- ─────────────────────────────────────────────
        -- Source system lineage
        -- ─────────────────────────────────────────────
        source_system,

        -- ─────────────────────────────────────────────
        -- Event Description + Metadata
        -- Preserved as-is for downstream enrichment
        -- ─────────────────────────────────────────────
        event_description,
        metadata,

        -- ─────────────────────────────────────────────
        -- Audit Timestamps
        -- ─────────────────────────────────────────────
        loaded_at as updated_at,
        current_timestamp as silver_loaded_at

    from deduplicated
    where rn = 1

)

-- ============================================================
-- Final Output
-- ============================================================
select * from final