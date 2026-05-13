/*
  hedgeit_fut_hedge normalization (trade grain: one row = one trade for one client).

  PK strategy:
  - Clustered PK remains fut_hedge_id (IDENTITY) for stable row identity and persisted computeds.
  - Business uniqueness: UNIQUE (client_id, trade_id). trade_id may repeat across different
    clients; it is not assumed globally unique.

  Sequence (plan approach B):
  - Stored [sequence] removed as redundant with trade_id within a client (1:1 per business rules).
  - Derive display order in application or reporting queries with ROW_NUMBER() PARTITION BY client_id
    ORDER BY trade_date, trade_id, fut_hedge_id if needed.
*/

CREATE TABLE dbo.hedgeit_client (
    client_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    client_alias NVARCHAR(255) NOT NULL,
    client NVARCHAR(255) NULL, -- This seems to be unused think will remove
    CONSTRAINT UQ_hedgeit_client_client_alias UNIQUE (client_alias)
);
GO

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
    micro_replication_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    cash DECIMAL(19, 6) NULL,
    currency NVARCHAR(255) NULL,
    -- instrument_1..instrument_12: optional legs of the micro-replication basket; each references hedgeit_instrument when populated.
    instrument_1_id INT NULL,
    instrument_2_id INT NULL,
    instrument_3_id INT NULL,
    instrument_4_id INT NULL,
    instrument_5_id INT NULL,
    instrument_6_id INT NULL,
    instrument_7_id INT NULL,
    instrument_8_id INT NULL,
    instrument_9_id INT NULL,
    instrument_10_id INT NULL,
    instrument_11_id INT NULL,
    instrument_12_id INT NULL,
    -- position_1..position_12: WHAT IS THIS?
    position_2 INT NULL,
    position_3 INT NULL,
    position_4 INT NULL,
    position_5 INT NULL,
    position_6 INT NULL,
    position_7 INT NULL,
    position_8 INT NULL,
    position_9 INT NULL,
    position_10 INT NULL,
    position_11 INT NULL,
    position_12 INT NULL,

    CONSTRAINT FK_hedgeit_micro_replication_instrument_1 FOREIGN KEY (instrument_1_id) REFERENCES dbo.hedgeit_instrument (instrument_id),
    CONSTRAINT FK_hedgeit_micro_replication_instrument_2 FOREIGN KEY (instrument_2_id) REFERENCES dbo.hedgeit_instrument (instrument_id),
    CONSTRAINT FK_hedgeit_micro_replication_instrument_3 FOREIGN KEY (instrument_3_id) REFERENCES dbo.hedgeit_instrument (instrument_id),
    CONSTRAINT FK_hedgeit_micro_replication_instrument_4 FOREIGN KEY (instrument_4_id) REFERENCES dbo.hedgeit_instrument (instrument_id),
    CONSTRAINT FK_hedgeit_micro_replication_instrument_5 FOREIGN KEY (instrument_5_id) REFERENCES dbo.hedgeit_instrument (instrument_id),
    CONSTRAINT FK_hedgeit_micro_replication_instrument_6 FOREIGN KEY (instrument_6_id) REFERENCES dbo.hedgeit_instrument (instrument_id),
    CONSTRAINT FK_hedgeit_micro_replication_instrument_7 FOREIGN KEY (instrument_7_id) REFERENCES dbo.hedgeit_instrument (instrument_id),
    CONSTRAINT FK_hedgeit_micro_replication_instrument_8 FOREIGN KEY (instrument_8_id) REFERENCES dbo.hedgeit_instrument (instrument_id),
    CONSTRAINT FK_hedgeit_micro_replication_instrument_9 FOREIGN KEY (instrument_9_id) REFERENCES dbo.hedgeit_instrument (instrument_id),
    CONSTRAINT FK_hedgeit_micro_replication_instrument_10 FOREIGN KEY (instrument_10_id) REFERENCES dbo.hedgeit_instrument (instrument_id),
    CONSTRAINT FK_hedgeit_micro_replication_instrument_11 FOREIGN KEY (instrument_11_id) REFERENCES dbo.hedgeit_instrument (instrument_id),
    CONSTRAINT FK_hedgeit_micro_replication_instrument_12 FOREIGN KEY (instrument_12_id) REFERENCES dbo.hedgeit_instrument (instrument_id)
);
GO

