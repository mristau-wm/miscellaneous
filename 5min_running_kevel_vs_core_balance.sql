-- Example result set:

-- deltas_created_at	running_core_balance	running_adjusted_kevel_balance	running_adjusted_kevel_budget	running_revenue_total	running_credits_total	running_nonsettlement_debits_total	running_lifetime_cap_adjustment_credit_total	running_lifetime_cap_adjustment_debit_total	diff
-- 2022-02-15 18:25:58	141935.5969000000	4583.5969000000	3078800.0000000000	3074216.403100	3353504.0000000000	137352.0000000000	137352.0000000000	0	137352.0000000000
-- 2022-02-15 18:45:05	141423.3281000000	4071.3281000000	3078800.0000000000	3074728.671900	3353504.0000000000	137352.0000000000	137352.0000000000	0	137352.0000000000
-- 2022-02-15 18:50:04	141167.3088000000	3815.3088000000	3078800.0000000000	3074984.691200	3353504.0000000000	137352.0000000000	137352.0000000000	0	137352.0000000000

select sub2.*
, (running_core_balance - running_adjusted_kevel_balance) as diff
from (
    select created_at as deltas_created_at
    , (running_credits_total - running_nonsettlement_debits_total - running_revenue_total) as running_core_balance
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
            and ac.accountable_id = 4062 -- core flight ID
            and am.type = 'Plutus::CreditAmount'
            and e.created_at <= d.created_at
        ) as running_credits_total
        , (
            select coalesce (sum(am.amount), 0)
            from plutus_accounts ac
            join plutus_amounts am on (am.account_id = ac.id)
            join plutus_entries e on (e.id = am.entry_id)
            where ac.accountable_type = 'Advertising::Flight'
            and ac.accountable_id = 4062 -- core flight ID
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
            and ac.accountable_id = 4062 -- core flight ID
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
            and ac.accountable_id = 4062 -- core flight ID
            and am.type = 'Plutus::DebitAmount'
            and e.description = 'advertising.lifetime_cap_adjustment.debit_exclusion'
            and e.created_at <= d.created_at
        ) as running_lifetime_cap_adjustment_debit_total
        from advertising_flight_deltas d
        where d.advertising_flight_id = 4062 -- core flight ID
        and d.revenue > 0
    ) sub1
) sub2
where running_core_balance <> running_adjusted_kevel_balance -- optional
;
