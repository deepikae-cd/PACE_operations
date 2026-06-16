select distinct
    meal_type,
    dietary_restriction,
    calorie_range,
    is_clinical_dietary_need_flag

from {{ ref('enterprise_silver_meal_delivery') }}