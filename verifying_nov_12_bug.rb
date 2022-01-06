# Example output:
# 967|0013400001KB8rDAAT|117|1715411|116|2708706.5081|146352|146593.4919
# 10326|0010y00001cUirXAAS|142|1717250|141|3080735.5217|432024|436764.4783
# 7476|0013400001V6IcOAAV|147|1717268|146|367949.629|146350|146450.371
# 
# Final report: https://docs.google.com/spreadsheets/d/148BHJeUUska5igTIPM3LxSRGW7a4skIw4U2IvFkgRPM

# active_flight_ids = Advertising::FlightDelta.select("advertising_flight_id, sum(revenue)").where("created_at >= '2021-11-12'").group("advertising_flight_id").having("sum(revenue) > 0").order("advertising_flight_id asc").pluck(:advertising_flight_id)
# SELECT advertising_flight_id, sum(revenue) FROM "advertising_flight_deltas" WHERE (created_at >= '2021-11-12') GROUP BY "advertising_flight_deltas"."advertising_flight_id" HAVING (sum(revenue) > 0) ORDER BY advertising_flight_id asc

# Advertising::Flight.where(id: active_flight_ids).find_each do |flight|
Advertising::Flight.find_each do |flight|
  organization_id = flight.campaign.listing.advertising_organization.id
  organization_salesforce_id = flight.campaign.listing.advertising_organization.salesforce_id
  core_balance = flight.balance # cash + promo
  kevel_balance = flight.lifetime_cap - flight.revenue_from_deltas
  puts "#{organization_id}|#{organization_salesforce_id}|#{flight.campaign.id}|#{flight.campaign.adzerk_id}|#{flight.id}|#{flight.revenue_from_deltas}|#{core_balance}|#{kevel_balance}"
end
