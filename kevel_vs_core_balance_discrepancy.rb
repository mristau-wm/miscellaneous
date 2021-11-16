# To determine magnitude of discrepancy between kevel's balance (remaining budget) vs core's

# Example output:
# 12438|5673|50000|14677|35323|0|37823|37823|-2500
# 15153|5674|50000|20031|29969|0|33536|33536|-3567
# 17509|5675|50000|31745|18255|0|24416|24416|-6161

def pretransfer_correction_amount(flight)
  # nightly settlement fix released on Nov 12.
  # https://github.com/GhostGroup/weedmaps/releases/tag/pithily-restless-playback
  # sum pretransfer settlement cash/promo spent for the day prior to the nightly settlement morning of Nov 12
  flight.cash_account.debit_entries.where(date: '2021-11-11').select { |e| e.description.match /(pretransfer.cash_spent)/ }.map { |e| e.debit_amounts.pluck(:amount) }.flatten.sum.to_i
end


Advertising::Flight.find_each do |flight|
  kevel_remaining_budget = flight.lifetime_cap - flight.revenue_from_deltas.to_i
  pretransfer_correction_amount = pretransfer_correction_amount(flight)
  corrected_balance = flight.available_cash_balance + pretransfer_correction_amount(flight)
  balance_discrepancy = kevel_remaining_budget - corrected_balance

  puts "#{flight.campaign.listing.advertising_organization.id}|#{flight.id}|#{flight.lifetime_cap}|#{flight.revenue_from_deltas.to_i}|#{kevel_remaining_budget}|#{pretransfer_correction_amount}|#{flight.available_cash_balance}|#{corrected_balance}|#{balance_discrepancy}"
end
