require 'aws-sdk-athena'

# Example usage:
# 
# Dry run:
# TARGET_TABLE=ws_fastly_session_clicks ruby athena_queries_to_correct_click_anomalies.rb
#
# Actual run (this will execute the queries):
# TARGET_TABLE=ws_fastly_session_clicks EXECUTE=true ruby athena_queries_to_correct_click_anomalies.rb

# ============================================
# This script requires that you have assumed the ad_server_athena_rw role
# To do so, follow the steps below

# # assume ad_server_athena_rw role
# aws sts assume-role --role-arn arn:aws:iam::767696881916:role/ad_server_athena_rw --role-session-name ClickAnomalies

# # configure temporary credentials (from assume-role output)
# aws configure set aws_access_key_id TEMP_ACCESS_KEY_ID
# aws configure set aws_secret_access_key TEMP_SECRET_ACCESS_KEY
# aws configure set aws_session_token TEMP_SESSION_TOKEN

# # run athena query
# aws athena start-query-execution --query-string "SELECT * FROM wm_ad_server_pixels_production LIMIT 1" --query-execution-context Database=wm_ad_server --work-group wm-ad-server

# # get results of query (from query execution ID from query output)
# aws athena get-query-results --query-execution-id 46f70b28-42b7-4ef3-a97e-322a3a0a7c7c
# =============================================

# Create an Athena client
CLIENT = Aws::Athena::Client.new

# Define the query parameters
DATABASE = 'wm_ad_server'
WORKGROUP = 'wm-ad-server'

target_tables = [
  'ws_fastly_session_clicks',
  'ws_fastly_clicks',
  'weedmaps_revenue_daily',
  'ws_revenue_daily',
  'ws_custom_daily_report'
]

unless target_tables.include? ENV['TARGET_TABLE']
  puts "Error: Must specify TARGET_TABLE variable with one of the following:\n#{target_tables.inspect}"
  exit
end

puts "Targeting table #{ENV['TARGET_TABLE']}"

def run_query(sql)
  # Run the query
  response = CLIENT.start_query_execution({
    query_string: sql,
    query_execution_context: { database: DATABASE },
    work_group: WORKGROUP
  })
  puts "Query response: #{response}"

  # Get the query execution ID
  query_execution_id = response.query_execution_id

  # Wait for the query to complete
  loop do
    query_execution = CLIENT.get_query_execution({ query_execution_id: query_execution_id })

    status = query_execution.query_execution.status.state

    if status == 'SUCCEEDED'
      puts "Query succeeded"
      break
    elsif status == 'FAILED'
      puts "Query failed"
      break
    elsif status == 'QUEUED'
      puts 'Query is still in the queue. Waiting...'
      sleep 3
    elsif status == 'RUNNING'
      puts 'Query is still running. Waiting...'
      sleep 3
    else
      puts "Unxpected query status: #{status}"
      break
    end
  end
end

target_dates = [
  "2022-09-27",
  "2022-09-28",
  "2022-10-09",
  "2022-10-14",
  "2022-10-16",
  "2022-10-21",
  "2022-10-23",
  "2022-10-24",
  "2022-10-28",
  "2022-10-31",
  "2022-11-04",
  "2022-11-12",
  "2022-11-13",
  "2022-11-14",
  "2022-11-15",
  "2022-11-20",
  "2022-11-22",
  "2022-11-23",
  "2022-11-27",
  "2022-12-04",
  "2022-12-21",
  "2022-12-23",
  "2022-12-28",
  "2023-01-05",
  "2023-01-06",
  "2023-01-09",
  "2023-01-10",
  "2023-03-09",
  "2023-03-22",
  "2023-03-28",
  "2023-04-08",
  "2023-04-09",
  "2023-04-13"
]

# ws_fastly_session_clicks
# =============================================

