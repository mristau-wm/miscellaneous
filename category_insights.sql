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
),

category_insights_3 AS (
  select c2.advertiser_id
    , c2.category_id
    , c.name "category_name"
    , c.parent_id "parent_category_id"
    , c2.user_impressions
  from category_insights_2 c2
  right join categories c on (c.id = c2.category_id)
),

category_insights_4 AS (
  select c3.advertiser_id
    , c3.category_id
    , c3.category_name
    , c3.parent_category_id
    , coalesce(c.name, c3.category_name) "parent_category_name"
    , c3.user_impressions
    , row_number() over (partition by advertiser_id, parent_category_id order by user_impressions desc) as ranking
  from category_insights_3 c3
  left join categories c on (c.id = c3.parent_category_id)
),

user_insights_by_category AS (

select advertiser_id
  , category_id
  , category_name
  , case when parent_category_id in (0,2,3,4,5) then parent_category_id else -1 end "parent_category_id"
  , case when parent_category_name in ('Flower', 'Concentrates', 'Vape Pens', 'Edibles') then parent_category_name else 'Other' end "parent_category_name"
  , user_impressions
  , ranking
from category_insights_4 c4
)

select category_id, category_name, parent_category_id, parent_category_name, user_impressions
from user_insights_by_category
where advertiser_id = 410
and parent_category_id <> 0
and ranking <= 5
order by parent_category_name
;

-- category_id	category_name	parent_category_id	parent_category_name	user_impressions
-- 48	Budder	3	Concentrates	1
-- 28	Live Resin	3	Concentrates	2
-- 34	Distillate	3	Concentrates	2
-- 12	Shatter	3	Concentrates	1
-- 37	Crystalline	3	Concentrates	1
-- 1531	Candy	5	Edibles	1
-- 1497	Pre Roll	2	Flower	9
-- 1494	Infused Flower	2	Flower	5
-- 1514	Push Button	-1	Other	1
-- 1500	Drinks	-1	Other	1
-- 22	Gummies	-1	Other	1
-- 1468	Clone	-1	Other	1
-- 1513	Pods	4	Vape Pens	1

----------------------

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
),

category_insights_3 AS (
  select c2.advertiser_id
    , c2.category_id
    , c.name "category_name"
    , c.parent_id "parent_category_id"
    , c2.user_impressions
  from category_insights_2 c2
  right join categories c on (c.id = c2.category_id)
),

category_insights_4 AS (
  select c3.advertiser_id
    , c3.category_id
    , c3.category_name
    , c3.parent_category_id
    , coalesce(c.name, c3.category_name) "parent_category_name"
    , c3.user_impressions
    , row_number() over (partition by advertiser_id, parent_category_id order by user_impressions desc) as ranking
  from category_insights_3 c3
  left join categories c on (c.id = c3.parent_category_id)
),

category_insights_5 AS (

select advertiser_id
  , category_id
  , category_name
  , case when parent_category_id in (0,2,3,4,5) then parent_category_id else -1 end "parent_category_id"
  , case when parent_category_name in ('Flower', 'Concentrates', 'Vape Pens', 'Edibles') then parent_category_name else 'Other' end "parent_category_name"
  , user_impressions
  , ranking
from category_insights_4 c4
)

select parent_category_id, parent_category_name, sum(user_impressions)
from category_insights_5
where advertiser_id = 410
and parent_category_id in (-1,2,3,4,5)
group by parent_category_id, parent_category_name
order by sum(user_impressions) desc
;

-- parent_category_id	parent_category_name	sum
-- 2	Flower	14
-- 3	Concentrates	8
-- -1	Other	4
-- 4	Vape Pens	1
-- 5	Edibles	1


-----------------------------

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
),

category_insights_3 AS (
  select c2.advertiser_id
    , c2.category_id
    , c.name "category_name"
    , c.parent_id "parent_category_id"
    , c2.user_impressions
  from category_insights_2 c2
  right join categories c on (c.id = c2.category_id)
),

category_insights_4 AS (
  select c3.advertiser_id
    , c3.category_id
    , c3.category_name
    , c3.parent_category_id
    , coalesce(c.name, c3.category_name) "parent_category_name"
    , c3.user_impressions
    , row_number() over (partition by advertiser_id, parent_category_id order by user_impressions desc) as ranking
  from category_insights_3 c3
  left join categories c on (c.id = c3.parent_category_id)
),

category_insights_5 AS (

select advertiser_id
  , category_id
  , category_name
  , case when parent_category_id in (0,2,3,4,5) then parent_category_id else -1 end "parent_category_id"
  , case when parent_category_name in ('Flower', 'Concentrates', 'Vape Pens', 'Edibles') then parent_category_name else 'Other' end "parent_category_name"
  , user_impressions
  , ranking
from category_insights_4 c4
where ranking <= 5
)

select parent_category_name, sum(user_impressions)
from category_insights_5
where advertiser_id = 410
and parent_category_id = 0
group by parent_category_name
order by sum(user_impressions) desc
;

-- parent_category_name	sum
-- Flower	23
-- Concentrates	9
-- Vape Pens	6
-- Edibles	4
-- Other	3


--------------

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
),

