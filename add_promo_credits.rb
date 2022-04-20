org = Organization.find_by_id('17264')
amount = 5000

Plutus::Entry.create!(
  description: 'One-time promo credit',
  debits: [{ account: Advertising::Accounts.monthly_promo, amount: amount }],
  credits: [{ account: org.monthly_promo_account, amount: amount }]
)
