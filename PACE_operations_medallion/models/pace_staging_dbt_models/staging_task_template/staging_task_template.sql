WITH source AS (

    SELECT * 
    FROM {{ source('bronze_task', 'RAW_TASK_TEMPLATE') }}

),

final AS (

    SELECT
        TASK_TEMPLATE_ID         AS task_template_id,
        TASK_NAME                AS task_name,
        TASK_CATEGORY            AS task_category,
        SOURCE_SYSTEM            AS source_system,

        -- metadata fields
        _LOADED_AT               AS loaded_at,
        _SOURCE_FILE             AS source_file

    FROM source

)

SELECT * 
FROM final