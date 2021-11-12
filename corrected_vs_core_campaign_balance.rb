# This script calculates the campaign balances for all Advertising::Flight records by excluding pretransfer.cash_overage credit amounts
# TODO: Ensure core data reflects the same time period as the Kevel-reported revenue

# Formula: transferred from org to campaign
# - transferred from campaign to org
# + nightly.cash_overage <-- if the campaign had repeated overages due to discrepancy, this will be inflated but we have to absorb this
# + whole_dollar_correction
# + any credit entries not covered above and excluding pretransfer.cash_spent (because its covered in nightly.cash_spent)
# - any debit entries not settlement entries (because this will be reflected by kevel revenue)
# - kevel revenue <-- reported

# Example output:
# 12607|1||85000|85000|0
# 12607|2||1500000|1500000|0
# 12607|3||5000|5000|0
# 12607|4||0|5000|0
# 545|5|0.0|0|0|0

api = Adzerk::Api.new(cache_requests: true)

end_date = Time.current.beginning_of_day - 1.day

report = begin
  receipt = api.create_report(
    group_by: %w[campaignid],
    start_date: Advertising::Flight.order(:created_at).first.created_at,
    end_date: end_date
  )
  api.poll_report(report_id: receipt[:Id])
end

adzerk_campaigns = {}
report[:Result][:Records].first[:Details].each do |detail|
  adzerk_campaigns[detail[:Grouping][:CampaignId]] = (detail[:TrueRevenue] * 100).to_i
end

def adjusted_campaign_budget(account)
  credits_amount = account.credit_entries.where("created_at < ?", end_date).reject { |e| e.description.match /pretransfer\.cash_overage/ }.sum { |e| e.credit_amounts.sum(:amount) }
  non_settlement_debits_amount = account.debit_entries.where("created_at < ?", end_date).reject { |e| Advertising::Utility.settlement_entry? e }.sum { |e| e.debit_amounts.sum(:amount) }
  credits_amount - non_settlement_debits_amount
end

Advertising::Flight.find_each do |flight|
  organization_id = flight.campaign.listing.advertising_organization.id
  adzerk_campaign_revenue = adzerk_campaigns[flight.campaign.adzerk_id]

  cash_balance = adjusted_campaign_budget(flight.cash_account)
  promo_balance = adjusted_campaign_budget(flight.monthly_promo_account)

  if !adzerk_campaign_revenue
    corrected_campaign_balance = ''
  else
    corrected_campaign_balance = cash_balance + promo_balance - adzerk_campaign_revenue
    corrected_campaign_balance = [corrected_campaign_balance, 0].max
  end

  core_campaign_balance = flight.available_cash_balance + flight.available_promo_balance
  puts "#{organization_id}|#{flight.id}|#{corrected_campaign_balance}|#{core_campaign_balance}|#{flight.available_cash_balance}|#{flight.available_promo_balance}"
end
