dry_run = true

# Results of dry run
# - Acceptance: https://gist.github.com/mristau-wm/dd4c69f46a3b4d462ac64729b33120d6#file-lifetime_cap_correction_acceptance_results-txt
# - Production: https://gist.github.com/mristau-wm/dd4c69f46a3b4d462ac64729b33120d6#file-results-of-fry-run-of-lifetime_cap_correction-rb-on-production

Advertising::Flight.find_each do |flight|
  campaign = flight.campaign
  organization = campaign.listing.advertising_organization
  initial_lifetime_cap = flight.lifetime_cap

  puts "Processing flight #{flight.id} #{'(dry run)' if dry_run}"

  # Determine if the flight needs correction
  accurate_lifetime_cap = ((flight.revenue_from_deltas.to_i + flight.balance) / 100.0).ceil

  transfer_args = {
    price_value: 0,
    organization_id: organization.id,
    debit_entity: organization,
    credit_entity: flight,
    user_id: nil
  }
  transfer_service = Advertising::TransferService::Cash.new(transfer_args)
  current_lifetime_cap = transfer_service.send(:new_lifetime_cap, flight)

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
    adjustment_type = 'decrease'

    unless dry_run
      Plutus::Entry.create!(
        description: 'One-time Kevel lifetime cap correction entry',
        debits: [{ account: Advertising::Accounts.cash_correction, amount: price_value }],
        credits: [{ account: flight.cash_account, amount: price_value }]
      );nil

      Plutus::Entry.create!(
        description: 'advertising.lifetime_cap_adjustment.debit_exclusion',
        debits: [{ account: flight.cash_account, amount: price_value }],
        credits: [{ account: Advertising::Accounts.cash_correction, amount: price_value }]
      );nil
    end
  end

  flight.reload
  flight.cash_account.reload

  transfer_args = {
    price_value: 0,
    organization_id: organization.id,
    debit_entity: organization,
    credit_entity: flight,
    user_id: nil,
    entry_description: 'Lifetime cap force-refresh'
  }
  Advertising::TransferService::Cash.call(transfer_args) unless dry_run
  
  puts "CSV summary: #{flight.id},#{adjustment_amount},decrease,#{current_lifetime_cap},#{accurate_lifetime_cap},#{initial_lifetime_cap},#{flight.lifetime_cap},#{flight.balance},#{flight.revenue_from_deltas}"
rescue => e
  puts "Exception occurred: #{e.class} #{e.message} #{e.backtrace.join("\n")}"
end
