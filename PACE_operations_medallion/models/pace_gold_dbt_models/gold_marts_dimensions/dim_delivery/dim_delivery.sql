/*
    Model: dim_delivery

    Description:
        Dimension table capturing delivery-related attributes for meals.
        This table is used to support reporting and analytics on delivery outcomes,
        types, and compliance.

    Grain:
        One row per unique combination of:
            - delivery_status
            - delivery_type
            - is_delivery_compliant_flag

    Source:
        enterprise_silver_meal_delivery

    Transformation Logic:
        - DISTINCT is applied to ensure uniqueness of delivery attribute combinations.
        - No filtering is applied, assuming upstream data is already curated.

    Notes:
        - Consider adding a surrogate key if this dimension is used in joins.
        - Assumes source may contain duplicate records.
*/

select distinct
    -- Status of delivery (e.g., delivered, missed, cancelled)
    delivery_status,

    -- Type of delivery (e.g., standard, express, scheduled)
    delivery_type,

    -- Flag indicating whether delivery met compliance requirements
    is_delivery_compliant_flag

from {{ ref('enterprise_silver_meal_delivery') }}