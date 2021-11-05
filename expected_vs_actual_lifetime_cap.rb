Advertising::Flight.find_each do |flight|
  amount_to_add_to_budget = flight.cash_account.credit_entries.select { |e| e.description.match /(Transferred from Organization|pretransfer\.cash_overage|whole_dollar_correction)/ }.map { |e| e.credit_amounts.pluck(:amount) }.flatten.sum.to_i
  amount_to_deduct_from_budget = flight.cash_account.debit_entries.select { |e| e.description.match /(Transferred from Advertising::Flight)/ }.map { |e| e.debit_amounts.pluck(:amount) }.flatten.sum.to_i
  expected_kevel_lifetime_cap = amount_to_add_to_budget - amount_to_deduct_from_budget

  puts "#{flight.campaign.listing.advertising_organization.id}|#{flight.campaign.id}|#{flight.campaign.adzerk_id}|#{flight.id}|#{flight.adzerk_id}|#{expected_kevel_lifetime_cap}|#{flight.lifetime_cap}|#{flight.attributes['revenue']}"
end
