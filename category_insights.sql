WITH

category_insights_1 AS (
  select date_key
    , advertiser_id
    , flight_id
    , i.user_id
    , arr.position as "category_position"
    , arr.item_object as "category_data"
  from advertising_user_insights_90_days i
  join user_affinities a on (i.user_id = a.user_id)
  , jsonb_array_elements(a.categories) with ordinality arr(item_object, position)
  where a.categories <> '{}' and a.categories <> '[]'
),

category_insights_2 AS (
select advertiser_id
  , (category_data->>'value')::int "category_id"
  , count(user_id) "user_impressions"
from category_insights_1
group by advertiser_id, category_id
order by advertiser_id, category_id
)

select advertiser_id
  , category_id
  , user_impressions
from category_insights_2
where category_id in (2,3,4,5) -- Flower, Concentrates, Vape Pens, Edibles
;

-- advertiser_id	category_id	user_impressions
-- 410	2	23
-- 410	3	9
-- 410	4	6

-------------------------

WITH category_insights AS (
  select date_key
    , advertiser_id
    , flight_id
    , i.user_id
    , arr.position as "category_position"
    , arr.item_object as "category_data"
  from advertising_user_insights_90_days i
  join user_affinities a on (i.user_id = a.user_id)
  , jsonb_array_elements(a.categories) with ordinality arr(item_object, position)
  where a.categories <> '{}' and a.categories <> '[]'
)

select advertiser_id
  , category_data->'value' "category_id"
  , count(user_id) "user_impressions"
from category_insights
group by advertiser_id, category_id
order by advertiser_id, category_id;

-- advertiser_id	category_id	user_impressions
-- 410	2	23
-- 410	3	9
-- 410	4	6

------------------------

WITH category_insights AS (
  select date_key
    , advertiser_id
    , flight_id
    , i.user_id
    , arr.position as "category_position"
    , arr.item_object as "category_data"
  from advertising_user_insights_90_days i
  join user_affinities a on (i.user_id = a.user_id)
  , jsonb_array_elements(a.categories) with ordinality arr(item_object, position)
  where a.categories <> '{}' and a.categories <> '[]'
)

select * from category_insights;

-- date_key	advertiser_id	flight_id	user_id	category_position	category_data
-- 2022-07-10	410	1295	2377305	1	{"value": 23, "percent": 64.03}
