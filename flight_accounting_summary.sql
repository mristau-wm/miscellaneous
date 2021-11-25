-- Example result set:
-- 4621	5005.0000000000	Plutus::DebitAmount	advertising.revenue_settlement.nightly.cash_spent	2021-11-25	2021-11-25 08:15:23
-- 4621	5425.0000000000	Plutus::DebitAmount	advertising.revenue_settlement.adjustment.cash_spent	2021-11-23	2021-11-25 08:15:20
-- 4621	5394.0000000000	Plutus::DebitAmount	advertising.cor9294.cash_spent	2021-11-24	2021-11-24 23:53:24

select f.id, am.amount, am.type, e.description, e.date, e.created_at
from plutus_accounts ac
join advertising_flights f on (f.id = ac.accountable_id)
join plutus_amounts am on (am.account_id = ac.id)
join plutus_entries e on (e.id = am.entry_id)
join advertising_campaigns c on (f.advertising_campaign_id = c.id)
where accountable_type = 'Advertising::Flight'
and c.adzerk_id = 33138456
order by e.created_at desc;
