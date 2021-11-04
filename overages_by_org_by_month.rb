# Example STDOUT:
# 12607|b3ac26b5-fdb4-43bd-9d7a-c5cc821a96df|1|2021-09-01|0
# 12607|b3ac26b5-fdb4-43bd-9d7a-c5cc821a96df|1|2021-10-01|0
# 12607|b3ac26b5-fdb4-43bd-9d7a-c5cc821a96df|2|2021-09-01|0

intervals = [
  {start_of_month: '2021-09-01', end_of_month: '2021-10-01'},
  {start_of_month: '2021-10-01', end_of_month: '2021-11-01'}
]

stats = {}

Advertising::Flight.find_each do |flight|
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
    puts "#{flight_stats[:organization_id]}|#{flight_stats[:organization_sf_account_id]}|#{flight.id}|#{interval[:start_of_month]}|#{overage_for_the_month}"
  end

  stats[flight.id] = flight_stats
end
