/*
===========================================================
Model:        enterprise_silver_task
Layer:        Silver (Staging → Silver)
Source:
              - staging_task_instance
              - staging_task_template
Author:       Deepika Eswar

Description:
    Integrates task execution data with task template metadata
    to produce a unified, analytics-ready task dataset.

Business Logic:
    - Joins task instance with task template using task_template_id
    - Enriches task records with task name and category
    - Preserves execution-level granularity

Grain:
    One record per task_instance_id

Dependencies:
    - ref('staging_task_instance')
    - ref('staging_task_template')

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
        i.task_template_id,

        t.task_name,
        t.task_category,

        i.actual_duration_minutes,
        i.performed_at,

        i.source_system

    FROM instance i
    LEFT JOIN template t
        ON i.task_template_id = t.task_template_id

)

SELECT *
FROM joined
