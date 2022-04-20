source_org = Organization.find_by_hashid('m1qgk')
target_org = Organization.find_by_id('3555')

user_id = User.find_by_email('mristau@weedmaps.com').id

# transfer org funds to org

source_org_balance = source_org.available_cash_balance

transfer_options = {
  organization_id: source_org.id,
  debit_entity: source_org,
  credit_entity: target_org,
  user_id: user_id,
  entry_description: 'One-time transfer of funds between Organizations',
  price_value: source_org_balance
}

Advertising::TransferService::Cash.call(**transfer_options)

# transfer campaign funds to org

campaign = Advertising::Campaign.find_by_wmid('407125545')
campaign_balance = campaign.available_cash_balance

transfer_options = {
  organization_id: source_org.id,
  debit_entity: campaign.flight,
  credit_entity: target_org,
  user_id: user_id,
  entry_description: 'One-time transfer of funds between Organizations',
  price_value: campaign_balance
}

Advertising::TransferService::Cash.call(**transfer_options)