ws_fastly_session_clicks = """insert into ws_fastly_session_clicks
WITH dedup AS (
select
date as dt_time,
http.url as url_payload,
MAX(http.request_x_forwarded_for) as ip_address,
dt as date_key
from wm_ad_server_pixels_$ENV where  dt='$DATE'
and http.url like '%etype=ctr%'
and http.status_code=302
and http.useragent not in ('Weedmaps Datadog Synthetics Test', 'Weedmaps Moonshot Cypress')
GROUP BY 1,2,4
)
, data as(
select
date_key,
try(from_utf8(from_base64url(SPLIT_PART(REPLACE(REPLACE(url_payload,'/pixel?etype=ctr&payload=',''),'%3D',''),'&',1)))) as payload,
coalesce(LENGTH(try(from_utf8(from_base64url(SPLIT_PART(REPLACE(REPLACE(url_payload,'/pixel?etype=ctr&payload=',''),'%3D',''),'&',1))))),0) as data_length,
ip_address
from
dedup
)
,final_data as(
select
CAST(json_extract(payload,'$.uuid') as VARCHAR) as session_id,
CAST(json_extract(payload,'$.flight_id') as VARCHAR) as flight_id,
CAST(json_extract(payload,'$.campaign_id') as VARCHAR) as campaign_id,
CAST(json_extract(payload,'$.creative_id') as VARCHAR) as creative_id,
CAST(json_extract(payload,'$.zones') as INTEGER) as zone_id,
CASE
WHEN LENGTH(CAST(json_extract(payload,'$.click_spend') as VARCHAR))>0 then CAST(json_extract(payload,'$.click_spend') as DOUBLE)
ELSE 0.0 end as click_spend,
CASE
WHEN LENGTH(CAST(json_extract(payload,'$.impression_spend') as VARCHAR))>0 then CAST(json_extract(payload,'$.impression_spend') as DOUBLE)
ELSE 0.0 end as impression_spend,
CASE
WHEN LENGTH(CAST(json_extract(payload,'$.sales_region') as VARCHAR))>0 then CAST(json_extract(payload,'$.sales_region') as INTEGER)
ELSE 0 end as region_id,
CAST(json_extract(payload,'$.user_id') as VARCHAR) as user_id,
CAST(json_extract(payload,'$.anonymous_id') as VARCHAR) as anonymous_id,
ip_address,
date_key
from data
where data_length>0
)

select
a.session_id,
a.flight_id,
a.campaign_id,
a.creative_id,
a.zone_id,
a.click_spend,
a.impression_spend,
a.region_id,
a.user_id,
a.anonymous_id,
a.ip_address,
a.date_key
from
final_data a"""

if ENV['TARGET_TABLE'] == 'ws_fastly_session_clicks'
  target_dates.each do |date|
    puts "Running ws_fastly_session_clicks query for #{date}"
    sql = ws_fastly_session_clicks.gsub('$ENV', 'production').gsub('$DATE', date)
    run_query(sql) if ENV['EXECUTE'] == 'true'
  end
end

# ws_fastly_clicks
# =============================================

ws_fastly_clicks = """insert into ws_fastly_clicks
WITH dedup AS (
select
session_id,
flight_id,
creative_id,
zone_id,
date_key,
sum(1) as clicks
from ws_fastly_session_clicks
where date_key='$DATE'
group by 1,2,3,4,5
),clk_gt as (
select
session_id,
flight_id,
creative_id,
zone_id,
date_key
from dedup
where clicks>5
), clicks_ls as (
select
a.session_id,
a.flight_id,
a.campaign_id,
a.creative_id,
a.zone_id,
a.click_spend,
a.impression_spend,
a.region_id,
a.date_key
from ws_fastly_session_clicks a
left join clk_gt b 
on a.session_id=b.session_id
and a.zone_id=b.zone_id
and a.flight_id=b.flight_id
and a.creative_id=b.creative_id
where a.date_key='$DATE' and b.session_id is null
), clicks_gt as (
select
a.session_id,
a.flight_id,
a.campaign_id,
a.creative_id,
a.zone_id,
a.click_spend,
a.impression_spend,
a.region_id,
a.date_key
from 
ws_fastly_session_clicks a,
clk_gt b 
where a.session_id=b.session_id
and a.flight_id=b.flight_id
and a.creative_id=b.creative_id
and a.date_key='$DATE'
), rn_clicks as (
select *, row_number() over (PARTITION BY session_id, flight_id,creative_id,zone_id,region_id) as row_num 
from clicks_gt
)
select 
a.flight_id,
a.campaign_id,
a.creative_id,
a.zone_id,
a.click_spend,
a.impression_spend,
a.region_id,
a.date_key
from rn_clicks a 
where row_num <=5

UNION ALL

select 
a.flight_id,
a.campaign_id,
a.creative_id,
a.zone_id,
a.click_spend,
a.impression_spend,
a.region_id,
a.date_key
from clicks_ls a"""

