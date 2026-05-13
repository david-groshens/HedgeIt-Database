
CREATE TABLE dbo.hedgeit_instrument (
    instrument_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    currency_pair NVARCHAR(255),
    notional_currency NVARCHAR(255),
    contract_currency NVARCHAR(255),
    multiplier INT,
    maturity DATE,
    [type] NVARCHAR(255),
    option_type NVARCHAR(255),
    strike DECIMAL(19,6) --finish
);
GO

CREATE TABLE dbo.hedgeit_micro_replication (
    micro_replication_id INT IDENTITY(1,1) PRIMARY KEY,
    cash DECIMAL(19, 6) NULL,
    currency NVARCHAR(255),
    instrument1 INT NULL,
    instrument2 INT NULL,
    instrument3 INT NULL,
    instrument4 INT NULL,
    instrument5 INT NULL,
    instrument6 INT NULL,
    instrument7 INT NULL,
    instrument8 INT NULL,
    instrument9 INT NULL,
    instrument10 INT NULL,
    instrument11 INT NULL,
    instrument12 INT NULL,
    position1 INT NULL,
    position2 INT NULL,
    position3 INT NULL,
    position4 INT NULL,
    position5 INT NULL,
    position6 INT NULL,
    position7 INT NULL,
    position8 INT NULL,
    position9 INT NULL,
    position10 INT NULL,
    position11 INT NULL,
    position12 INT NULL,
);
GO

