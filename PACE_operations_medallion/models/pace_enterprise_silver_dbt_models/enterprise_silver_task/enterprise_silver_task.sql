
/*
===========================================================
Model:        staging_task_template
Layer:        Staging (Bronze → Staging)

/*
===========================================================
Model:        staging_task_template
Layer:        Staging (Bronze → Staging)
Source:       BRONZE_TASK.RAW_TASK_TEMPLATE
Author:       Deepika Eswar
Created On:   2026-06-08

Description:
    Transforms raw task template data from Bronze layer into
    a cleaned, standardized staging model. Applies column
    renaming, consistent casing, and metadata preservation.

Business Logic:
    - Standardizes column naming to snake_case
    - Preserves ingestion metadata for lineage tracking

Dependencies:
    - source('bronze_task', 'RAW_TASK_TEMPLATE')

Outputs:
    - PACE_DW.staging_task_template

===========================================================
*/



WITH instance AS (

    SELECT * FROM {{ ref('staging_task_instance') }}

),

template AS (

    SELECT * FROM {{ ref('staging_task_template') }}

),

joined AS (

    SELECT
        i.task_instance_id,
        i.participant_id,

        i.task_template_id,
        t.task_name,
        t.task_category,

        i.task_status,
        i.start_time,
        i.end_time,
        i.duration_minutes,

        i.source_system

    FROM instance i
    LEFT JOIN template t
        ON i.task_template_id = t.task_template_id

)

SELECT * FROM joined