if ENV['TARGET_TABLE'] == 'ws_fastly_clicks'
  target_dates.each do |date|
    puts "Running ws_fastly_clicks query for #{date}"
    sql = ws_fastly_clicks.gsub('$ENV', 'production').gsub('$DATE', date)
    run_query(sql) if ENV['EXECUTE'] == 'true'
  end
end

# weedmaps_revenue_daily
# =============================================

weedmaps_revenue_daily = """insert into weedmaps_revenue_daily
WITH ws_flights as (
select
distinct
flight_id,
flight_name,
campaign_id,
campaign_name,
advertiser_id,
advertiser_name,
rate_type_id,
flight_start_date,
flight_end_date
from wasp_flights
), data as (
select 
a.flight_id,
b.flight_name,
a.campaign_id,
b.campaign_name,
b.advertiser_id,
b.advertiser_name,
a.creative_id,
'' as creative_name,
'' as creative_link,
cast(b.rate_type_id as INTEGER) as rate_type,
cast(a.region_id as INTEGER) as region_id,
cast(a.zone_id as INTEGER) as zone_id,
c.name as zone_name,
sum(1) as impressions,
0 as clicks,
sum(
case 
when cast(b.rate_type_id as INTEGER)=1 then a.impression_spend
else 0 end) as revenue,
a.date_key as date_key
from 
ws_fastly_impressions a,
ws_flights b,
zones c
where a.date_key='$DATE'
and a.flight_id=b.flight_id
and a.campaign_id=b.campaign_id
and a.zone_id=c.zone_id
and c.date_key='2022-07-31'
and a.date_key>=b.flight_start_date
and a.date_key<=b.flight_end_date
group by 
1,2,3,4,5,6,7,10,11,12,13,17

UNION ALL

select 
a.flight_id,
b.flight_name,
a.campaign_id,
b.campaign_name,
b.advertiser_id,
b.advertiser_name,
a.creative_id,
'' as creative_name,
'' as creative_link,
cast(b.rate_type_id as INTEGER) as rate_type,
cast(a.region_id as INTEGER) as region_id,
cast(a.zone_id as INTEGER) as zone_id,
c.name as zone_name,
0 as impressions,
sum(1) as clicks,
sum(
case 
when cast(b.rate_type_id as INTEGER)=2 then a.click_spend
else 0 end) as revenue,
a.date_key as date_key
from 
ws_fastly_clicks a,
ws_flights b,
zones c
where a.date_key='$DATE'
and a.flight_id=b.flight_id
and a.campaign_id=b.campaign_id
and a.zone_id=c.zone_id
and c.date_key='2022-07-31'
and a.date_key>=b.flight_start_date
and a.date_key<=b.flight_end_date
group by 
1,2,3,4,5,6,7,10,11,12,13,17
)

select 
flight_id,
flight_name,
campaign_id,
campaign_name,
advertiser_id,
advertiser_name,
creative_id,
creative_name,
creative_link,
rate_type,
region_id,
zone_id,
zone_name,
sum(impressions),
sum(clicks),
sum(revenue),
'wasp',
to_hex(md5(to_utf8(concat(flight_id,campaign_id,advertiser_id,creative_id,'wasp')))),
cast(date_key as VARCHAR(10))
from data
group by
flight_id,
flight_name,
campaign_id,
campaign_name,
advertiser_id,
advertiser_name,
creative_id,
creative_name,
creative_link,
rate_type,
region_id,
zone_id,
zone_name,
date_key"""

if ENV['TARGET_TABLE'] == 'weedmaps_revenue_daily'
  target_dates.each do |date|
    puts "Running weedmaps_revenue_daily query for #{date}"
    sql = weedmaps_revenue_daily.gsub('$ENV', 'production').gsub('$DATE', date)
    run_query(sql) if ENV['EXECUTE'] == 'true'
  end
end

# ws_revenue_daily
# =============================================

