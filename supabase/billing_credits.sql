-- ============================================================
--  AI WORKSPACE — BILLING & CREDIT SYSTEM
--  File 3 of 3 — run after model_registry_seed.sql
--
--  Sections:
--    1.  Enums
--    2.  Plans & Credit Packages
--    3.  Workspace Credit Ledger
--    4.  Variable Pricing Rules
--    5.  Subscriptions
--    6.  Payments
--    7.  Credit Transactions (partitioned)
--    8.  Usage Analytics
--    9.  Indexes
--    10. Functions & Triggers
--    11. Views
--    12. Seed Data
-- ============================================================


-- ============================================================
-- 1. ENUMS
-- ============================================================

CREATE TYPE billing_interval    AS ENUM ('monthly','annual');
CREATE TYPE subscription_status AS ENUM ('active','past_due','cancelled','paused','trialing','expired');
CREATE TYPE transaction_type    AS ENUM ('purchase','usage','refund','bonus','expiry','transfer','adjustment');
CREATE TYPE payment_status      AS ENUM ('pending','succeeded','failed','refunded','disputed');
CREATE TYPE payment_provider    AS ENUM ('stripe','paypal','crypto','manual');
CREATE TYPE pricing_strategy    AS ENUM ('flat','per_second','per_megapixel','per_frame','tiered','formula');


-- ============================================================
-- 2. PLANS & CREDIT PACKAGES
-- ============================================================

