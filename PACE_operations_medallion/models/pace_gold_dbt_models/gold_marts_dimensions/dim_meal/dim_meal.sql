/*
    Model: dim_meal_delivery

    Description:
        This dimension table captures distinct meal delivery attributes
        used for analytical reporting and downstream consumption.

    Grain:
        One row per unique combination of:
            - meal_type
            - dietary_restriction
            - calorie_range
            - is_clinical_dietary_need_flag

    Source:
        enterprise_silver_meal_delivery

    Notes:
        - DISTINCT is used to deduplicate combinations from the source.
        - This model assumes source data may contain duplicate records.
        - No surrogate key is generated here; consider adding one if required.
*/

select distinct
    -- Type/category of meal (e.g., breakfast, lunch, dinner, snack)
    meal_type,

    -- Dietary restriction associated with the meal (e.g., vegan, gluten-free)
    dietary_restriction,

    -- Calorie classification bucket for the meal
    calorie_range,

    -- Flag indicating whether the meal satisfies a clinical dietary requirement
    is_clinical_dietary_need_flag

from {{ ref('enterprise_silver_meal_delivery') }}