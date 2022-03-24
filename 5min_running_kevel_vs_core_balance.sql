-- Example result set:

-- deltas_created_at	running_core_balance	running_adjusted_kevel_balance	running_adjusted_kevel_budget	running_revenue_total	running_credits_total	running_nonsettlement_debits_total	running_lifetime_cap_adjustment_credit_total	running_lifetime_cap_adjustment_debit_total
-- 2021-12-16 17:30:11	99965.0000000000	99965.0000000000	100000.0000000000	35.000000	100000.0000000000	0	0	0
-- 2021-12-16 17:45:07	99930.0000000000	99930.0000000000	100000.0000000000	70.000000	100000.0000000000	0	0	0
-- 2021-12-16 17:50:10	99790.0000000000	99790.0000000000	100000.0000000000	210.000000	100000.0000000000	0	0	0

select created_at as deltas_created_at
, (running_credits_total - running_revenue_total) as running_core_balance
, ( (running_credits_total - running_lifetime_cap_adjustment_credit_total) - (running_nonsettlement_debits_total - running_lifetime_cap_adjustment_debit_total) - running_revenue_total ) as running_adjusted_kevel_balance
, ( (running_credits_total - running_lifetime_cap_adjustment_credit_total) - (running_nonsettlement_debits_total - running_lifetime_cap_adjustment_debit_total) ) as running_adjusted_kevel_budget
, running_revenue_total
, running_credits_total
, running_nonsettlement_debits_total
, running_lifetime_cap_adjustment_credit_total
, running_lifetime_cap_adjustment_debit_total
from (
    select d.created_at
    , sum(100 * d.revenue) over (order by d.created_at) as running_revenue_total
    , (
        select sum(am.amount)
        from plutus_accounts ac
        join plutus_amounts am on (am.account_id = ac.id)
        join plutus_entries e on (e.id = am.entry_id)
        where ac.accountable_type = 'Advertising::Flight'
        and ac.accountable_id = 6251 -- core flight ID
        and am.type = 'Plutus::CreditAmount'
        and e.created_at <= d.created_at
    ) as running_credits_total
    , (
        select coalesce (sum(am.amount), 0)
        from plutus_accounts ac
        join plutus_amounts am on (am.account_id = ac.id)
        join plutus_entries e on (e.id = am.entry_id)
        where ac.accountable_type = 'Advertising::Flight'
        and ac.accountable_id = 6251 -- core flight ID
        and am.type = 'Plutus::DebitAmount'
        and e.description not like 'advertising.revenue_settlement%'
        and e.created_at <= d.created_at
    ) as running_nonsettlement_debits_total
    , (
        select coalesce (sum(am.amount), 0)
        from plutus_accounts ac
        join plutus_amounts am on (am.account_id = ac.id)
        join plutus_entries e on (e.id = am.entry_id)
        where ac.accountable_type = 'Advertising::Flight'
        and ac.accountable_id = 6251 -- core flight ID
        and am.type = 'Plutus::CreditAmount'
        and e.description = 'advertising.lifetime_cap_adjustment.credit_exclusion'
        and e.created_at <= d.created_at
    ) as running_lifetime_cap_adjustment_credit_total
, (
        select coalesce (sum(am.amount), 0)
        from plutus_accounts ac
        join plutus_amounts am on (am.account_id = ac.id)
        join plutus_entries e on (e.id = am.entry_id)
        where ac.accountable_type = 'Advertising::Flight'
        and ac.accountable_id = 6251 -- core flight ID
        and am.type = 'Plutus::DebitAmount'
        and e.description = 'advertising.lifetime_cap_adjustment.debit_exclusion'
        and e.created_at <= d.created_at
    ) as running_lifetime_cap_adjustment_debit_total
    from advertising_flight_deltas d
    where d.advertising_flight_id = 6251 -- core flight ID
    and d.revenue > 0
) sub1
;
