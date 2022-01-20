# KBOA issue was that kevel budget became greater than core budget.
# Now that we've fixed the app to prevent this from happening,
# we want to monitor to alert if it happens again.
# But first we want to resolve existing discrepancies.
# 
# So, for campaigns with kevel budget greater than core budget,
# we want to sync them. We'll credit the campaign with the difference.
#
# Output example: https://docs.google.com/spreadsheets/d/1_EX-6GCZze-vYexEuQc_HwCA2kVegDwDnKD1wb0zKWI/edit#gid=1322562653

# Grant logic

def campaign_budget(campaign)
  campaign.flight.accounts.sum { |account| adjusted_campaign_budget account }
end

def adjusted_campaign_budget(account)
  total_credits_amount = account.credits_balance
  non_settlement_debits_amount = account.debit_entries
    .reject { |e| Advertising::Utility.settlement_entry? e }
    .sum { |e| e.debit_amounts.sum(:amount) }
  total_credits_amount - non_settlement_debits_amount
end

Advertising::Campaign.find_each do |campaign|
  # puts "Processing campaign ID #{campaign.id}"

  flight = campaign.flight
  next unless flight

  core_budget = campaign_budget(campaign)
  kevel_budget = flight.lifetime_cap

  # next if kevel_budget <= core_budget
  # next if kevel_budget.zero?

  core_spend = flight.settled_revenue + flight.unsettled_revenue
  kevel_spend = flight.revenue_from_deltas

  core_balance = flight.balance
  kevel_balance = flight.lifetime_cap - flight.revenue_from_deltas

  # temp, for pre-lim analysis
  grant_amount = kevel_balance - core_balance
  grant_amount = 0 if kevel_balance <= core_balance
  grant_amount = 0 if kevel_budget.zero?

  puts "#{campaign.listing.advertising_organization.id}|#{campaign.id}|#{campaign.adzerk_id}|#{flight.adzerk_id}|#{core_budget}|#{kevel_budget}|#{grant_amount}|#{core_spend}|#{kevel_spend}|#{core_balance}|#{kevel_balance}"
end
