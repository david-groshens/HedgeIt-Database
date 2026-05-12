CREATE TABLE dbo.fut_hedge (
    id INT IDENTITY(1,1) PRIMARY KEY,
    trade_id nvarchar(255) NULL,
    [sequence] int NULL, --IDENTITY(1,1)
    client nvarchar(255) NULL, --not used keep for now
    client_alias nvarchar(255) NULL,
    trade_status nvarchar(255) NULL,
    client_ref nvarchar(255) NULL,
    [type] nvarchar(255) NULL,
    currency_pair nvarchar(255) NULL,
    instrument_currency nvarchar(255) NULL,
    hedged_currency nvarchar(255) NULL,
    trade_date DATE NULL,
    window_forward_start_date DATE NULL,
    maturity DATE NULL,
    conversion_date DATE NULL,
    hedged_amount_formula nvarchar(255) NULL,
    hedged_amount float NULL,
    client_strike float NULL,
    initial_fx float NULL,
    futures_maturity date NULL,
    futures_rate nvarchar(255) NULL,
    roll_spreads nvarchar(255) NULL,
    se_initial_margin float NULL,
    se_maintenance_margin float NULL,
    se_fee float NULL,
    se_fee_formula nvarchar(255) NULL,
    se_fee_embedded float NULL,
    announced_profit float NULL,
    margin_per_trade BIT,
    spot_rate float NULL,
    forward_rate float NULL,
    micro_replication int NULL,
    associated_trade_id nvarchar(255) NULL,
    cross_strike float NULL,
    commentaires nvarchar(255) NULL, --do we more precision
    today_date date NULL,
    sub_accounts_projects nvarchar(255) NULL,
    margin_currency NVARCHAR(255),
    margin_amount FLOAT NULL,


    currency_1 AS (LEFT(currency_pair, 3)) PERSISTED,
    currency_2 AS (RIGHT(currency_pair, 3)) PERSISTED,

--added
    client_amt_currency_1_formula AS (
        CASE
            WHEN LEFT(currency_pair, 3) = hedged_currency THEN hedged_amount_formula
            WHEN client_strike = 0 THEN '0'
            ELSE STR(ROUND(-((1 * hedged_amount) / client_strike), 0))
        END
    ) PERSISTED,
    client_amt_currency_2_formula AS (
        CASE
            WHEN RIGHT(currency_pair, 3) = hedged_currency THEN hedged_amount_formula
            WHEN client_strike = 0 THEN '0'
            ELSE STR(ROUND(-((1 * hedged_amount) * client_strike), 0))
        END
    ) PERSISTED,
    client_amt_currency_1 AS (
        CASE
            WHEN LEFT(currency_pair, 3) = hedged_currency THEN hedged_amount
            WHEN client_strike = 0 THEN 0
            ELSE ROUND(-((1 * hedged_amount) / client_strike), 0)
        END
    ) PERSISTED,
    client_amt_currency_2 AS (
        CASE
            WHEN RIGHT(currency_pair, 3) = hedged_currency THEN hedged_amount
            WHEN client_strike = 0 THEN 0
            ELSE ROUND(-((1 * hedged_amount) * client_strike), 0)
        END
    ) PERSISTED,

    -- IIf([Currency1]=[HedgedCurrency],[HedgedAmount],IIf([Type]="Hedge",-[HedgedAmount]/[FuturesRate],-[HedgedAmount]/[InitialFX]))
    h_amt_currency_1 AS (
        CASE
            WHEN currency_1 = hedged_currency THEN hedged_amount
            WHEN lower(rtrim(ltrim([type]))) = N'hedge' THEN
                -hedged_amount / nullif(try_cast(futures_rate AS float), 0)
            ELSE
                -hedged_amount / nullif(initial_fx, 0)
        END
    ) PERSISTED,

    -- IIf([Currency2]=[HedgedCurrency],[HedgedAmount],-[HedgedAmount]*[FuturesRate])
    h_amt_currency_2 AS (
        CASE
            WHEN currency_2 = hedged_currency THEN hedged_amount
            ELSE -hedged_amount * try_cast(futures_rate AS float)
        END
    ) PERSISTED,

    -- IIf([Currency1]=[InstrumentCurrency],-[ClientAmtCurrency1]*[ForwardRate],-[ClientAmtCurrency1]*[ForwardRate]/[SpotRate])
    valuation_non_instrument_cur AS (
        CASE
            WHEN currency_1 = instrument_currency THEN
                -client_amt_currency_1 * forward_rate
            ELSE
                -client_amt_currency_1 * forward_rate / nullif(spot_rate, 0)
        END
    ) PERSISTED,

    -- IIf([Currency1]='USD',([ForwardRate]-[FuturesRate])*[H_AmtCurrency1],([ForwardRate]-[FuturesRate])*[H_AmtCurrency2])
    forward_pl_currency_2 AS (
        CASE
            WHEN currency_1 = N'USD' THEN
                (forward_rate - try_cast(futures_rate AS float)) * h_amt_currency_1
            ELSE
                (forward_rate - try_cast(futures_rate AS float)) * h_amt_currency_2
        END
    ) PERSISTED,

    -- IIf([SpotRate]=0,0,[ForwardPLCurrency2]/[SpotRate])  (Access ForwardPLCurrency1)
    forward_pl_currency_1 AS (
        CASE
            WHEN spot_rate = 0 THEN 0
            ELSE forward_pl_currency_2 / nullif(spot_rate, 0)
        END
    ) PERSISTED,

    -- IIf([Currency1]='USD',[ForwardPLCurrency2]-([SpotRate]-[InitialFX])*[H_AmtCurrency1],[ForwardPLCurrency2]-([SpotRate]-[InitialFX])*[H_AmtCurrency2])
    cumulated_carry_currency_2 AS (
        CASE
            WHEN currency_1 = N'USD' THEN
                forward_pl_currency_2 - (spot_rate - initial_fx) * h_amt_currency_1
            ELSE
                forward_pl_currency_2 - (spot_rate - initial_fx) * h_amt_currency_2
        END
    ) PERSISTED,

    -- IIf([Currency1]='USD',([InitialFX]-[FuturesRate])*[H_AmtCurrency1],([InitialFX]-[FuturesRate])*[H_AmtCurrency2])
    total_carry_currency_2 AS (
        CASE
            WHEN currency_1 = N'USD' THEN
                (initial_fx - try_cast(futures_rate AS float)) * h_amt_currency_1
            ELSE
                (initial_fx - try_cast(futures_rate AS float)) * h_amt_currency_2
        END
    ) PERSISTED,

    -- IIf([WindowForwardStartDate]="",IIf([Maturity]<[TodayDate],[TodayDate],[Maturity]),(IIf(...)+IIf(...))/2)
    -- Empty window in Access maps to NULL for DATE; midpoint uses calendar-day midpoint between the two branch dates.
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

    -- IIf([TodayDate]-[Maturity]>0,[TodayDate]-[Maturity],0)
    days_excess_maturity AS (
        CASE
            WHEN maturity IS NULL OR today_date IS NULL THEN NULL
            WHEN datediff(day, maturity, today_date) > 0 THEN datediff(day, maturity, today_date)
            ELSE 0
        END
    ) PERSISTED,

    -- (([FuturesRate]/[InitialFX])-1)*365/([Maturity]-[TradeDate])
    actual_carry AS (
        CASE
            WHEN try_cast(futures_rate AS float) IS NULL
                OR initial_fx IS NULL
                OR initial_fx = 0
                OR maturity IS NULL
                OR trade_date IS NULL
                OR datediff(day, trade_date, maturity) = 0
            THEN NULL
            ELSE (
                ((try_cast(futures_rate AS float) / initial_fx) - 1.0)
                * 365.0
                / cast(datediff(day, trade_date, maturity) AS float)
            )
        END
    ) PERSISTED,

    -- IIf([Currency1]='USD', Abs([ClientAmtCurrency1])*[SEFee]/365*([TodayDate]-[TradeDate]), ...)
    accrued_se_fee_usd AS (
        CASE
            WHEN currency_1 = N'USD' THEN
                abs(client_amt_currency_1) * se_fee / 365.0
                * cast(datediff(day, trade_date, today_date) AS float)
            ELSE
                abs(client_amt_currency_2) * se_fee / 365.0
                * cast(datediff(day, trade_date, today_date) AS float)
        END
    ) PERSISTED,

    -- IIf([Currency1]='USD', Abs([ClientAmtCurrency1])*[AnnouncedProfit]/365*([TodayDate]-[TradeDate]), ...)
    accrued_gross_profit_usd AS (
        CASE
            WHEN currency_1 = N'USD' THEN
                abs(client_amt_currency_1) * announced_profit / 365.0
                * cast(datediff(day, trade_date, today_date) AS float)
            ELSE
                abs(client_amt_currency_2) * announced_profit / 365.0
                * cast(datediff(day, trade_date, today_date) AS float)
        END
    ) PERSISTED,

    -- [AccruedGrossProfitUSD]-[AccruedSEFeeUSD]
    accrued_net_pnl_usd AS (accrued_gross_profit_usd - accrued_se_fee_usd) PERSISTED
);
GO