CREATE TABLE dbo.hedgeit_fut_hedge (
    fut_hedge_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY, -- Surrogate primary key for this hedge trade row.
    trade_id NVARCHAR(255) NOT NULL, -- External or upstream trade identifier; unique per client_id.
    client_id INT NOT NULL, -- FK to hedgeit_client; replaces denormalized client_alias.
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
    margin_per_trade BIT NULL, -- TRUE if margin is tracked per trade rather than portfolio.
    spot_rate DECIMAL(19, 6) NULL, -- Spot FX for valuation (pair vs USD context).
    forward_rate DECIMAL(19, 6) NULL, -- Forward FX rate for valuation.
    micro_replication_id INT NULL, -- FK to hedgeit_micro_replication when this trade uses a micro-replication template.
    associated_trade_id NVARCHAR(255) NULL, -- Linked trade id when this row is part of a bundle.
    cross_strike DECIMAL(19, 6) NULL, -- Cross or secondary strike used in structure.
    commentaires NVARCHAR(255) NULL, -- Free-form notes on the trade.
    today_date DATE NULL, -- Valuation "as of" date driving time-based computed columns.
    sub_accounts_projects NVARCHAR(255) NULL, -- Sub-account or project tag for reporting.
    margin_currency NVARCHAR(255) NULL, -- ISO currency code for margin_amount.
    margin_amount DECIMAL(19, 6) NULL, -- Margin notional in margin_currency.

    CONSTRAINT FK_hedgeit_fut_hedge_hedgeit_client FOREIGN KEY (client_id) REFERENCES dbo.hedgeit_client (client_id),
    CONSTRAINT FK_hedgeit_fut_hedge_hedgeit_micro_replication FOREIGN KEY (micro_replication_id) REFERENCES dbo.hedgeit_micro_replication (micro_replication_id),
    CONSTRAINT UQ_hedgeit_fut_hedge_client_trade UNIQUE (client_id, trade_id),

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

CREATE NONCLUSTERED INDEX IX_hedgeit_fut_hedge_client_id ON dbo.hedgeit_fut_hedge (client_id); -- For quicker lookups by client.
GO

CREATE TABLE dbo.hedgeit_option_micro_replication (
    option_micro_replication_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY, -- Surrogate PK for the option micro-replication template row.
    currency_pair NVARCHAR(255), -- Six-character FX pair code (e.g. EURUSD); drives RIGHT(...,3) USD checks in computed columns.
    instrument_1_id INT NULL, --FK TO instrument
    instrument_2_id INT NULL, --FK to instrument
    maturity_1 DATE NULL, -- Maturity for replication leg 1.
    maturity_2 DATE NULL, -- Maturity for replication leg 2.
    strike_1 DECIMAL(19,6) NULL, -- Strike for leg 1.
    strike_2 DECIMAL(19,6) NULL, -- Strike for leg 2.
    position_option_1 DECIMAL(19,6) NULL, -- Position size or weight for leg 1.
    position_option_2 DECIMAL(19,6) NULL, -- Position size or weight for leg 2.
    notional_currency_1_1 DECIMAL(19,6) NULL, -- Notional in first currency of the pair for leg 1.
    notional_currency_1_2 DECIMAL(19,6) NULL, -- Notional in first currency of the pair for leg 2.
    initial_premium_unit_currency_2_1 DECIMAL(19,6) NULL, -- Initial premium per unit in second currency of the pair (leg 1).
    initial_premium_unit_currency_2_2 DECIMAL(19,6) NULL, -- Initial premium per unit in second currency of the pair (leg 2).
    mtm_currency_2_1 DECIMAL(19,6) NULL, -- Mark-to-market per unit in second currency for leg 1 (used in PnL formulas).
    mtm_currency_2_2 DECIMAL(19,6) NULL, -- Mark-to-market per unit in second currency for leg 2 (used in PnL formulas).
    spot_rate DECIMAL(19,6) NULL, -- Spot FX for converting leg-2 amounts to USD when the pair second currency is not USD.

    CONSTRAINT FK_hedgeit_micro_replication_instrument_1 FOREIGN KEY (instrument_1_id) REFERENCES dbo.hedgeit_instrument (instrument_id),
    CONSTRAINT FK_hedgeit_micro_replication_instrument_2 FOREIGN KEY (instrument_2_id) REFERENCES dbo.hedgeit_instrument (instrument_id),

    -- Leg 1: total initial premium in USD (Access IIf on USD in second leg of pair vs divide by spot_rate).
    initial_premium_total_usd_1 AS (
        CAST(
            CASE
                WHEN RIGHT(currency_pair, 3) = N'USD' THEN
                    notional_currency_1_1 * initial_premium_unit_currency_2_1
                ELSE
                    notional_currency_1_1 * initial_premium_unit_currency_2_1 / NULLIF(spot_rate, 0)
            END
        AS DECIMAL(19, 6))
    ) PERSISTED,
    -- Leg 1: total MTM in second currency of the pair (notional × per-unit MTM in currency 2).
    mtm_total_currency_2_1 AS (
        CAST(notional_currency_1_1 * mtm_currency_2_1 AS DECIMAL(19, 6))
    ) PERSISTED,
    -- Leg 1: total MTM expressed in USD (Access: USD second leg uses total ccy2; else divide by spot_rate).
    mtm_usd_1 AS (
        CAST(
            CASE
                WHEN RIGHT(currency_pair, 3) = N'USD' THEN mtm_total_currency_2_1
                ELSE mtm_total_currency_2_1 / NULLIF(spot_rate, 0)
            END
        AS DECIMAL(19, 6))
    ) PERSISTED,
    -- Leg 1: P/L in USD vs initial premium total (Access uses per-unit MTM in ccy2, not total MTM ccy2).
    pnl_usd_1 AS (
        CAST(
            CASE
                WHEN RIGHT(currency_pair, 3) = N'USD' THEN
                    mtm_currency_2_1 - initial_premium_total_usd_1
                ELSE
                    mtm_currency_2_1 / NULLIF(spot_rate, 0) - initial_premium_total_usd_1
            END
        AS DECIMAL(19, 6))
    ) PERSISTED,

    -- Leg 2: total initial premium in USD (same pattern as leg 1).
    initial_premium_total_usd_2 AS (
        CAST(
            CASE
                WHEN RIGHT(currency_pair, 3) = N'USD' THEN
                    notional_currency_1_2 * initial_premium_unit_currency_2_2
                ELSE
                    notional_currency_1_2 * initial_premium_unit_currency_2_2 / NULLIF(spot_rate, 0)
            END
        AS DECIMAL(19, 6))
    ) PERSISTED,
    -- Leg 2: total MTM in second currency of the pair.
    mtm_total_currency_2_2 AS (
        CAST(mtm_currency_2_2 * notional_currency_1_2 AS DECIMAL(19, 6))
    ) PERSISTED,
    -- Leg 2: total MTM in USD.
    mtm_usd_2 AS (
        CAST(
            CASE
                WHEN RIGHT(currency_pair, 3) = N'USD' THEN mtm_total_currency_2_2
                ELSE mtm_total_currency_2_2 / NULLIF(spot_rate, 0)
            END
        AS DECIMAL(19, 6))
    ) PERSISTED,
    -- Leg 2: P/L in USD vs initial premium total.
    pnl_usd_2 AS (
        CAST(
            CASE
                WHEN RIGHT(currency_pair, 3) = N'USD' THEN
                    mtm_currency_2_2 - initial_premium_total_usd_2
                ELSE
                    mtm_currency_2_2 / NULLIF(spot_rate, 0) - initial_premium_total_usd_2
            END
        AS DECIMAL(19, 6))
    ) PERSISTED
);
GO

/*
  hedgeit_opt_hedge (option hedge trade grain: one row per trade per client).

  PK: opt_hedge_id (IDENTITY). Business uniqueness: UNIQUE (client_id, trade_id).
  trade_id is unique per client; sequence is not stored—derive display order with
  ROW_NUMBER() OVER (PARTITION BY client_id ORDER BY trade_date, trade_id, opt_hedge_id)
  when trade_date exists, else ORDER BY trade_id, opt_hedge_id.
*/
CREATE TABLE dbo.hedgeit_opt_hedge (
    opt_hedge_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY, -- Surrogate primary key for the option hedge row.
    trade_id NVARCHAR(255) NOT NULL, -- External or upstream trade identifier; unique per client_id.
    client_id INT NOT NULL, -- FK to hedgeit_client; replaces denormalized client_alias.
    trade_status NVARCHAR(255) NULL, -- Workflow status of the hedge/trade.
    client_ref NVARCHAR(255) NULL, -- Client reference, ticket, or deal id.
    currency_pair NVARCHAR(255) NULL, -- Six-letter FX pair code (e.g. EURUSD).
    [type] NVARCHAR(255) NULL, -- Trade classification (e.g. hedge vs other).
    strategy NVARCHAR(255) NULL, -- Strategy or book classification for the option trade.
    instrument_currency NVARCHAR(255) NULL, -- Currency the instrument is quoted in.
    hedged_currency NVARCHAR(255) NULL, -- Currency exposure being hedged.
    trade_date DATE NULL, -- Trade execution or booking date.
    maturity DATE NULL, -- Contract or hedge maturity date.
    conversion_date DATE NULL, -- Conversion or cash-flow date when applicable.
    hedged_amount_formula NVARCHAR(255) NULL, -- Text formula for hedged notional (display/audit).
    hedged_amount DECIMAL(19, 6) NULL, -- Hedged notional amount in hedged_currency.
    client_strike DECIMAL(19, 6) NULL, -- Client strike or contractual conversion rate.
    initial_fx DECIMAL(19, 6) NULL, -- Spot or deal FX rate at inception.
    barriar INT NULL, --DO WE USE THIS, SHOULD IT BE INT
    underlying_fut_maturity DATE NULL, --maturity date of underlying future
    implied_volatility DECIMAL(19, 6) NULL, -- Implied volatility input for pricing.
    se_initial_marginal DECIMAL(19, 6) NULL, -- Initial margin (SE).
    se_maintenance_margin DECIMAL(19, 6) NULL, -- Maintenance margin requirement (SE).
    roll_pnl DECIMAL(19,6) NULL, -- P/L from rolls or similar adjustments.
    se_fee DECIMAL(19,6) NULL, -- Service-entity fee rate used in accruals (annualized basis in formulas).
    se_formula NVARCHAR(255) NULL, -- Text description or formula for the SE fee.
    spot_rate DECIMAL(19,6) NULL, -- Spot FX for valuation.
    forward_rate DECIMAL(19,6) NULL, -- Forward FX for valuation and intrinsic-style calculations.
    mtm_USD DECIMAL(19,6) NULL, -- Mark-to-market in USD.
    pnl_usd DECIMAL(19,6) NULL, -- Profit and loss in USD.
    option_micro_replication_id INT NULL, -- FK to dbo.option_micro_replication when this trade uses an option micro-replication template.
    associated_trade_id NVARCHAR(255) NULL, -- Linked trade id when bundled with another trade.
    commentaires NVARCHAR(255) NULL, -- Free-form notes (legacy column name).
    today_date DATE NULL, --is this the date when this row/trade is inserted

    CONSTRAINT FK_hedgeit_opt_hedge_hedgeit_client FOREIGN KEY (client_id) REFERENCES dbo.hedgeit_client (client_id),
    CONSTRAINT FK_hedgeit_opt_hedge_option_micro_replication FOREIGN KEY (option_micro_replication_id) REFERENCES dbo.hedgeit_option_micro_replication (option_micro_replication_id),
    CONSTRAINT UQ_hedgeit_opt_hedge_client_trade UNIQUE (client_id, trade_id),

    -- First leg of the pair: left three characters of currency_pair.
    currency_1 AS (LEFT(currency_pair, 3)) PERSISTED,
    -- Second leg of the pair: right three characters of currency_pair.
    currency_2 AS (RIGHT(currency_pair, 3)) PERSISTED,

    -- Client notional in currency_1: hedged amount or amount implied via client_strike (legacy Access ClientAmtCurrency1).
    client_amt_currency_1 AS (
        CASE
            WHEN LEFT(currency_pair, 3) = hedged_currency THEN hedged_amount
            WHEN client_strike = 0 THEN 0
            ELSE ROUND(-(hedged_amount / client_strike), 0)
        END
    ) PERSISTED,
    -- Client notional in currency_2: hedged amount or amount implied via client_strike (legacy Access ClientAmtCurrency2).
    client_amt_currency_2 AS (
        CASE
            WHEN RIGHT(currency_pair, 3) = hedged_currency THEN hedged_amount
            WHEN client_strike = 0 THEN 0
            ELSE ROUND(-(hedged_amount * client_strike), 0)
        END
    ) PERSISTED,

    -- Text mirror: hedged_amount_formula when this leg is hedged_currency; else string form of client notional (Access Str$).
    client_amt_currency_1_formula AS (
        CASE
            WHEN currency_1 = hedged_currency THEN hedged_amount_formula
            ELSE CAST(client_amt_currency_1 AS NVARCHAR(50))
        END
    ) PERSISTED,
    client_amt_currency_2_formula AS (
        CASE
            WHEN currency_2 = hedged_currency THEN hedged_amount_formula
            ELSE CAST(client_amt_currency_2 AS NVARCHAR(50))
        END
    ) PERSISTED,

    -- SE fee accrued daily from trade_date to today_date on the USD leg amount vs the other leg (legacy Access accrued_se_fee).
    accrued_se_fee AS (
        CASE
            WHEN currency_1 = N'USD' THEN
                client_amt_currency_1 * se_fee / 365.0
                * CAST(DATEDIFF(day, trade_date, today_date) AS DECIMAL(19, 6))
            ELSE
                client_amt_currency_2 * se_fee / 365.0
                * CAST(DATEDIFF(day, trade_date, today_date) AS DECIMAL(19, 6))
        END
    ) PERSISTED,

    -- Option intrinsic in USD: CALL/PUT branch on forward vs strike, scaled by spot when currency_1 is USD (legacy Access intrinsic_value_usd).
    intrinsic_value_usd AS (
        (
            CASE
                WHEN UPPER(LTRIM(RTRIM([type]))) = N'CALL' THEN
                    CASE
                        WHEN forward_rate - client_strike > 0 THEN forward_rate - client_strike
                        ELSE CAST(0 AS DECIMAL(19, 6))
                    END * client_amt_currency_1
                ELSE
                    CASE
                        WHEN client_strike - forward_rate > 0 THEN client_strike - forward_rate
                        ELSE CAST(0 AS DECIMAL(19, 6))
                    END * client_amt_currency_1
            END
        )
        / NULLIF(CASE WHEN currency_1 = N'USD' THEN spot_rate ELSE CAST(1 AS DECIMAL(19, 6)) END, 0)
    ) PERSISTED
);
GO

CREATE NONCLUSTERED INDEX IX_hedgeit_opt_hedge_client_id ON dbo.hedgeit_opt_hedge (client_id);
GO

CREATE TABLE dbo.hedgeit_deposit_micro_replication (
    deposit_micro_replication_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY, -- Surrogate primary key for this deposit_micro_replication trade row.
    deposit_currency NVARCHAR(255) NOT NULL,
    cash_eur DECIMAL(19,6) NULL,
    cash_chf DECIMAL(19,6) NULL,
    cash_jpy DECIMAL(19,6) NULL,
    cash_usd DECIMAL(19,6) NULL,
    cash_dkk DECIMAL(19,6) NULL,
    cash_hkd DECIMAL(19,6) NULL,
    cash_aud DECIMAL(19,6) NULL,
    cash_cad DECIMAL(19,6) NULL,
    cash_sgd DECIMAL(19,6) NULL,
    cash_gpb DECIMAL(19,6) NULL,
    cash_cnh DECIMAL(19,6) NULL,
    cash_eur_jpy_fut DECIMAL(19,6) NULL,
    cash_gbp_jpy_fut DECIMAL(19,6) NULL,
    t_bills DECIMAL(19,6) NULL,
    t_bills_eur DECIMAL(19,6) NULL,
    usd_cnh_hedge NVARCHAR(255) NULL,
    eur_usd_hedge NVARCHAR(255) NULL,
    chf_usd_hedge NVARCHAR(255) NULL,
    jpy_usd_hedge NVARCHAR(255) NULL,
    gbp_usd_hedge NVARCHAR(255) NULL,
    usd_sgd_hedge NVARCHAR(255) NULL,
    aud_usd_hedge NVARCHAR(255) NULL,
    cad_usd_hedge NVARCHAR(255) NULL,
    eur_jpy_hedge NVARCHAR(255) NULL,
    gbp_jpy_hedge NVARCHAR(255) NULL,
    sum_real_accrued_in_currency DECIMAL(19,6) NULL,
    cash_eur_formula NVARCHAR(255) NULL,
    cash_chf_formula NVARCHAR(255) NULL,
    cash_jpy_formula NVARCHAR(255) NULL,
    cash_usd_formula NVARCHAR(255) NULL,
    cash_dkk_formula NVARCHAR(255) NULL,
    cash_hkd_formula NVARCHAR(255) NULL,
    cash_aud_formula NVARCHAR(255) NULL,
    cash_cad_formula NVARCHAR(255) NULL,
    cash_sgd_formula NVARCHAR(255) NULL,
    cash_gbp_formula NVARCHAR(255) NULL,
    cash_cnh_formula NVARCHAR(255) NULL,
    cash_eur_jpy_fut_formula NVARCHAR(255) NULL,
    cash_gbp_jpy_fut_formula NVARCHAR(255) NULL,
    t_bills_formula NVARCHAR(255) NULL,
    t_bills_eur_formula NVARCHAR(255)

);
GO

CREATE TABLE dbo.hedgeit_deposit (
    deposit_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY, -- Surrogate primary key for this deposit trade row.
    trade_id NVARCHAR(255) NOT NULL, -- External or upstream trade identifier; unique per client_id.
    client_id INT NOT NULL, -- FK to hedgeit_client; replaces denormalized client_alias.
    client_ref NVARCHAR(255) NULL, -- Client reference, ticket, or deal id.
    trade_status NVARCHAR(255) NULL, -- Workflow status of the hedge/trade.
    [type] NVARCHAR(255) NULL, -- Trade classification (e.g. hedge vs other).
    deposit_currency NVARCHAR(255) NULL,
    date_of_deposit DATE NULL,
    [start_date] DATE NULL, -- Accrual period start (Access StartDate).
    maturity DATE NULL, -- Deposit or accrual maturity date (Access Maturity).
    actual_end_date DATE NULL,
    deposit_value_formula NVARCHAR(255),
    deposit_value DECIMAL(19,6), -- Deposit principal or notional for accrual (Access DepositValue).
    return_currency NVARCHAR(255),
    margin_rate DECIMAL(19,6),
    initial_fx DECIMAL(19,6),
    return_ammount DECIMAL(19,6),
    announced_interest DECIMAL(19,6),  -- Announced interest rate for client accrual (Access AnnouncedInterest).
    locked_interest DECIMAL(19,6),  -- Locked interest rate for cash-deposit accrual (Access LockedInterest).
    se_fee DECIMAL(19,6), -- Service-entity fee rate for SE accrual (Access SEFee).
    real_accrued_in_currency DECIMAL(19,6), -- Real accrued amount in deposit currency before scaling by principal (Access RealAccruedinCurrency).
    deposit_micro_replication DECIMAL(19,6),
    interest_paid DECIMAL(19,6),
    comments NVARCHAR(255),
    today_date DATE, -- Valuation or reporting as-of date (Access TodayDate).
    sub_accounts_project NVARCHAR(255),

    CONSTRAINT FK_hedgeit_deposit_client FOREIGN KEY (client_id) REFERENCES dbo.hedgeit_client (client_id),
    CONSTRAINT FK_hedgeit_deposit_micro_replication FOREIGN KEY (deposit_micro_replication_id) REFERENCES dbo.hedgeit_deposit_micro_replication (option_micro_replication_id),
    CONSTRAINT UQ_hedgeit_opt_hedge_client_trade UNIQUE (client_id, trade_id),

    -- Announced interest accrued in deposit currency: value × announced rate / 365 × days from start to min(maturity, today) when maturity in future else maturity (legacy Access announced_accrued_in_currency).
    announced_accrued_in_currency AS (
        CAST(
            deposit_value * announced_interest / 365.0
            * CAST(
                DATEDIFF(
                    day,
                    start_date,
                    CASE
                        WHEN maturity > today_date THEN today_date
                        ELSE maturity
                    END
                ) AS DECIMAL(19, 6)
            )
        AS DECIMAL(19, 6))
    ) PERSISTED,

    -- SE fee accrued: value × SE fee / 365 × days from start to min(maturity, today) when maturity passed else today (legacy Access accrued_se_fee).
    accrued_se_fee AS (
        CAST(
            deposit_value * se_fee / 365.0
            * CAST(
                DATEDIFF(
                    day,
                    start_date,
                    CASE
                        WHEN maturity < today_date THEN maturity
                        ELSE today_date
                    END
                ) AS DECIMAL(19, 6)
            )
        AS DECIMAL(19, 6))
    ) PERSISTED,

    -- Locked-rate accrual for Cash Deposit type only; else zero (legacy Access accrued_locked).
    accrued_locked AS (
        CAST(
            CASE
                WHEN lower(ltrim(rtrim([type]))) = N'cash deposit' THEN
                    deposit_value * locked_interest / 365.0
                    * CAST(
                        DATEDIFF(
                            day,
                            start_date,
                            CASE
                                WHEN maturity > today_date THEN today_date
                                ELSE maturity
                            END
                        ) AS DECIMAL(19, 6)
                    )
                ELSE CAST(0 AS DECIMAL(19, 6))
            END
        AS DECIMAL(19, 6))
    ) PERSISTED,

    -- Real accrued as ratio of real accrued in currency to principal (legacy Access real_accrued).
    real_accrued AS (
        CAST(real_accrued_in_currency / NULLIF(deposit_value, 0) AS DECIMAL(19, 6))
    ) PERSISTED
);
GO