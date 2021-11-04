-- Example result set:
-- date_part	date_part	id	sum
-- 2021.0	4.0	116	28.0000000000
-- 2021.0	4.0	154	349.0000000000

select extract(year from e.date), extract(month from e.date), f.id, sum(am.amount)
from plutus_accounts ac
join advertising_flights f on (f.id = ac.accountable_id)
join plutus_amounts am on (am.account_id = ac.id)
join plutus_entries e on (e.id = am.entry_id)
where accountable_type = 'Advertising::Flight'
and (
  e.description like '%nightly.cash_overage'
  or e.description like '%monthly_promo_overage'
  or e.description like '%whole_dollar_correction'
)
and am.type = 'Plutus::CreditAmount'
group by extract(year from e.date), extract(month from e.date), f.id;
