-- Example result set:
-- organization_id	organization_name	organization_salesforce_id	campaign_id	campaign_name	campaign_adzerk_id	listing_name	listing_type	auto_transfer_amount
-- 4736	Lucky Lion Halsey	0010y00001dRhz8AAC	2806	Self-service: Lucky Lion - Eugene - Eugene / Springfield	15473086	Lucky Lion - Eugene	Dispensary	5000
-- 6531	Broadway Cannabis Market	0010y00001fl8PkAAI	2674	Self-service: Broadway Cannabis Market - Portland West	13802999	Broadway Cannabis Market	Dispensary	64800

select org.id as organization_id
, org.name as organization_name
, org.salesforce_id as organization_salesforce_id
, c.id as campaign_id
, c.name as campaign_name
, c.adzerk_id as campaign_adzerk_id
, l.name as listing_name
, l.type as listing_type
, c.auto_transfer_amount
from advertising_campaigns c
join listings l on (l.wmid = c.wmid)
join organizations org on (org.id = l.organization_id)
where c.auto_transfer_enabled is true
and c.active is true
and c.start_date <= now()
and ( c.end_date is null or c.end_date <= now() )
order by org.id;