ws_revenue_daily = """insert into ws_revenue_daily
WITH ws_flights as (
select
distinct
flight_id,
flight_name,
campaign_id,
campaign_name,
advertiser_id,
advertiser_name,
rate_type_id,
flight_start_date,
flight_end_date
from wasp_flights
), data as (
select 
a.flight_id,
b.flight_name,
a.campaign_id,
b.campaign_name,
b.advertiser_id,
b.advertiser_name,
a.creative_id,
'' as creative_name,
'' as creative_link,
cast(b.rate_type_id as INTEGER) as rate_type,
cast(a.region_id as INTEGER) as region_id,
cast(a.zone_id as INTEGER) as zone_id,
c.name as zone_name,
sum(1) as impressions,
0 as clicks,
sum(
case 
when cast(b.rate_type_id as INTEGER)=1 then a.impression_spend
else 0 end) as revenue,
a.date_key as date_key
from 
ws_fastly_impressions a,
ws_flights b,
zones c
where a.date_key='$DATE'
and a.flight_id=b.flight_id
and a.campaign_id=b.campaign_id
and a.zone_id=c.zone_id
and c.date_key='2022-07-31'
and a.date_key>=b.flight_start_date
and a.date_key<=b.flight_end_date
group by 
1,2,3,4,5,6,7,10,11,12,13,17

UNION ALL

select 
a.flight_id,
b.flight_name,
a.campaign_id,
b.campaign_name,
b.advertiser_id,
b.advertiser_name,
a.creative_id,
'' as creative_name,
'' as creative_link,
cast(b.rate_type_id as INTEGER) as rate_type,
cast(a.region_id as INTEGER) as region_id,
cast(a.zone_id as INTEGER) as zone_id,
c.name as zone_name,
0 as impressions,
sum(1) as clicks,
sum(
case 
when cast(b.rate_type_id as INTEGER)=2 then a.click_spend
else 0 end) as revenue,
a.date_key as date_key
from 
ws_fastly_clicks a,
ws_flights b,
zones c
where a.date_key='$DATE'
and a.flight_id=b.flight_id
and a.campaign_id=b.campaign_id
and a.zone_id=c.zone_id
and c.date_key='2022-07-31'
and a.date_key>=b.flight_start_date
and a.date_key<=b.flight_end_date
group by 
1,2,3,4,5,6,7,10,11,12,13,17
)

select 
flight_id,
flight_name,
campaign_id,
campaign_name,
advertiser_id,
advertiser_name,
creative_id,
creative_name,
creative_link,
rate_type,
region_id,
zone_id,
zone_name,
sum(impressions),
sum(clicks),
CASE 
WHEN sum(impressions) <=0 THEN 0 
WHEN sum(impressions)>0 THEN round(CAST(sum(clicks) * 100 as double)/(CAST(sum(impressions) as double)  + 0.0001),4) 
END as ctr,
sum(revenue),
CASE
WHEN sum(impressions)<=0 THEN 0
WHEN sum(impressions)>0 THEN
CAST(sum(revenue) * 1000/sum(impressions) as double) 
END as ecpm,
'wasp',
cast(date_key as VARCHAR(10))
from data
group by
flight_id,
flight_name,
campaign_id,
campaign_name,
advertiser_id,
advertiser_name,
creative_id,
creative_name,
creative_link,
rate_type,
region_id,
zone_id,
zone_name,
date_key"""

if ENV['TARGET_TABLE'] == 'ws_revenue_daily'
  target_dates.each do |date|
    puts "Running ws_revenue_daily query for #{date}"
    sql = ws_revenue_daily.gsub('$ENV', 'production').gsub('$DATE', date)
    run_query(sql) if ENV['EXECUTE'] == 'true'
  end
end

# ws_custom_daily_report
# =============================================

ws_custom_daily_report = """insert into ws_custom_daily_report
select
'0',
campaign_id,
flight_id,
flight_name,
rate_type,
sum(revenue),
zone_id,
1,
region_id,
sum(impressions),
sum(clicks),
cast(0 as bigint),
cast(0 as bigint),
cast(0 as bigint),
cast(0 as bigint),
cast(0 as bigint),
cast(0 as bigint),
cast(0 as bigint),
case
when sum(impressions)>0 then sum(clicks) * 100/sum(impressions)
else 0.0 end,
sum(revenue),
case
when sum(impressions)>0 then sum(revenue) * 1000/sum(impressions)
else 0.0 end,
date_key
from ws_revenue_daily
where date_key='$DATE'
group by 
campaign_id,
flight_id,
flight_name,
rate_type,
zone_id,
region_id,
date_key"""

if ENV['TARGET_TABLE'] == 'ws_custom_daily_report'
  target_dates.each do |date|
    puts "Running ws_custom_daily_report query for #{date}"
    sql = ws_custom_daily_report.gsub('$ENV', 'production').gsub('$DATE', date)
    run_query(sql) if ENV['EXECUTE'] == 'true'
  end
end
