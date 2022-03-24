-- Example result set:

-- settlement_entry_creation_time	running_settled_revenue_total	running_deltas_revenue_total	diff
-- 2021-09-15 07:15:34	17025.0000000000	20501.962000	-3476.9620000000
-- 2021-09-16 07:15:34	54488.0000000000	59150.873200	-4662.8732000000
-- 2021-09-17 07:15:06	95043.0000000000	100260.857400	-5217.8574000000


select created_at as settlement_entry_creation_time
, running_settled_revenue_total
, running_deltas_revenue_total
, (running_settled_revenue_total - running_deltas_revenue_total) as diff
from
(
        select created_at
        , (
                select sum(am.amount)
                from plutus_accounts ac
                join plutus_amounts am on (am.account_id = ac.id)
                join plutus_entries e on (e.id = am.entry_id)
                where ac.accountable_type = 'Advertising::Flight'
                and ac.accountable_id = 4062 -- core flight ID
                and am.type = 'Plutus::DebitAmount'
                and e.description like 'advertising.revenue_settlement%'
                and e.created_at <= sub1.created_at
        ) as running_settled_revenue_total
        , (
                select sum(revenue * 100)
                from advertising_flight_deltas
                where advertising_flight_id = 4062 -- core flight ID
                and revenue > 0
                and created_at < sub1.created_at
        ) as running_deltas_revenue_total
        from
        (
                select e.created_at
                from plutus_accounts ac
                join plutus_amounts am on (am.account_id = ac.id)
                join plutus_entries e on (e.id = am.entry_id)
                where ac.accountable_type = 'Advertising::Flight'
                and ac.accountable_id = 4062 -- core flight ID
                and am.type = 'Plutus::DebitAmount'
                and e.description like 'advertising.revenue_settlement%'
        ) sub1
) sub2
order by created_at asc;