CREATE TABLE plans (
    id                  UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                VARCHAR(50)   UNIQUE NOT NULL,
    display_name        VARCHAR(100)  NOT NULL,
    description         TEXT,
    price_monthly_usd   NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    price_annual_usd    NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    annual_saving_pct   NUMERIC(5,2)  GENERATED ALWAYS AS (
                            CASE WHEN price_monthly_usd > 0
                            THEN ROUND((1 - (price_annual_usd / (price_monthly_usd * 12))) * 100, 2)
                            ELSE 0 END
                        ) STORED,
    credits_per_cycle   INTEGER       NOT NULL DEFAULT 0,
    credit_value_usd    NUMERIC(8,6)  NOT NULL DEFAULT 0.010000,
    max_workspaces      INTEGER       NOT NULL DEFAULT 1,
    max_members         INTEGER       NOT NULL DEFAULT 1,
    max_canvases        INTEGER       NOT NULL DEFAULT 5,
    max_storage_gb      INTEGER       NOT NULL DEFAULT 5,
    max_executions_day  INTEGER       NOT NULL DEFAULT 50,
    features            JSONB         NOT NULL DEFAULT '{}',
    is_active           BOOLEAN       NOT NULL DEFAULT TRUE,
    sort_order          INTEGER       NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE credit_packages (
    id               UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    name             VARCHAR(100)  NOT NULL,
    credits          INTEGER       NOT NULL,
    price_usd        NUMERIC(10,2) NOT NULL,
    bonus_credits    INTEGER       NOT NULL DEFAULT 0,
    total_credits    INTEGER       GENERATED ALWAYS AS (credits + bonus_credits) STORED,
    price_per_credit NUMERIC(8,6)  GENERATED ALWAYS AS (
                         CASE WHEN (credits + bonus_credits) > 0
                         THEN price_usd / (credits + bonus_credits)
                         ELSE 0 END
                     ) STORED,
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
    valid_from       TIMESTAMPTZ,
    valid_until      TIMESTAMPTZ,
    sort_order       INTEGER       NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 3. WORKSPACE CREDIT LEDGER
-- ============================================================

CREATE TABLE workspace_credits (
    workspace_id            UUID        PRIMARY KEY REFERENCES workspaces(id) ON DELETE CASCADE,
    balance                 INTEGER     NOT NULL DEFAULT 0 CHECK (balance >= 0),
    lifetime_purchased      INTEGER     NOT NULL DEFAULT 0,
    lifetime_used           INTEGER     NOT NULL DEFAULT 0,
    lifetime_refunded       INTEGER     NOT NULL DEFAULT 0,
    lifetime_bonus          INTEGER     NOT NULL DEFAULT 0,
    cycle_credits_included  INTEGER     NOT NULL DEFAULT 0,
    cycle_credits_used      INTEGER     NOT NULL DEFAULT 0,
    cycle_reset_at          TIMESTAMPTZ,
    low_balance_threshold   INTEGER     NOT NULL DEFAULT 100,
    low_balance_alerted_at  TIMESTAMPTZ,
    auto_topup_enabled      BOOLEAN     NOT NULL DEFAULT FALSE,
    auto_topup_threshold    INTEGER     NOT NULL DEFAULT 50,
    auto_topup_package_id   UUID        REFERENCES credit_packages(id),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 4. VARIABLE PRICING RULES
-- ============================================================

CREATE TABLE model_pricing_rules (
    id                     UUID             PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_id               UUID             NOT NULL REFERENCES ai_models(id) ON DELETE CASCADE,
    strategy               pricing_strategy NOT NULL DEFAULT 'flat',
    parameter_name         VARCHAR(50),
    flat_credits           INTEGER,
    credits_per_unit       NUMERIC(8,4),
    formula                TEXT,
    tiers                  JSONB,
    resolution_multipliers JSONB,
    duration_multipliers   JSONB,
    is_active              BOOLEAN          NOT NULL DEFAULT TRUE,
    effective_from         TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    effective_until        TIMESTAMPTZ,
    created_at             TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    UNIQUE (model_id, effective_from)
);


-- ============================================================
-- 5. SUBSCRIPTIONS
-- ============================================================

CREATE TABLE subscriptions (
    id                       UUID                PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id             UUID                NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    plan_id                  UUID                NOT NULL REFERENCES plans(id),
    status                   subscription_status NOT NULL DEFAULT 'trialing',
    interval                 billing_interval    NOT NULL DEFAULT 'monthly',
    trial_ends_at            TIMESTAMPTZ,
    current_period_start     TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    current_period_end       TIMESTAMPTZ         NOT NULL,
    cancelled_at             TIMESTAMPTZ,
    cancel_at_period_end     BOOLEAN             NOT NULL DEFAULT FALSE,
    ended_at                 TIMESTAMPTZ,
    payment_provider         payment_provider    NOT NULL DEFAULT 'stripe',
    external_subscription_id VARCHAR(200),
    external_customer_id     VARCHAR(200),
    price_usd                NUMERIC(10,2)       NOT NULL,
    credits_per_cycle        INTEGER             NOT NULL,
    metadata                 JSONB               NOT NULL DEFAULT '{}',
    created_at               TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 6. PAYMENTS
-- ============================================================

CREATE TABLE payments (
    id                    UUID             PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id          UUID             NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    subscription_id       UUID             REFERENCES subscriptions(id) ON DELETE SET NULL,
    credit_package_id     UUID             REFERENCES credit_packages(id) ON DELETE SET NULL,
    amount_usd            NUMERIC(10,2)    NOT NULL,
    credits_granted       INTEGER          NOT NULL DEFAULT 0,
    bonus_credits_granted INTEGER          NOT NULL DEFAULT 0,
    status                payment_status   NOT NULL DEFAULT 'pending',
    payment_provider      payment_provider NOT NULL DEFAULT 'stripe',
    external_payment_id   VARCHAR(200),
    external_invoice_id   VARCHAR(200),
    receipt_url           TEXT,
    failure_code          VARCHAR(100),
    failure_message       TEXT,
    retry_count           INTEGER          NOT NULL DEFAULT 0,
    refunded_amount_usd   NUMERIC(10,2),
    refunded_at           TIMESTAMPTZ,
    refund_reason         TEXT,
    metadata              JSONB            NOT NULL DEFAULT '{}',
    paid_at               TIMESTAMPTZ,
    created_at            TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 7. CREDIT TRANSACTIONS (partitioned)
-- ============================================================

CREATE TABLE credit_transactions (
    id                   UUID             NOT NULL DEFAULT uuid_generate_v4(),
    created_at           TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    workspace_id         UUID             NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    user_id              UUID             REFERENCES users(id) ON DELETE SET NULL,
    type                 transaction_type NOT NULL,
    amount               INTEGER          NOT NULL,
    balance_after        INTEGER          NOT NULL,
    description          TEXT,
    payment_id           UUID             REFERENCES payments(id) ON DELETE SET NULL,
    execution_id         UUID,
    execution_created_at TIMESTAMPTZ,
    node_execution_id    UUID             REFERENCES node_executions(id) ON DELETE SET NULL,
    model_id             UUID             REFERENCES ai_models(id) ON DELETE SET NULL,
    model_name           VARCHAR(100),
    base_credits         INTEGER,
    duration_seconds     NUMERIC(6,2),
    resolution           VARCHAR(20),
    width                INTEGER,
    height               INTEGER,
    steps                INTEGER,
    pricing_rule_id      UUID             REFERENCES model_pricing_rules(id) ON DELETE SET NULL,
    expires_at           TIMESTAMPTZ,
    metadata             JSONB            NOT NULL DEFAULT '{}',
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Monthly partitions 2025–2026
CREATE TABLE credit_transactions_2025_01 PARTITION OF credit_transactions FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE credit_transactions_2025_02 PARTITION OF credit_transactions FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE credit_transactions_2025_03 PARTITION OF credit_transactions FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE credit_transactions_2025_04 PARTITION OF credit_transactions FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE credit_transactions_2025_05 PARTITION OF credit_transactions FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE credit_transactions_2025_06 PARTITION OF credit_transactions FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE credit_transactions_2025_07 PARTITION OF credit_transactions FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE credit_transactions_2025_08 PARTITION OF credit_transactions FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE credit_transactions_2025_09 PARTITION OF credit_transactions FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE credit_transactions_2025_10 PARTITION OF credit_transactions FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE credit_transactions_2025_11 PARTITION OF credit_transactions FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE credit_transactions_2025_12 PARTITION OF credit_transactions FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE credit_transactions_2026_01 PARTITION OF credit_transactions FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE credit_transactions_2026_02 PARTITION OF credit_transactions FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE credit_transactions_2026_03 PARTITION OF credit_transactions FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE credit_transactions_2026_04 PARTITION OF credit_transactions FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE credit_transactions_2026_05 PARTITION OF credit_transactions FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE credit_transactions_2026_06 PARTITION OF credit_transactions FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE credit_transactions_2026_07 PARTITION OF credit_transactions FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE credit_transactions_2026_08 PARTITION OF credit_transactions FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE credit_transactions_2026_09 PARTITION OF credit_transactions FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE credit_transactions_2026_10 PARTITION OF credit_transactions FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE credit_transactions_2026_11 PARTITION OF credit_transactions FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE credit_transactions_2026_12 PARTITION OF credit_transactions FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');


-- ============================================================
-- 8. USAGE ANALYTICS
-- ============================================================

CREATE TABLE usage_daily (
    id                  UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id        UUID          NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    model_id            UUID          REFERENCES ai_models(id) ON DELETE SET NULL,
    model_name          VARCHAR(100),
    date                DATE          NOT NULL,
    execution_count     INTEGER       NOT NULL DEFAULT 0,
    success_count       INTEGER       NOT NULL DEFAULT 0,
    failure_count       INTEGER       NOT NULL DEFAULT 0,
    credits_used        INTEGER       NOT NULL DEFAULT 0,
    estimated_cost_usd  NUMERIC(10,4) NOT NULL DEFAULT 0.0000,
    total_images        INTEGER       NOT NULL DEFAULT 0,
    total_video_seconds NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    avg_latency_ms      INTEGER,
    p95_latency_ms      INTEGER,
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    UNIQUE (workspace_id, model_id, date)
);


-- ============================================================
-- 9. INDEXES
-- ============================================================

CREATE INDEX idx_subscriptions_workspace ON subscriptions(workspace_id);
CREATE INDEX idx_subscriptions_status    ON subscriptions(status) WHERE status IN ('active','trialing','past_due');
CREATE INDEX idx_subscriptions_external  ON subscriptions(external_subscription_id) WHERE external_subscription_id IS NOT NULL;
CREATE INDEX idx_payments_workspace      ON payments(workspace_id);
CREATE INDEX idx_payments_status         ON payments(status);
CREATE INDEX idx_payments_external       ON payments(external_payment_id) WHERE external_payment_id IS NOT NULL;
CREATE INDEX idx_credit_tx_workspace     ON credit_transactions(workspace_id, created_at DESC);
CREATE INDEX idx_credit_tx_type          ON credit_transactions(type, created_at DESC);
CREATE INDEX idx_credit_tx_model         ON credit_transactions(model_id) WHERE model_id IS NOT NULL;
CREATE INDEX idx_credit_tx_execution     ON credit_transactions(execution_id) WHERE execution_id IS NOT NULL;
CREATE INDEX idx_workspace_credits_low   ON workspace_credits(balance) WHERE balance < 200;
CREATE INDEX idx_pricing_rules_model     ON model_pricing_rules(model_id) WHERE is_active = TRUE;
CREATE INDEX idx_usage_daily_workspace   ON usage_daily(workspace_id, date DESC);
CREATE INDEX idx_usage_daily_model       ON usage_daily(model_id, date DESC);


-- ============================================================
-- 10. FUNCTIONS & TRIGGERS
-- ============================================================

-- updated_at triggers
CREATE TRIGGER trg_plans_updated_at
    BEFORE UPDATE ON plans FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
CREATE TRIGGER trg_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
CREATE TRIGGER trg_payments_updated_at
    BEFORE UPDATE ON payments FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
CREATE TRIGGER trg_workspace_credits_updated_at
    BEFORE UPDATE ON workspace_credits FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- ── Calculate credits before execution ─────────────────────
CREATE OR REPLACE FUNCTION calculate_execution_credits(
    p_model_id UUID,
    p_params   JSONB
)
RETURNS TABLE (credits INTEGER, breakdown JSONB)
LANGUAGE plpgsql AS $$
DECLARE
    v_model      RECORD;
    v_rule       RECORD;
    v_credits    NUMERIC := 0;
    v_breakdown  JSONB   := '{}'::jsonb;
    v_duration   NUMERIC := COALESCE((p_params->>'duration')::NUMERIC, 5);
    v_width      INTEGER := COALESCE((p_params->>'width')::INTEGER, 1024);
    v_height     INTEGER := COALESCE((p_params->>'height')::INTEGER, 1024);
    v_steps      INTEGER := COALESCE((p_params->>'steps')::INTEGER, 50);
    v_fps        INTEGER := COALESCE((p_params->>'fps')::INTEGER, 24);
    v_resolution TEXT    := COALESCE(p_params->>'resolution', '1080p');
    v_res_mult   NUMERIC := 1.0;
    v_dur_mult   NUMERIC := 1.0;
    v_tier       JSONB;
BEGIN
    SELECT * INTO v_model FROM ai_models WHERE id = p_model_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Model % not found', p_model_id;
    END IF;

    SELECT * INTO v_rule
    FROM model_pricing_rules
    WHERE model_id = p_model_id
      AND is_active = TRUE
      AND effective_from <= NOW()
      AND (effective_until IS NULL OR effective_until > NOW())
    ORDER BY effective_from DESC LIMIT 1;

    IF NOT FOUND THEN
        RETURN QUERY SELECT v_model.credit_cost,
            jsonb_build_object('strategy','flat','base', v_model.credit_cost);
        RETURN;
    END IF;

    IF v_rule.resolution_multipliers IS NOT NULL
       AND v_rule.resolution_multipliers ? v_resolution THEN
        v_res_mult := (v_rule.resolution_multipliers->>v_resolution)::NUMERIC;
    END IF;

    IF v_rule.duration_multipliers IS NOT NULL
       AND v_rule.duration_multipliers ? v_duration::TEXT THEN
        v_dur_mult := (v_rule.duration_multipliers->>v_duration::TEXT)::NUMERIC;
    END IF;

    CASE v_rule.strategy
        WHEN 'flat' THEN
            v_credits   := COALESCE(v_rule.flat_credits, v_model.credit_cost);
            v_breakdown := jsonb_build_object('strategy','flat','base', v_credits);

        WHEN 'per_second' THEN
            v_credits   := CEIL(v_duration * v_rule.credits_per_unit * v_res_mult * v_dur_mult);
            v_breakdown := jsonb_build_object(
                'strategy','per_second','duration_sec',v_duration,
                'credits_per_sec',v_rule.credits_per_unit,
                'resolution_mult',v_res_mult,'duration_mult',v_dur_mult,'total',v_credits);

        WHEN 'per_megapixel' THEN
            v_credits   := CEIL((v_width * v_height / 1000000.0) * v_rule.credits_per_unit);
            v_breakdown := jsonb_build_object(
                'strategy','per_megapixel',
                'megapixels', ROUND(v_width * v_height / 1000000.0, 2),
                'credits_per_mp', v_rule.credits_per_unit, 'total', v_credits);

        WHEN 'per_frame' THEN
            v_credits   := CEIL(v_duration * v_fps * v_rule.credits_per_unit * v_res_mult);
            v_breakdown := jsonb_build_object(
                'strategy','per_frame','frames', v_duration * v_fps,
                'credits_per_frame', v_rule.credits_per_unit,
                'resolution_mult', v_res_mult, 'total', v_credits);

        WHEN 'tiered' THEN
            SELECT tier INTO v_tier
            FROM jsonb_array_elements(v_rule.tiers) AS tier
            WHERE (tier->>'up_to') IS NULL
               OR (tier->>'up_to')::NUMERIC >= v_duration
            ORDER BY COALESCE((tier->>'up_to')::NUMERIC, 999999) ASC LIMIT 1;

            v_credits   := CEIL((v_tier->>'credits')::NUMERIC * v_res_mult);
            v_breakdown := jsonb_build_object(
                'strategy','tiered','tier_matched',v_tier,
                'resolution_mult',v_res_mult,'total',v_credits);

        WHEN 'formula' THEN
            v_credits   := v_model.credit_cost;
            v_breakdown := jsonb_build_object(
                'strategy','formula','formula',v_rule.formula,
                'variables', jsonb_build_object(
                    'duration',v_duration,'width',v_width,'height',v_height,
                    'steps',v_steps,'fps',v_fps),
                'fallback_credits', v_credits);

        ELSE
            v_credits   := v_model.credit_cost;
            v_breakdown := jsonb_build_object('strategy','flat','base', v_credits);
    END CASE;

    v_credits := GREATEST(v_credits, 1);
    RETURN QUERY SELECT v_credits::INTEGER, v_breakdown;
END;
$$;

-- ── Atomic credit debit ────────────────────────────────────
CREATE OR REPLACE FUNCTION debit_credits(
    p_workspace_id    UUID,
    p_amount          INTEGER,
    p_user_id         UUID,
    p_description     TEXT,
    p_model_id        UUID        DEFAULT NULL,
    p_model_name      VARCHAR     DEFAULT NULL,
    p_execution_id    UUID        DEFAULT NULL,
    p_execution_ts    TIMESTAMPTZ DEFAULT NULL,
    p_node_exec_id    UUID        DEFAULT NULL,
    p_pricing_rule_id UUID        DEFAULT NULL,
    p_breakdown       JSONB       DEFAULT NULL,
    p_params          JSONB       DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    v_balance       INTEGER;
    v_balance_after INTEGER;
    v_tx_id         UUID := uuid_generate_v4();
BEGIN
    SELECT balance INTO v_balance
    FROM workspace_credits
    WHERE workspace_id = p_workspace_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Workspace credits not found for %', p_workspace_id;
    END IF;

    IF v_balance < p_amount THEN
        RETURN jsonb_build_object(
            'success', FALSE, 'error', 'insufficient_credits',
            'balance', v_balance, 'required', p_amount,
            'shortfall', p_amount - v_balance);
    END IF;

    v_balance_after := v_balance - p_amount;

    UPDATE workspace_credits SET
        balance            = v_balance_after,
        lifetime_used      = lifetime_used + p_amount,
        cycle_credits_used = cycle_credits_used + p_amount
    WHERE workspace_id = p_workspace_id;

    INSERT INTO credit_transactions (
        id, workspace_id, user_id, type, amount, balance_after, description,
        model_id, model_name, execution_id, execution_created_at,
        node_execution_id, pricing_rule_id,
        duration_seconds, resolution, width, height, steps, metadata
    ) VALUES (
        v_tx_id, p_workspace_id, p_user_id, 'usage', -p_amount, v_balance_after, p_description,
        p_model_id, p_model_name, p_execution_id, p_execution_ts,
        p_node_exec_id, p_pricing_rule_id,
        (p_params->>'duration')::NUMERIC, p_params->>'resolution',
        (p_params->>'width')::INTEGER, (p_params->>'height')::INTEGER,
        (p_params->>'steps')::INTEGER, COALESCE(p_breakdown, '{}'::jsonb)
    );

    -- Notify application layer on low balance
    IF v_balance_after <= (
        SELECT low_balance_threshold FROM workspace_credits WHERE workspace_id = p_workspace_id
    ) THEN
        PERFORM pg_notify('low_balance', jsonb_build_object(
            'workspace_id', p_workspace_id, 'balance', v_balance_after
        )::text);
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE, 'transaction_id', v_tx_id,
        'debited', p_amount, 'balance_before', v_balance, 'balance_after', v_balance_after);
END;
$$;

-- ── Credit workspace (purchase / bonus / refund) ───────────
CREATE OR REPLACE FUNCTION credit_workspace(
    p_workspace_id UUID,
    p_amount       INTEGER,
    p_type         transaction_type,
    p_user_id      UUID        DEFAULT NULL,
    p_description  TEXT        DEFAULT NULL,
    p_payment_id   UUID        DEFAULT NULL,
    p_expires_at   TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    v_balance_after INTEGER;
    v_tx_id         UUID := uuid_generate_v4();
BEGIN
    UPDATE workspace_credits SET
        balance            = balance + p_amount,
        lifetime_purchased = CASE WHEN p_type = 'purchase' THEN lifetime_purchased + p_amount ELSE lifetime_purchased END,
        lifetime_bonus     = CASE WHEN p_type = 'bonus'    THEN lifetime_bonus + p_amount     ELSE lifetime_bonus END,
        lifetime_refunded  = CASE WHEN p_type = 'refund'   THEN lifetime_refunded + p_amount  ELSE lifetime_refunded END
    WHERE workspace_id = p_workspace_id
    RETURNING balance INTO v_balance_after;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Workspace credits not found for %', p_workspace_id;
    END IF;

    INSERT INTO credit_transactions (
        id, workspace_id, user_id, type, amount, balance_after,
        description, payment_id, expires_at
    ) VALUES (
        v_tx_id, p_workspace_id, p_user_id, p_type, p_amount, v_balance_after,
        p_description, p_payment_id, p_expires_at
    );

    RETURN jsonb_build_object(
        'success', TRUE, 'transaction_id', v_tx_id,
        'credited', p_amount, 'balance_after', v_balance_after);
END;
$$;

-- ── Auto-init credits on workspace creation ─────────────────
CREATE OR REPLACE FUNCTION fn_init_workspace_credits()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO workspace_credits (
        workspace_id, balance, cycle_credits_included, cycle_reset_at
    ) VALUES (
        NEW.id, 100, 100, NOW() + INTERVAL '30 days'
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_init_workspace_credits
    AFTER INSERT ON workspaces
    FOR EACH ROW EXECUTE FUNCTION fn_init_workspace_credits();

-- ── Aggregate daily usage stats ────────────────────────────
CREATE OR REPLACE FUNCTION fn_aggregate_usage_daily()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.type = 'usage' AND NEW.model_id IS NOT NULL THEN
        INSERT INTO usage_daily (
            workspace_id, model_id, model_name, date,
            execution_count, success_count, credits_used, estimated_cost_usd
        ) VALUES (
            NEW.workspace_id, NEW.model_id, NEW.model_name,
            NEW.created_at::DATE, 1, 1,
            ABS(NEW.amount), ABS(NEW.amount) * 0.01
        )
        ON CONFLICT (workspace_id, model_id, date) DO UPDATE SET
            execution_count    = usage_daily.execution_count + 1,
            success_count      = usage_daily.success_count + 1,
            credits_used       = usage_daily.credits_used + ABS(EXCLUDED.credits_used),
            estimated_cost_usd = usage_daily.estimated_cost_usd + EXCLUDED.estimated_cost_usd,
            updated_at         = NOW();
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_aggregate_usage
    AFTER INSERT ON credit_transactions
    FOR EACH ROW EXECUTE FUNCTION fn_aggregate_usage_daily();

-- ── Monthly cycle reset (schedule via pg_cron) ─────────────
-- cron.schedule('reset-credits','0 0 1 * *','SELECT fn_reset_cycle_credits()');
CREATE OR REPLACE FUNCTION fn_reset_cycle_credits()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE workspace_credits wc
    SET balance                = balance + p.credits_per_cycle,
        cycle_credits_included = p.credits_per_cycle,
        cycle_credits_used     = 0,
        cycle_reset_at         = NOW() + INTERVAL '1 month',
        lifetime_purchased     = lifetime_purchased + p.credits_per_cycle
    FROM subscriptions s
    JOIN plans p ON p.id = s.plan_id
    WHERE s.workspace_id = wc.workspace_id
      AND s.status IN ('active','trialing')
      AND wc.cycle_reset_at <= NOW();
END;
$$;


-- ============================================================
-- 11. VIEWS
-- ============================================================

CREATE OR REPLACE VIEW v_workspace_billing AS
SELECT
    w.id                        AS workspace_id,
    w.name                      AS workspace_name,
    w.plan                      AS plan_type,
    p.display_name              AS plan_name,
    wc.balance                  AS credits_balance,
    wc.cycle_credits_used,
    wc.cycle_credits_included,
    ROUND(wc.cycle_credits_used::NUMERIC /
        NULLIF(wc.cycle_credits_included, 0) * 100, 1) AS cycle_usage_pct,
    wc.lifetime_used,
    ROUND(wc.lifetime_used * 0.01, 2)  AS lifetime_spend_usd,
    s.status                    AS subscription_status,
    s.current_period_end        AS next_billing_date,
    s.cancel_at_period_end,
    wc.auto_topup_enabled,
    wc.low_balance_threshold,
    wc.cycle_reset_at
FROM workspaces w
LEFT JOIN workspace_credits wc ON wc.workspace_id = w.id
LEFT JOIN subscriptions s      ON s.workspace_id  = w.id
                               AND s.status IN ('active','trialing','past_due')
LEFT JOIN plans p              ON p.id = s.plan_id
WHERE w.deleted_at IS NULL;

-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW v_model_pricing AS
SELECT
    m.id,
    m.display_name,
    m.provider::TEXT,
    m.modality::TEXT,
    m.sub_modality,
    m.credit_cost               AS base_credits,
    m.cost_variable,
    r.strategy::TEXT,
    r.credits_per_unit,
    r.tiers,
    r.resolution_multipliers,
    r.duration_multipliers,
    ROUND(m.credit_cost * 0.01, 4) AS base_cost_usd,
    CASE
        WHEN m.credit_cost <= 2  THEN 'low'
        WHEN m.credit_cost <= 8  THEN 'medium'
        WHEN m.credit_cost <= 15 THEN 'high'
        ELSE 'very_high'
    END                         AS cost_tier,
    m.avg_latency_ms,
    m.health::TEXT,
    m.is_active,
    m.is_beta
FROM ai_models m
LEFT JOIN model_pricing_rules r ON r.model_id = m.id
    AND r.is_active = TRUE
    AND r.effective_from <= NOW()
    AND (r.effective_until IS NULL OR r.effective_until > NOW())
ORDER BY m.modality, m.credit_cost;

-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW v_usage_30d AS
SELECT
    workspace_id,
    model_name,
    SUM(execution_count)                         AS total_executions,
    SUM(credits_used)                            AS total_credits,
    ROUND(SUM(estimated_cost_usd)::NUMERIC, 4)   AS total_cost_usd,
    SUM(total_images)                            AS total_images,
    SUM(total_video_seconds)                     AS total_video_seconds,
    ROUND(AVG(avg_latency_ms))                   AS avg_latency_ms
FROM usage_daily
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY workspace_id, model_name
ORDER BY total_credits DESC;


-- ============================================================
-- 12. SEED DATA
-- ============================================================

INSERT INTO plans (
    name, display_name, description,
    price_monthly_usd, price_annual_usd,
    credits_per_cycle, credit_value_usd,
    max_workspaces, max_members, max_canvases, max_storage_gb, max_executions_day,
    features, sort_order
) VALUES

('free', 'Free', 'Get started — no credit card required',
 0.00, 0.00, 100, 0.010000, 1, 1, 5, 2, 20,
 '{"watermark":true,"api_access":false,"priority_queue":false,"custom_models":false,
   "app_publish":false,"collaboration":false,"version_history":5,
   "export_formats":["mp4","png"]}'::jsonb, 1),

('starter', 'Starter', 'For solo creators building their first pipelines',
 12.00, 115.00, 1500, 0.008000, 1, 3, 20, 20, 200,
 '{"watermark":false,"api_access":false,"priority_queue":false,"custom_models":false,
   "app_publish":true,"collaboration":false,"version_history":30,
   "export_formats":["mp4","mov","png","webp"]}'::jsonb, 2),

('pro', 'Pro', 'For professionals running serious workflows',
 39.00, 374.00, 6000, 0.006500, 3, 10, 100, 100, 1000,
 '{"watermark":false,"api_access":true,"priority_queue":true,"custom_models":false,
   "app_publish":true,"collaboration":true,"version_history":365,
   "export_formats":["mp4","mov","webm","png","webp","jpeg"]}'::jsonb, 3),

('enterprise', 'Enterprise', 'Unlimited scale, custom models, SLA',
 149.00, 1430.00, 30000, 0.005000, 999, 999, 999, 999, 999,
 '{"watermark":false,"api_access":true,"priority_queue":true,"custom_models":true,
   "app_publish":true,"collaboration":true,"version_history":-1,
   "export_formats":["mp4","mov","webm","png","webp","jpeg","gif","prores"],
   "sla":true,"dedicated_support":true}'::jsonb, 4);

-- ────────────────────────────────────────────────────────────

INSERT INTO credit_packages (name, credits, price_usd, bonus_credits, sort_order) VALUES
('Starter Pack',   500,    4.99,    0, 1),
('Value Pack',    1500,   12.99,  150, 2),
('Creator Pack',  5000,   39.99,  750, 3),
('Studio Pack',  15000,  109.99, 3000, 4),
('Agency Pack',  50000,  329.99,15000, 5);

-- ────────────────────────────────────────────────────────────
-- Pricing rules — one INSERT per model to avoid UNION type conflicts

INSERT INTO model_pricing_rules (model_id, strategy, parameter_name, credits_per_unit, resolution_multipliers, duration_multipliers, tiers, is_active)
SELECT id, 'tiered'::pricing_strategy, 'duration', NULL::NUMERIC,
    '{"720p":1.0,"1080p":1.6}'::jsonb, NULL::jsonb,
    '[{"up_to":5,"credits":20},{"up_to":8,"credits":30},{"up_to":null,"credits":40}]'::jsonb, TRUE
FROM ai_models WHERE model_name = 'veo-3';

INSERT INTO model_pricing_rules (model_id, strategy, parameter_name, credits_per_unit, resolution_multipliers, duration_multipliers, tiers, is_active)
SELECT id, 'tiered'::pricing_strategy, 'duration', NULL::NUMERIC,
    '{"480p":0.6,"720p":1.0,"1080p":1.8}'::jsonb, NULL::jsonb,
    '[{"up_to":5,"credits":25},{"up_to":10,"credits":45},{"up_to":null,"credits":80}]'::jsonb, TRUE
FROM ai_models WHERE model_name = 'sora';

INSERT INTO model_pricing_rules (model_id, strategy, parameter_name, credits_per_unit, resolution_multipliers, duration_multipliers, tiers, is_active)
SELECT id, 'per_second'::pricing_strategy, 'duration', 3.0::NUMERIC,
    '{"720p":1.0,"1080p":1.5}'::jsonb, '{"5":1.0,"10":1.7}'::jsonb,
    NULL::jsonb, TRUE
FROM ai_models WHERE model_name = 'kling-v2';

INSERT INTO model_pricing_rules (model_id, strategy, parameter_name, credits_per_unit, resolution_multipliers, duration_multipliers, tiers, is_active)
SELECT id, 'per_second'::pricing_strategy, 'duration', 3.5::NUMERIC,
    '{"720p":1.0,"1080p":1.5}'::jsonb, '{"5":1.0,"10":1.8}'::jsonb,
    NULL::jsonb, TRUE
FROM ai_models WHERE model_name = 'gen-4';

INSERT INTO model_pricing_rules (model_id, strategy, parameter_name, credits_per_unit, resolution_multipliers, duration_multipliers, tiers, is_active)
SELECT id, 'per_second'::pricing_strategy, 'duration', 3.2::NUMERIC,
    '{"720p":1.0,"1080p":1.4}'::jsonb, '{"5":1.0,"9":1.6}'::jsonb,
    NULL::jsonb, TRUE
FROM ai_models WHERE model_name = 'ray-2';

INSERT INTO model_pricing_rules (model_id, strategy, parameter_name, credits_per_unit, resolution_multipliers, duration_multipliers, tiers, is_active)
SELECT id, 'per_second'::pricing_strategy, 'duration', 3.0::NUMERIC,
    '{"720p":1.0,"1080p":1.4}'::jsonb, NULL::jsonb,
    NULL::jsonb, TRUE
FROM ai_models WHERE model_name = 'higgsfield-1';

INSERT INTO model_pricing_rules (model_id, strategy, parameter_name, credits_per_unit, resolution_multipliers, duration_multipliers, tiers, is_active)
SELECT id, 'tiered'::pricing_strategy, 'duration', NULL::NUMERIC,
    '{"720p":1.0,"1080p":1.4}'::jsonb, NULL::jsonb,
    '[{"up_to":3,"credits":8},{"up_to":5,"credits":12},{"up_to":8,"credits":18},{"up_to":null,"credits":25}]'::jsonb, TRUE
FROM ai_models WHERE model_name = 'seedance-1';

INSERT INTO model_pricing_rules (model_id, strategy, parameter_name, credits_per_unit, resolution_multipliers, duration_multipliers, tiers, is_active)
SELECT id, 'formula'::pricing_strategy, NULL::VARCHAR, NULL::NUMERIC,
    '{"720p":1.0,"1080p":2.0,"4k":4.5}'::jsonb, NULL::jsonb,
    NULL::jsonb, TRUE
FROM ai_models WHERE model_name = 'topaz-video-ai';

INSERT INTO model_pricing_rules (model_id, strategy, parameter_name, credits_per_unit, resolution_multipliers, duration_multipliers, tiers, is_active)
SELECT id, 'per_megapixel'::pricing_strategy, 'width', 4.0::NUMERIC,
    NULL::jsonb, NULL::jsonb, NULL::jsonb, TRUE
FROM ai_models WHERE model_name = 'flux-pro-1.1-ultra';

INSERT INTO model_pricing_rules (model_id, strategy, parameter_name, credits_per_unit, resolution_multipliers, duration_multipliers, tiers, is_active)
SELECT id, 'per_megapixel'::pricing_strategy, 'width', 5.0::NUMERIC,
    NULL::jsonb, NULL::jsonb, NULL::jsonb, TRUE
FROM ai_models WHERE model_name = 'imagen-4';

INSERT INTO model_pricing_rules (model_id, strategy, parameter_name, credits_per_unit, resolution_multipliers, duration_multipliers, tiers, is_active)
SELECT id, 'per_megapixel'::pricing_strategy, 'width', 3.0::NUMERIC,
    NULL::jsonb, NULL::jsonb, NULL::jsonb, TRUE
FROM ai_models WHERE model_name = 'sana-1.5';

-- ============================================================
-- END OF BILLING & CREDIT SYSTEM
-- ============================================================
