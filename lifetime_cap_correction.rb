dry_run = true

# Results of dry run
# - Acceptance: https://gist.github.com/mristau-wm/dd4c69f46a3b4d462ac64729b33120d6#file-lifetime_cap_correction_acceptance_results-txt
# - Production (2022-02-09): https://gist.github.com/mristau-wm/dd4c69f46a3b4d462ac64729b33120d6#file-production-2022-02-09
# - Production (2022-02-08): https://gist.github.com/mristau-wm/dd4c69f46a3b4d462ac64729b33120d6#file-production-2022-02-08

api = Adzerk::Api.new
SECOND_PRICE_FLIGHT_IDS = [12084940, 12084944, 12084945, 12084947, 12084953, 12084961, 12084965, 12084972, 12084980, 12084983, 12084985, 12084989, 12084990, 12084991, 12123050, 12123052, 12123053, 12123054, 12123056, 12123057, 12123058, 12123060, 12123065, 12123067, 12123069, 12123071, 12123072, 12123073, 12123094, 12123095, 12123097, 12123100, 12123102, 12123106, 12123109, 12123114, 12123119, 12123129, 12123132, 12123167, 12123170, 12123171, 12123173, 12123174, 12123175, 12123176, 12123180, 12439895, 12507887, 12507933, 12509941, 12510279, 12510281, 12510287, 12510294, 12510300, 12510348, 12511923, 12511925, 12511926, 12511936, 12511940, 12511945, 12511973, 12512096, 12512178, 12512185, 12512188, 12512189, 12512190, 12512191, 12512194, 12512205, 12512211, 12512214, 12512223, 12512297, 12512311, 12512312, 12512315, 12512317, 12512323, 12512327, 12512334, 12512338, 12512339, 12512344, 12512346, 12512355, 12512357, 12512386, 12512492, 12512529, 12512530, 12512544, 12512547, 12512558, 12512560, 12512562, 12512564, 12512583, 12512585, 12512586, 12512588, 12513803, 12513805, 12513806, 12513809, 12513844, 12513850, 12513853, 12513870, 12513878, 12513882, 12513885, 12513887, 12513891, 12513896, 12513904, 12513906, 12513909, 12513911, 12513915, 12513917, 12513926, 12513936, 12513989, 12514809, 12514810, 12518060, 12518168, 12518169, 12518172, 12518173, 12518174, 12518175, 12518186, 12518190, 12518192, 12518847, 12518848, 12519012, 12519041, 12519045, 12522314, 12522552, 12523458, 12532762, 12532763, 12532768, 12532772, 12532773, 12532778, 12532779, 12532791, 12534869, 12534891, 12535500, 12535590, 12535594, 12535600, 12535608, 12535612, 12535639, 12535696, 12540280, 12540529, 12541823, 12542166, 12550406, 12550411, 12550525, 12550531, 12562058, 12562386, 12562389, 12562419, 12569400, 12576633, 12620471, 12916321, 12916366, 12916409, 12916446, 12916482, 12941094, 12941216, 14678804, 15092411, 15118751, 15156909, 15182588, 15189642, 15189672, 15210859, 15255295, 15255296, 15772399, 15772409, 16018394, 16018440, 16018590, 16542401, 16542426, 16655589, 16669365, 16987680, 17359078, 17359162, 17607965, 17607978, 17607985, 21775054, 27665069, 27665072]

def sync_all_flights(dry_run: true)
  Advertising::Flight.find_each do |flight|
    sync_balances(flight, dry_run: dry_run)
  end
end

###############################
# Correcting single flight    #
###############################

