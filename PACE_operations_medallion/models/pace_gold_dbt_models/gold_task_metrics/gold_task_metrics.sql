/*
===========================================================
Model:        gold_task_metrics
Layer:        Gold (Silver → Analytics)

Description:
    Aggregated task metrics for reporting and dashboards.
    Provides insights into workload, duration, and performance.

Grain:
    One record per day

===========================================================
*/

WITH base AS (

    SELECT * 
    FROM {{ ref('enterprise_silver_task') }}

),

aggregated AS (

    SELECT
        DATE(performed_at) AS task_date,

        COUNT(*) AS total_tasks,

        AVG(duration_minutes) AS avg_duration,

        MAX(duration_minutes) AS max_duration,

        MIN(duration_minutes) AS min_duration

    FROM base
    GROUP BY 1

)

SELECT * 
FROM aggregated