category_insights_3 AS (
  select c2.advertiser_id
    , c2.category_id
    , c.name "category_name"
    , c.parent_id "parent_category_id"
    , c2.user_impressions
  from category_insights_2 c2
  right join categories c on (c.id = c2.category_id)
),

category_insights_4 AS (
  select c3.advertiser_id
    , c3.category_id
    , c3.category_name
    , c3.parent_category_id
    , coalesce(c.name, c3.category_name) "parent_category_name"
    , c3.user_impressions
    , row_number() over (partition by advertiser_id, parent_category_id order by user_impressions desc) as ranking
  from category_insights_3 c3
  left join categories c on (c.id = c3.parent_category_id)
)

select advertiser_id
  , category_id
  , category_name
  , case when parent_category_id in (0,2,3,4,5) then parent_category_id else -1 end "parent_category_id"
  , case when parent_category_name in ('Flower', 'Concentrates', 'Vape Pens', 'Edibles') then parent_category_name else 'Other' end "parent_category_name"
  , user_impressions
  , ranking
from category_insights_4 c4
where ranking <= 5
order by advertiser_id asc, user_impressions desc
;

-- advertiser_id	category_id	category_name	parent_category_id	parent_category_name	user_impressions	ranking
-- 410	2	Flower	0	Flower	23	1
-- 410	3	Concentrates	0	Concentrates	9	2
-- 410	1497	Pre Roll	2	Flower	9	1


----------------------------

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
),

category_insights_3 AS (
  select c2.advertiser_id
    , c2.category_id
    , c.name "category_name"
    , c.parent_id "parent_category_id"
    , c2.user_impressions
  from category_insights_2 c2
  right join categories c on (c.id = c2.category_id)
),

category_insights_4 AS (
  select c3.advertiser_id
    , c3.category_id
    , c3.category_name
    , c3.parent_category_id
    , coalesce(c.name, c3.category_name) "parent_category_name"
    , c3.user_impressions
    , row_number() over (partition by advertiser_id, parent_category_id order by user_impressions desc) as advertiser_parent_category_rank
  from category_insights_3 c3
  left join categories c on (c.id = c3.parent_category_id)
)

select *
from category_insights_4 c4
-- where advertiser_parent_rank <= 2
order by advertiser_id asc, user_impressions desc
;

-- advertiser_id	category_id	category_name	parent_category_id	parent_category_name	user_impressions	advertiser_parent_category_rank
-- 410	2	Flower	0	Flower	23	1
-- 410	1497	Pre Roll	2	Flower	9	1
-- 410	3	Concentrates	0	Concentrates	9	2

-------------------------

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
),

category_insights_3 AS (
  select c2.advertiser_id
    , c2.category_id
    , c.name "category_name"
    , c.parent_id "parent_category_id"
    , c2.user_impressions
  from category_insights_2 c2
  join categories c on (c.id = c2.category_id)
)

select c3.advertiser_id
  , c3.category_id
  , c3.category_name
  , c3.parent_category_id
  , c.name "parent_category_name"
  , c3.user_impressions
from category_insights_3 c3
join categories c on (c.id = c3.parent_category_id)
order by advertiser_id asc, user_impressions desc
;

-- advertiser_id	category_id	category_name	parent_category_id	parent_category_name	user_impressions
-- 410	1497	Pre Roll	2	Flower	9
-- 410	1494	Infused Flower	2	Flower	5
-- 410	28	Live Resin	3	Concentrates	2

---------------------

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
),

category_insights_3 AS (
  select advertiser_id
    , sum(user_impressions) "total_user_impressions"
  from category_insights_2
  group by advertiser_id
)

select c2.advertiser_id
  , c2.category_id
  , c.name
  , c.parent_id
  , c2.user_impressions
  , round((c2.user_impressions / c3.total_user_impressions)::numeric, 2) "pct_user_impressions"
from category_insights_2 c2
join category_insights_3 c3 on (c2.advertiser_id = c3.advertiser_id)
join categories c on (c.id = c2.category_id)
where c2.category_id in (2,3,4,5) or c.parent_id in (2,3,4,5) -- Flower, Concentrates, Vape Pens, Edibles
order by advertiser_id asc, pct_user_impressions desc

-- advertiser_id	category_id	name	parent_id	user_impressions	pct_user_impressions
-- 410	2	Flower	0	23	0.31
-- 410	1497	Pre Roll	2	9	0.12
-- 410	3	Concentrates	0	9	0.12

-------------------------

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
),

category_insights_3 AS (
  select advertiser_id
    , sum(user_impressions) "total_user_impressions"
  from category_insights_2
  group by advertiser_id
)

select c2.advertiser_id
  , c2.category_id
  , round((c2.user_impressions / c3.total_user_impressions)::numeric, 2) "pct_user_impressions"
from category_insights_2 c2
join category_insights_3 c3 on (c2.advertiser_id = c3.advertiser_id)
where c2.category_id in (2,3,4,5) -- Flower, Concentrates, Vape Pens, Edibles
order by advertiser_id, category_id
;

-- advertiser_id	category_id	pct_user_impressions
-- 410	2	0.31
-- 410	3	0.12
-- 410	4	0.08

--------------------

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