CREATE TABLE dbo.fut_hedge (
    id INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate primary key for this hedge row.
    trade_id NVARCHAR(255) NULL, -- External or upstream trade identifier.
    [sequence] INT NULL, -- Sequence or line number within the trade (legacy; not IDENTITY).
    client NVARCHAR(255) NULL, -- Legacy client code; unused, kept for compatibility.
    client_alias NVARCHAR(255) NULL, -- Display name or alias for the client.
    trade_status NVARCHAR(255) NULL, -- Workflow status of the hedge/trade.
    client_ref NVARCHAR(255) NULL, -- Client reference, ticket, or deal id.
    [type] NVARCHAR(255) NULL, -- Trade classification (e.g. hedge vs other).
    currency_pair NVARCHAR(255) NULL, -- Six-letter FX pair code (e.g. EURUSD).
    instrument_currency NVARCHAR(255) NULL, -- Currency the instrument is quoted in.
    hedged_currency NVARCHAR(255) NULL, -- Currency exposure being hedged.
    trade_date DATE NULL, -- Trade execution or booking date.
    window_forward_start_date DATE NULL, -- Start of optional forward window; NULL means no window.
    maturity DATE NULL, -- Contract or hedge maturity date.
    conversion_date DATE NULL, -- Conversion or cash-flow date when applicable.
    hedged_amount_formula NVARCHAR(255) NULL, -- Text formula for hedged notional (display/audit).
    hedged_amount DECIMAL(19, 6) NULL, -- Hedged notional amount in hedged_currency.
    client_strike DECIMAL(19, 6) NULL, -- Client strike or contractual conversion rate.
    initial_fx DECIMAL(19, 6) NULL, -- Spot or deal FX rate at inception.
    futures_maturity DATE NULL, -- Maturity date of the futures leg.
    futures_rate NVARCHAR(255) NULL, -- Futures price or implied rate (text for parsing).
    roll_spreads NVARCHAR(255) NULL, -- Roll or spread parameters (text).
    se_initial_margin DECIMAL(19, 6) NULL, -- Service-entity initial margin requirement.
    se_maintenance_margin DECIMAL(19, 6) NULL, -- Service-entity maintenance margin.
    se_fee DECIMAL(19, 6) NULL, -- Service-entity fee rate used in accruals.
    se_fee_formula NVARCHAR(255) NULL, -- Text formula describing the SE fee.
    se_fee_embedded DECIMAL(19, 6) NULL, -- Embedded portion of the SE fee.
    announced_profit DECIMAL(19, 6) NULL, -- Announced profit rate for gross accrual.
    margin_per_trade BIT, -- TRUE if margin is tracked per trade rather than portfolio.
    spot_rate DECIMAL(19, 6) NULL, -- Spot FX for valuation (pair vs USD context).
    forward_rate DECIMAL(19, 6) NULL, -- Forward FX rate for valuation.
    micro_replication INT NULL, -- Replication or sizing factor (integer scale).
    associated_trade_id NVARCHAR(255) NULL, -- Linked trade id when this row is part of a bundle.
    cross_strike DECIMAL(19, 6) NULL, -- Cross or secondary strike used in structure.
    commentaires NVARCHAR(255) NULL, -- Free-form notes on the trade.
    today_date DATE NULL, -- Valuation "as of" date driving time-based computed columns.
    sub_accounts_projects NVARCHAR(255) NULL, -- Sub-account or project tag for reporting.
    margin_currency NVARCHAR(255), -- ISO currency code for margin_amount.
    margin_amount DECIMAL(19, 6) NULL, -- Margin notional in margin_currency.

    -- First leg of the pair: left three characters of currency_pair.
    currency_1 AS (LEFT(currency_pair, 3)) PERSISTED,
    -- Second leg of the pair: right three characters of currency_pair.
    currency_2 AS (RIGHT(currency_pair, 3)) PERSISTED,

    -- Text mirror of client amount in currency_1 (formula branch matches hedged leg / strike).
    client_amt_currency_1_formula AS (
        CASE
            WHEN LEFT(currency_pair, 3) = hedged_currency THEN hedged_amount_formula
            WHEN client_strike = 0 THEN '0'
            ELSE STR(ROUND(-(hedged_amount / client_strike), 0))
        END
    ) PERSISTED,
    -- Text mirror of client amount in currency_2 (formula branch matches hedged leg / strike).
    client_amt_currency_2_formula AS (
        CASE
            WHEN RIGHT(currency_pair, 3) = hedged_currency THEN hedged_amount_formula
            WHEN client_strike = 0 THEN '0'
            ELSE STR(ROUND(-(hedged_amount * client_strike), 0))
        END
    ) PERSISTED,
    -- Client notional in currency_1: hedged amount or amount implied via client_strike.
    client_amt_currency_1 AS (
        CASE
            WHEN LEFT(currency_pair, 3) = hedged_currency THEN hedged_amount
            WHEN client_strike = 0 THEN 0
            ELSE ROUND(-(hedged_amount / client_strike), 0)
        END
    ) PERSISTED,
    -- Client notional in currency_2: hedged amount or amount implied via client_strike.
    client_amt_currency_2 AS (
        CASE
            WHEN RIGHT(currency_pair, 3) = hedged_currency THEN hedged_amount
            WHEN client_strike = 0 THEN 0
            ELSE ROUND(-(hedged_amount * client_strike), 0)
        END
    ) PERSISTED,

    -- Hedge notional in currency_1: direct hedged leg or futures vs initial FX by type.
    -- Mirrors legacy IIf on hedged currency and "Hedge" type routing through futures_rate.
    h_amt_currency_1 AS (
        CASE
            WHEN currency_1 = hedged_currency THEN hedged_amount
            WHEN lower(rtrim(ltrim([type]))) = N'hedge' THEN
                -hedged_amount / nullif(try_cast(futures_rate AS DECIMAL(19, 6)), 0)
            ELSE
                -hedged_amount / nullif(initial_fx, 0)
        END
    ) PERSISTED,

    -- Hedge notional in currency_2: hedged leg unchanged, else scaled by futures_rate.
    h_amt_currency_2 AS (
        CASE
            WHEN currency_2 = hedged_currency THEN hedged_amount
            ELSE -hedged_amount * try_cast(futures_rate AS DECIMAL(19, 6))
        END
    ) PERSISTED,

    -- Mark-to-market style term in non-instrument currency: client amt × forward, scaled by spot if needed.
    valuation_non_instrument_cur AS (
        CASE
            WHEN currency_1 = instrument_currency THEN
                -client_amt_currency_1 * forward_rate
            ELSE
                -client_amt_currency_1 * forward_rate / nullif(spot_rate, 0)
        END
    ) PERSISTED,

    -- Forward vs futures P/L expressed in the pair's second currency (branch on USD in currency_1).
    forward_pl_currency_2 AS (
        CASE
            WHEN currency_1 = N'USD' THEN
                (forward_rate - try_cast(futures_rate AS DECIMAL(19, 6))) * h_amt_currency_1
            ELSE
                (forward_rate - try_cast(futures_rate AS DECIMAL(19, 6))) * h_amt_currency_2
        END
    ) PERSISTED,

    -- Forward P/L in first currency: currency_2 leg converted through spot_rate (zero spot yields zero).
    forward_pl_currency_1 AS (
        CASE
            WHEN spot_rate = 0 THEN 0
            ELSE forward_pl_currency_2 / nullif(spot_rate, 0)
        END
    ) PERSISTED,

    -- Cumulative carry in currency_2: forward P/L minus (spot − initial) hedge exposure.
    cumulated_carry_currency_2 AS (
        CASE
            WHEN currency_1 = N'USD' THEN
                forward_pl_currency_2 - (spot_rate - initial_fx) * h_amt_currency_1
            ELSE
                forward_pl_currency_2 - (spot_rate - initial_fx) * h_amt_currency_2
        END
    ) PERSISTED,

    -- Total carry in currency_2: (initial FX − futures) times hedge amount (USD leg picks h_amt side).
    total_carry_currency_2 AS (
        CASE
            WHEN currency_1 = N'USD' THEN
                (initial_fx - try_cast(futures_rate AS DECIMAL(19, 6))) * h_amt_currency_1
            ELSE
                (initial_fx - try_cast(futures_rate AS DECIMAL(19, 6))) * h_amt_currency_2
        END
    ) PERSISTED,

    -- Effective maturity for analytics: max(maturity,today) without window; with window, midpoint between capped dates.
    -- NULL window_forward_start_date follows simple maturity vs today_date rule; else calendar midpoint logic.
    effective_maturity AS (
        CASE
            WHEN window_forward_start_date IS NULL THEN
                CASE
                    WHEN maturity < today_date THEN today_date
                    ELSE maturity
                END
            ELSE
                dateadd(
                    day,
                    abs(
                        datediff(
                            day,
                            CASE
                                WHEN maturity < today_date THEN today_date
                                ELSE maturity
                            END,
                            CASE
                                WHEN window_forward_start_date < today_date THEN today_date
                                ELSE maturity
                            END
                        )
                    ) / 2,
                    CASE
                        WHEN (CASE WHEN maturity < today_date THEN today_date ELSE maturity END)
                             <= (CASE
                                     WHEN window_forward_start_date < today_date THEN today_date
                                     ELSE maturity
                                 END)
                        THEN (CASE WHEN maturity < today_date THEN today_date ELSE maturity END)
                        ELSE (CASE
                                  WHEN window_forward_start_date < today_date THEN today_date
                                  ELSE maturity
                              END)
                    END
                )
        END
    ) PERSISTED,

    -- Calendar days past maturity as of today_date; zero if not past; NULL if dates missing.
    days_excess_maturity AS (
        CASE
            WHEN maturity IS NULL OR today_date IS NULL THEN NULL
            WHEN datediff(day, maturity, today_date) > 0 THEN datediff(day, maturity, today_date)
            ELSE 0
        END
    ) PERSISTED,

    -- Annualized implied carry from futures vs initial FX over trade_date→maturity day count.
    -- NULL when inputs missing, initial_fx zero, or tenor days zero.
    actual_carry AS (
        CASE
            WHEN try_cast(futures_rate AS DECIMAL(19, 6)) IS NULL
                OR initial_fx IS NULL
                OR initial_fx = 0
                OR maturity IS NULL
                OR trade_date IS NULL
                OR datediff(day, trade_date, maturity) = 0
            THEN NULL
            ELSE (
                ((try_cast(futures_rate AS DECIMAL(19, 6)) / initial_fx) - 1.0)
                * 365.0
                / cast(datediff(day, trade_date, maturity) AS DECIMAL(19, 6))
            )
        END
    ) PERSISTED,

    -- SE fee accrued in USD: |client leg| × se_fee / 365 × days since trade_date to today_date.
    accrued_se_fee_usd AS (
        CASE
            WHEN currency_1 = N'USD' THEN
                abs(client_amt_currency_1) * se_fee / 365.0
                * cast(datediff(day, trade_date, today_date) AS DECIMAL(19, 6))
            ELSE
                abs(client_amt_currency_2) * se_fee / 365.0
                * cast(datediff(day, trade_date, today_date) AS DECIMAL(19, 6))
        END
    ) PERSISTED,

    -- Gross profit accrued in USD: |client leg| × announced_profit / 365 × days since trade_date.
    accrued_gross_profit_usd AS (
        CASE
            WHEN currency_1 = N'USD' THEN
                abs(client_amt_currency_1) * announced_profit / 365.0
                * cast(datediff(day, trade_date, today_date) AS DECIMAL(19, 6))
            ELSE
                abs(client_amt_currency_2) * announced_profit / 365.0
                * cast(datediff(day, trade_date, today_date) AS DECIMAL(19, 6))
        END
    ) PERSISTED,

    -- Net accrued P/L in USD: gross accrued profit minus accrued SE fee.
    accrued_net_pnl_usd AS (accrued_gross_profit_usd - accrued_se_fee_usd) PERSISTED
);
GO
