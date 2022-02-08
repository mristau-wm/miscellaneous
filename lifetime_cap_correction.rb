Advertising::Flight.find_each do |flight|
  campaign = flight.campaign
  organization = campaign.listing.advertising_organization

  puts "Processing flight #{flight.id}"

  # does this need correction?
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

  puts "Current lifetime cap: #{current_lifetime_cap}. New lifetime cap: #{accurate_lifetime_cap}"

  if current_lifetime_cap == accurate_lifetime_cap
    puts "Skipping flight. Lifetime cap does not need correction."
    next
  end

  # Flight needs correction. Determine the amount
  adjustment_amount = abs(current_lifetime_cap - accurate_lifetime_cap)

  # Apply the correction for that amount
  if current_lifetime_cap > accurate_lifetime_cap
    puts "Subtracting #{adjustment_amount} from lifetime cap"

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
  else
    puts "Adding #{adjustment_amount} to lifetime cap"

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
  Advertising::TransferService::Cash.call(transfer_args)
rescue => e
  puts "Exception occurred: #{e.class} #{e.message} #{e.backtrace.join("\n")}"
end