def sync_balances(flight, dry_run: true)
  api = Adzerk::Api.new

  campaign = flight.campaign
  organization = campaign.listing.advertising_organization
  initial_lifetime_cap = flight.lifetime_cap

  puts "Processing flight #{flight.id} #{'(dry run)' if dry_run}"

  if SECOND_PRICE_FLIGHT_IDS.include? flight.adzerk_id
    puts "This flight has a 2nd Price Auction priority. No correction needed."
    return
  end

  # Determine if the flight needs correction
  accurate_lifetime_cap_cents = (flight.revenue_from_deltas.to_i + flight.balance)
  accurate_lifetime_cap = accurate_lifetime_cap_cents / 100.0

  transfer_args = {
    price_value: 0,
    organization_id: organization.id,
    debit_entity: organization,
    credit_entity: flight,
    user_id: nil
  }
  transfer_service = Advertising::TransferService::Cash.new(transfer_args)

  budget = flight.accounts.sum { |account| transfer_service.send(:adjusted_campaign_budget, account) }
  current_lifetime_cap = budget / 100.0

  puts "Current lifetime cap: \$#{current_lifetime_cap}. Accurate lifetime cap: \$#{accurate_lifetime_cap}"

  if current_lifetime_cap == accurate_lifetime_cap
    puts "Skipping flight. Lifetime cap does not need correction."
    return
  end

  # Determine the correction amount
  adjustment_amount = (current_lifetime_cap - accurate_lifetime_cap).abs * 100 # convert dollars to cents

  # Apply the correction for that amount
  if current_lifetime_cap > accurate_lifetime_cap
    puts "Subtracting \$#{adjustment_amount} from lifetime cap"
    adjustment_type = 'decrease'

    unless dry_run
      Plutus::Entry.create!(
        description: 'advertising.lifetime_cap_adjustment.credit_exclusion',
        debits: [{ account: Advertising::Accounts.cash_correction, amount: adjustment_amount }],
        credits: [{ account: flight.cash_account, amount: adjustment_amount }]
      );nil

      Plutus::Entry.create!(
        description: 'One-time Kevel lifetime cap correction entry',
        debits: [{ account: flight.cash_account, amount: adjustment_amount }],
        credits: [{ account: Advertising::Accounts.cash_correction, amount: adjustment_amount }]
      );nil
    end
  else
    puts "Adding \$#{adjustment_amount} to lifetime cap"
    adjustment_type = 'increase'

    unless dry_run
      Plutus::Entry.create!(
        description: 'One-time Kevel lifetime cap correction entry',
        debits: [{ account: Advertising::Accounts.cash_correction, amount: adjustment_amount }],
        credits: [{ account: flight.cash_account, amount: adjustment_amount }]
      );nil

      Plutus::Entry.create!(
        description: 'advertising.lifetime_cap_adjustment.debit_exclusion',
        debits: [{ account: flight.cash_account, amount: adjustment_amount }],
        credits: [{ account: Advertising::Accounts.cash_correction, amount: adjustment_amount }]
      );nil
    end
  end

  # Make whole dollar correction
  rounded_up_accurate_lifetime_cap_cents = accurate_lifetime_cap_cents.ceil(-2)
  whole_dollar_correction_cents = rounded_up_accurate_lifetime_cap_cents - accurate_lifetime_cap_cents
  rounded_up_accurate_lifetime_cap = rounded_up_accurate_lifetime_cap_cents / 100.0
  
  if whole_dollar_correction_cents.zero?
    puts "Does not need whole dollar correction"
  else
    puts "Creating whole dollar correction entry of #{whole_dollar_correction_cents} cents"

    unless dry_run
      Plutus::Entry.create!(
        description: 'advertising.budget_transfer.whole_dollar_correction',
        debits: [{ account: Advertising::Accounts.cash_correction, amount: whole_dollar_correction_cents }],
        credits: [{ account: flight.cash_account, amount: whole_dollar_correction_cents }],
      )
    end
  end

  flight.reload
  flight.cash_account.reload

  unless dry_run
    api.update_flight_cap(flight_id: flight.adzerk_id, amount: rounded_up_accurate_lifetime_cap)
  end
  
  csv_summary = "#{organization.id},#{flight.id},#{flight.adzerk_id},#{adjustment_amount},#{adjustment_type},#{current_lifetime_cap},#{accurate_lifetime_cap},#{rounded_up_accurate_lifetime_cap},#{initial_lifetime_cap},#{flight.balance},#{flight.revenue_from_deltas},#{whole_dollar_correction_cents}"

  unless dry_run
    sleep 1 # allow for db replication time
    flight.reload
    final_core_balance = flight.balance
    final_kevel_lifetime_cap = flight.lifetime_cap
    final_kevel_balance = final_kevel_lifetime_cap - flight.revenue_from_deltas

    flight.accounts { |a| a.reload }
    transfer_args = {
      price_value: 0,
      organization_id: organization.id,
      debit_entity: organization,
      credit_entity: flight,
      user_id: nil
    }
    transfer_service = Advertising::TransferService::Cash.new(transfer_args)

    final_budget = flight.accounts.sum { |account| transfer_service.send(:adjusted_campaign_budget, account) }

    csv_summary += ",#{final_core_balance},#{final_kevel_lifetime_cap},#{final_kevel_balance},#{final_budget}"
  end

  puts "CSV summary: #{csv_summary}"
rescue => e
  puts "Exception occurred: #{e.class} #{e.message} #{e.backtrace.join("\n")}"
end







###############################
# Checking single flight data #
###############################

def print_flight_calculated_budget(flight)
  campaign = flight.campaign
  organization = campaign.listing.advertising_organization

  flight.cash_account.reload

  transfer_args = {
    price_value: 0,
    organization_id: organization.id,
    debit_entity: organization,
    credit_entity: flight,
    user_id: nil
  }
  transfer_service = Advertising::TransferService::Cash.new(transfer_args)

  budget = flight.accounts.sum { |account| transfer_service.send(:adjusted_campaign_budget, account) }.to_i
  
  puts "Calculated budget: #{budget}"

#   flight.lifetime_cap # 3000
#   flight.balance #  2994
#   revenue = flight.revenue_from_deltas.to_i # 101
#   flight.lifetime_cap - revenue # 2899
end
