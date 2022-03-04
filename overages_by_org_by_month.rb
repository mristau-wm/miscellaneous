# Example STDOUT:
# 12607|b3ac26b5-fdb4-43bd-9d7a-c5cc821a96df|1|2021-09-01|0
# 12607|b3ac26b5-fdb4-43bd-9d7a-c5cc821a96df|1|2021-10-01|0
# 12607|b3ac26b5-fdb4-43bd-9d7a-c5cc821a96df|2|2021-09-01|0

intervals = [
  {start_of_month: '2021-09-01', end_of_month: '2021-10-01'},
  {start_of_month: '2021-10-01', end_of_month: '2021-11-01'},
  {start_of_month: '2021-11-01', end_of_month: '2021-12-01'},
  {start_of_month: '2021-12-01', end_of_month: '2022-01-01'},
  {start_of_month: '2022-01-01', end_of_month: '2022-02-01'}
]

stats = {}
target_regions = [3261,3260,3259,173,281,3292,385,386,575,2267,574]

Advertising::Flight.find_each do |flight|
  campaign = flight.campaign
  organization = campaign.listing.advertising_organization
  regions = organization.regions
  region_ids = regions.pluck(:id)
  region_names = regions.pluck(:name)

  next if (target_regions & region_ids).empty?

  flight_stats = {
    organization_id: flight.campaign.listing.advertising_organization.id,
    organization_sf_account_id: flight.campaign.listing.advertising_organization.salesforce_id,
    month_stats: {}
  }

  intervals.each do |interval|
    cash_balance_at_start_of_the_month = flight.cash_account.balance(from_date: '2000-01-01', to_date: interval[:start_of_month]).to_i
    promo_balance_at_start_of_the_month = flight.monthly_promo_account.balance(from_date: '2000-01-01', to_date: interval[:start_of_month]).to_i
    total_balance_at_start_of_the_month = cash_balance_at_start_of_the_month + promo_balance_at_start_of_the_month

    funds_added_during_the_month = flight.cash_account.credit_entries.where("date >= '#{interval[:start_of_month]}' and date < '#{interval[:end_of_month]}'").select { |e| e.description.match /(Transferred from Organization)/ }.map { |e| e.credit_amounts.pluck(:amount) }.flatten.sum.to_i
    funds_removed_during_the_month = flight.cash_account.debit_entries.where("date >= '#{interval[:start_of_month]}' and date < '#{interval[:end_of_month]}'").select { |e| e.description.match /(Transferred from Advertising::Flight)/ }.map { |e| e.debit_amounts.pluck(:amount) }.flatten.sum.to_i

    budget_for_the_month = total_balance_at_start_of_the_month + funds_added_during_the_month - funds_removed_during_the_month

    spend_for_the_month = flight.deltas.where("created_at >= '#{interval[:start_of_month]}' and created_at < '#{interval[:end_of_month]}'").sum(:revenue).to_i * 100

    overage_for_the_month = spend_for_the_month - budget_for_the_month > 0 ? spend_for_the_month - budget_for_the_month : 0

    flight_stats[:month_stats][interval[:start_of_month]] = overage_for_the_month
    puts "#{flight_stats[:organization_id]}|#{flight_stats[:organization_sf_account_id]}|#{region_ids.join(',')}|#{region_names.join(',')}|#{flight.id}|#{interval[:start_of_month]}|#{overage_for_the_month}"
  end

  stats[flight.id] = flight_stats
end


# Below was run for the month of Jan (2022) to compare overage by using instant count revenue (from deltas) vs reported revenue
# Sheet: https://docs.google.com/spreadsheets/d/1nH03C-OWVBS7Ah7PuYNphD-QGq4yRAOidt5S6E830lY/edit#gid=774584947

# api = Adzerk::Api.new(cache_requests: true)

# report = begin
#   receipt = api.create_report(
#     group_by: %w[campaignid],
#     start_date: Time.current.beginning_of_month - 1.month,
#     end_date: Time.current.beginning_of_month
#   )
#   api.poll_report(report_id: receipt[:Id])
# end

# adzerk_campaigns = {}
# report[:Result][:Records].first[:Details].each do |detail|
#   adzerk_campaigns[detail[:Grouping][:CampaignId]] = (detail[:TrueRevenue] * 100).to_i
# end

# Advertising::Flight.find_each do |flight|
#   flight_stats = {
#     organization_id: flight.campaign.listing.advertising_organization.id,
#     organization_sf_account_id: flight.campaign.listing.advertising_organization.salesforce_id
#   }

#   cash_balance_at_start_of_the_month = flight.cash_account.balance(from_date: '2000-01-01', to_date: '2022-01-01').to_i
#   promo_balance_at_start_of_the_month = flight.monthly_promo_account.balance(from_date: '2000-01-01', to_date: '2022-01-01').to_i
#   total_balance_at_start_of_the_month = cash_balance_at_start_of_the_month + promo_balance_at_start_of_the_month

#   funds_added_during_the_month = flight.cash_account.credit_entries.where("date >= '#{'2022-01-01'}' and date < '#{'2022-02-01'}'").select { |e| e.description.match /(Transferred from Organization)/ }.map { |e| e.credit_amounts.pluck(:amount) }.flatten.sum.to_i
#   funds_removed_during_the_month = flight.cash_account.debit_entries.where("date >= '#{'2022-01-01'}' and date < '#{'2022-02-01'}'").select { |e| e.description.match /(Transferred from Advertising::Flight)/ }.map { |e| e.debit_amounts.pluck(:amount) }.flatten.sum.to_i

#   budget_for_the_month = total_balance_at_start_of_the_month + funds_added_during_the_month - funds_removed_during_the_month

#   spend_for_the_month = flight.deltas.where("created_at >= '#{'2022-01-01'}' and created_at < '#{'2022-02-01'}'").sum(:revenue).to_i * 100
#   reported_spend_for_the_month = adzerk_campaigns[flight.campaign.adzerk_id] || 0

#   overage_for_the_month = spend_for_the_month - budget_for_the_month > 0 ? spend_for_the_month - budget_for_the_month : 0

#   puts "#{flight_stats[:organization_id]}|#{flight_stats[:organization_sf_account_id]}|#{flight.id}|#{'2022-01-01'}|#{overage_for_the_month}|#{cash_balance_at_start_of_the_month}|#{promo_balance_at_start_of_the_month}|#{total_balance_at_start_of_the_month}|#{funds_added_during_the_month}|#{funds_removed_during_the_month}|#{budget_for_the_month}|#{spend_for_the_month}|#{reported_spend_for_the_month}"
# end
