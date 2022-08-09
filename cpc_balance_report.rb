# To run in console
# Prints CSV report of $ balances (cash and promo) at the campaign and organization level
# Example report: https://docs.google.com/spreadsheets/d/1gn29Tfle2-Pbf-JTgcQAH3KXs2jf3Wwxe2VIt8rtKvI

co_region_ids = [173]
mi_region_ids = [281]
or_region_ids = [385,386,574,575,2267]
nm_region_ids = [588,2399,3558,3524,609,608,680,607,589,1555,681,1331,3557]

target_region_ids = co_region_ids + mi_region_ids + or_region_ids + nm_region_ids

Advertising::Campaign.where(region_id: target_region_ids).count

organization_ids = []

# Campaign-level balance report
Advertising::Campaign.where(region_id: target_region_ids).includes(:flight).each do |campaign|
  org = campaign.listing.advertising_organization
  flight = campaign.flight

  organization_ids << org.id

  puts "#{campaign.region_id},#{org.id},#{org.salesforce_id},#{org.adzerk_advertiser_id},#{org.wasp_advertiser_id},#{campaign.id},#{campaign.adzerk_id},#{flight.available_cash_balance / 100},#{flight.available_promo_balance / 100}"
end;nil

organization_ids.uniq!

# Org-level balance report
Organization.where(id: organization_ids).each do |org|
  puts "#{org.id},#{org.salesforce_id},#{org.adzerk_advertiser_id},#{org.wasp_advertiser_id},#{org.available_cash_balance / 100},#{org.available_promo_balance / 100}"
end;nil
