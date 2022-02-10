dry_run = true

# Results of dry run
# - Acceptance: https://gist.github.com/mristau-wm/dd4c69f46a3b4d462ac64729b33120d6#file-lifetime_cap_correction_acceptance_results-txt
# - Production (2022-02-09): https://gist.github.com/mristau-wm/dd4c69f46a3b4d462ac64729b33120d6#file-production-2022-02-09
# - Production (2022-02-08): https://gist.github.com/mristau-wm/dd4c69f46a3b4d462ac64729b33120d6#file-production-2022-02-08

api = Adzerk::Api.new

Advertising::Flight.find_each do |flight|
  campaign = flight.campaign
  organization = campaign.listing.advertising_organization
  initial_lifetime_cap = flight.lifetime_cap

  puts "Processing flight #{flight.id} #{'(dry run)' if dry_run}"

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
  adzerk_cap_in_cents = budget.ceil(-2)
  current_lifetime_cap = adzerk_cap_in_cents / 100.0

  puts "Current lifetime cap: \$#{current_lifetime_cap}. Accurate lifetime cap: \$#{accurate_lifetime_cap}"

  if current_lifetime_cap == accurate_lifetime_cap
    puts "Skipping flight. Lifetime cap does not need correction."
    next
  end

  # Determine the correction amount
  adjustment_amount = (current_lifetime_cap - accurate_lifetime_cap).abs

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
  
  puts "CSV summary: #{organization.id},#{flight.id},#{flight.adzerk_id},#{adjustment_amount},#{adjustment_type},#{current_lifetime_cap},#{accurate_lifetime_cap},#{rounded_up_accurate_lifetime_cap},#{initial_lifetime_cap},#{flight.balance},#{flight.revenue_from_deltas},#{whole_dollar_correction_cents}"
rescue => e
  puts "Exception occurred: #{e.class} #{e.message} #{e.backtrace.join("\n")}"
end
