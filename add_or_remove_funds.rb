org = Organization.find_by_id(17264)

# add promo credits to org
Plutus::Entry.create!(
  description: 'One-time promo credit',
  debits: [{ account: Advertising::Accounts.monthly_promo, amount: 5000 }],
  credits: [{ account: org.monthly_promo_account, amount: 5000 }]
)

# remove $1 from promo
Plutus::Entry.create!(
  description: 'One-time promo credit removal',
  debits: [{ account: org.monthly_promo_account, amount: 100 }],
  credits: [{ account: Advertising::Accounts.monthly_promo, amount: 100 }]
)


# add $1 to cash
Plutus::Entry.create!(
  description: 'One-time cash credit',
  debits: [{ account: Advertising::Accounts.cash, amount: 100 }],
  credits: [{ account: org.cash_account, amount: 100 }]
)
