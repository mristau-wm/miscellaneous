-- Example result set:
-- organization_id	organization_name	organization_salesforce_id	campaign_id	campaign_name	campaign_adzerk_id	listing_name	listing_type	auto_transfer_amount
-- 299	CAKE	0013400001Vo9jXAAR	2674	Self-service: Broadway Cannabis Market - Portland West	13802999	Broadway Cannabis Market	Dispensary	64800
-- 641	BLAZE ON DEMAND	0010y00001k8AVoAAM	6304	Self-service: The Cannabis Depot - Pueblo	49402135	The Cannabis Depot	Dispensary	20000

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
join ownerships own on (own.entity_id = l.id)
join organizations org on (org.id = own.organization_id)
where c.auto_transfer_enabled is true
and c.active is true
and c.start_date <= now()
and ( c.end_date is null or c.end_date <= now() )
order by org.id;
