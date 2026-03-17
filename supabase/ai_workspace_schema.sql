-- ============================================================
--  AI WORKSPACE — CORE SCHEMA
--  File 1 of 3 — run this first
--  PostgreSQL 15+  |  Extensions: uuid-ossp, pg_trgm, vector
--
--  Sections:
--    1.  Extensions & Enums
--    2.  Identity & Auth
--    3.  AI Model Registry
--    4.  Canvas & Workflows
--    5.  Execution Engine
--    6.  Asset Storage
--    7.  Versioning & History
--    8.  Product Features
--    9.  Indexes
--    10. Functions & Triggers
--    11. Row-Level Security
-- ============================================================

-- ============================================================
-- 1. EXTENSIONS & ENUMS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "vector";

CREATE TYPE user_role         AS ENUM ('owner','admin','editor','viewer');
CREATE TYPE plan_type         AS ENUM ('free','starter','pro','enterprise');
CREATE TYPE session_status    AS ENUM ('online','away','offline','editing','viewing');
CREATE TYPE model_provider    AS ENUM ('anthropic','openai','google','fal','replicate',
                                       'mistral','cohere','runway','luma','topaz',
                                       'higgsfield','nvidia','bytedance','custom');
CREATE TYPE modality_type     AS ENUM ('image','video','audio','text','3d','multimodal');
CREATE TYPE health_status     AS ENUM ('healthy','degraded','down','maintenance');
CREATE TYPE workflow_status   AS ENUM ('draft','running','paused','completed','error');
CREATE TYPE execution_mode    AS ENUM ('manual','auto','scheduled');
CREATE TYPE node_category     AS ENUM ('input','ai_model','edit_tool','control',
                                       'output','integration','custom');
CREATE TYPE execution_status  AS ENUM ('idle','queued','running','completed',
                                       'error','cached','skipped');
CREATE TYPE edge_type         AS ENUM ('direct','batch','conditional','feedback');
CREATE TYPE data_type         AS ENUM ('image','video','audio','text','mask','json','any');
CREATE TYPE port_kind         AS ENUM ('input','output');
CREATE TYPE asset_type        AS ENUM ('image','video','audio','mask','3d_model',
                                       'text','json','archive');
CREATE TYPE version_action    AS ENUM ('created','updated','deleted','restored','published');
CREATE TYPE access_type       AS ENUM ('private','workspace','public','password','link');
CREATE TYPE difficulty_level  AS ENUM ('beginner','intermediate','advanced');


-- ============================================================
-- 2. IDENTITY & AUTH
-- ============================================================

CREATE TABLE users (
    id                    UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    email                 VARCHAR(255) UNIQUE NOT NULL,
    email_verified        BOOLEAN     NOT NULL DEFAULT FALSE,
    password_hash         VARCHAR(255),
    mfa_enabled           BOOLEAN     NOT NULL DEFAULT FALSE,
    mfa_secret_encrypted  TEXT,
    failed_login_attempts INTEGER     NOT NULL DEFAULT 0,
    locked_until          TIMESTAMPTZ,
    last_login_at         TIMESTAMPTZ,
    google_id             VARCHAR(100),
    github_id             VARCHAR(100),
    figma_id              VARCHAR(100),
    display_name          VARCHAR(100),
    handle                VARCHAR(50)  UNIQUE,
    avatar_url            TEXT,
    bio                   TEXT,
    preferences           JSONB        NOT NULL DEFAULT '{
        "theme": "system",
        "default_models": [],
        "notifications": {"email": true, "browser": true, "slack": false},
        "editor": {"auto_save": true, "show_grid": true},
        "shortcuts": {}
    }'::jsonb,
    embedding             VECTOR(1536),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE workspaces (
    id           UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug         VARCHAR(50)  UNIQUE NOT NULL,
    name         VARCHAR(100) NOT NULL,
    description  TEXT,
    avatar_url   TEXT,
    plan         plan_type    NOT NULL DEFAULT 'free',
    credits_balance           INTEGER NOT NULL DEFAULT 0,
    credits_reset_date        TIMESTAMPTZ,
    settings     JSONB        NOT NULL DEFAULT '{
        "max_canvas_size": 10000,
        "max_nodes_per_graph": 100,
        "allowed_models": [],
        "collaboration_enabled": true,
        "app_mode_enabled": false,
        "storage_quota_gb": 10
    }'::jsonb,
    deleted_at   TIMESTAMPTZ,
    is_active    BOOLEAN GENERATED ALWAYS AS (deleted_at IS NULL) STORED,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE workspace_members (
    id           UUID      PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID      NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    user_id      UUID      NOT NULL REFERENCES users(id)      ON DELETE CASCADE,
    role         user_role NOT NULL DEFAULT 'editor',
    invited_by   UUID      REFERENCES users(id),
    joined_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (workspace_id, user_id)
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE teams (
    id           UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID         NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    name         VARCHAR(100) NOT NULL,
    description  TEXT,
    color        VARCHAR(7)   NOT NULL DEFAULT '#6366f1',
    member_count INTEGER      NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE team_members (
    team_id  UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    added_by UUID REFERENCES users(id),
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (team_id, user_id)
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE user_sessions (
    id               UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id          UUID          NOT NULL REFERENCES users(id)      ON DELETE CASCADE,
    workspace_id     UUID          REFERENCES workspaces(id)          ON DELETE CASCADE,
    socket_id        VARCHAR(100),
    status           session_status NOT NULL DEFAULT 'online',
    active_canvas_id UUID,
    viewport         JSONB,
    last_activity_at TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    connected_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    ip_address       INET,
    user_agent       TEXT
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE api_keys (
    id           UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id      UUID         NOT NULL REFERENCES users(id)      ON DELETE CASCADE,
    workspace_id UUID         REFERENCES workspaces(id)          ON DELETE CASCADE,
    name         VARCHAR(100) NOT NULL,
    key_hash     VARCHAR(255) NOT NULL UNIQUE,
    scopes       TEXT[]       NOT NULL DEFAULT '{}',
    last_used_at TIMESTAMPTZ,
    expires_at   TIMESTAMPTZ,
    revoked_at   TIMESTAMPTZ,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 3. AI MODEL REGISTRY
-- ============================================================

CREATE TABLE ai_models (
    id               UUID           PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider         model_provider NOT NULL,
    model_name       VARCHAR(100)   NOT NULL,
    model_version    VARCHAR(20)    NOT NULL DEFAULT '1.0.0',
    display_name     VARCHAR(100)   NOT NULL,
    description      TEXT,
    modality         modality_type  NOT NULL,
    sub_modality     VARCHAR(30),
    config_schema    JSONB          NOT NULL DEFAULT '{}',
    default_params   JSONB          NOT NULL DEFAULT '{}',
    credit_cost      INTEGER        NOT NULL DEFAULT 1,
    cost_variable    BOOLEAN        NOT NULL DEFAULT FALSE,
    cost_formula     TEXT,
    min_resolution   JSONB,
    max_resolution   JSONB,
    supported_formats TEXT[],
    max_batch_size   INTEGER        NOT NULL DEFAULT 1,
    is_active        BOOLEAN        NOT NULL DEFAULT TRUE,
    is_beta          BOOLEAN        NOT NULL DEFAULT FALSE,
    health           health_status  NOT NULL DEFAULT 'healthy',
    avg_latency_ms   INTEGER,
    success_rate     NUMERIC(5,2)   NOT NULL DEFAULT 100.00,
    embedding        VECTOR(1536),
    created_at       TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    UNIQUE (provider, model_name, model_version)
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE model_providers (
    id                         UUID           PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id               UUID           NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    provider                   model_provider NOT NULL,
    api_key_encrypted          TEXT,
    api_secret_encrypted       TEXT,
    base_url                   VARCHAR(255),
    rate_limit_requests        INTEGER        NOT NULL DEFAULT 60,
    rate_limit_window_seconds  INTEGER        NOT NULL DEFAULT 60,
    monthly_spend              NUMERIC(10,2)  NOT NULL DEFAULT 0.00,
    budget_limit               NUMERIC(10,2),
    budget_alert_threshold_pct NUMERIC(5,2)   NOT NULL DEFAULT 80.00,
    is_active                  BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at                 TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at                 TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    UNIQUE (workspace_id, provider)
);


-- ============================================================
-- 4. CANVAS & WORKFLOWS
-- ============================================================

CREATE TABLE canvas_graphs (
    id               UUID           PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id     UUID           NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    team_id          UUID           REFERENCES teams(id) ON DELETE SET NULL,
    created_by       UUID           NOT NULL REFERENCES users(id),
    updated_by       UUID           REFERENCES users(id),
    title            VARCHAR(200)   NOT NULL,
    description      TEXT,
    thumbnail_url    TEXT,
    tags             TEXT[]         NOT NULL DEFAULT '{}',
    status           workflow_status NOT NULL DEFAULT 'draft',
    execution_mode   execution_mode  NOT NULL DEFAULT 'manual',
    viewport         JSONB           NOT NULL DEFAULT '{"x":0,"y":0,"zoom":1,"width":5000,"height":5000}'::jsonb,
    is_app_published BOOLEAN         NOT NULL DEFAULT FALSE,
    app_config       JSONB,
    node_count       INTEGER         NOT NULL DEFAULT 0,
    edge_count       INTEGER         NOT NULL DEFAULT 0,
    execution_count  INTEGER         NOT NULL DEFAULT 0,
    last_executed_at TIMESTAMPTZ,
    current_version  INTEGER         NOT NULL DEFAULT 1,
    embedding        VECTOR(1536),
    deleted_at       TIMESTAMPTZ,
    created_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

ALTER TABLE user_sessions
    ADD CONSTRAINT fk_session_canvas
    FOREIGN KEY (active_canvas_id) REFERENCES canvas_graphs(id) ON DELETE SET NULL;

-- ────────────────────────────────────────────────────────────

CREATE TABLE nodes (
    id               UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    canvas_id        UUID          NOT NULL REFERENCES canvas_graphs(id) ON DELETE CASCADE,
    position_x       FLOAT         NOT NULL DEFAULT 0,
    position_y       FLOAT         NOT NULL DEFAULT 0,
    width            FLOAT         NOT NULL DEFAULT 300,
    height           FLOAT         NOT NULL DEFAULT 200,
    z_index          INTEGER       NOT NULL DEFAULT 0,
    category         node_category NOT NULL DEFAULT 'custom',
    node_type        VARCHAR(50)   NOT NULL,
    node_version     VARCHAR(20)   NOT NULL DEFAULT '1.0.0',
    label            VARCHAR(100),
    color            VARCHAR(7),
    icon             VARCHAR(50),
    description      TEXT,
    execution_status execution_status NOT NULL DEFAULT 'idle',
    execution_order  INTEGER,
    execution_group  INTEGER       NOT NULL DEFAULT 0,
    cache_enabled    BOOLEAN       NOT NULL DEFAULT TRUE,
    cache_key        VARCHAR(64),
    cache_expires_at TIMESTAMPTZ,
    cache_version    INTEGER       NOT NULL DEFAULT 1,
    retry_count      INTEGER       NOT NULL DEFAULT 0,
    max_retries      INTEGER       NOT NULL DEFAULT 3,
    timeout_seconds  INTEGER       NOT NULL DEFAULT 300,
    is_disabled      BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE node_ports (
    id            UUID      PRIMARY KEY DEFAULT uuid_generate_v4(),
    node_id       UUID      NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
    port_name     VARCHAR(50) NOT NULL,
    port_kind     port_kind   NOT NULL,
    data_type     data_type   NOT NULL DEFAULT 'any',
    is_required   BOOLEAN     NOT NULL DEFAULT FALSE,
    default_value JSONB,
    description   TEXT,
    sort_order    INTEGER     NOT NULL DEFAULT 0,
    UNIQUE (node_id, port_name, port_kind)
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE node_configs (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    node_id           UUID NOT NULL REFERENCES nodes(id) ON DELETE CASCADE UNIQUE,
    inputs            JSONB NOT NULL DEFAULT '{}',
    model_params      JSONB NOT NULL DEFAULT '{}',
    ui_state          JSONB NOT NULL DEFAULT '{
        "collapsed": false,
        "selected_tab": "settings",
        "show_preview": true,
        "panel_width": 320
    }'::jsonb,
    condition         JSONB,
    encrypted_secrets TEXT,
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE edges (
    id             UUID      PRIMARY KEY DEFAULT uuid_generate_v4(),
    canvas_id      UUID      NOT NULL REFERENCES canvas_graphs(id) ON DELETE CASCADE,
    source_node_id UUID      NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
    source_port    VARCHAR(50) NOT NULL,
    target_node_id UUID      NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
    target_port    VARCHAR(50) NOT NULL,
    edge_type      edge_type   NOT NULL DEFAULT 'direct',
    data_type      data_type   NOT NULL DEFAULT 'any',
    control_points JSONB,
    label          VARCHAR(100),
    condition_expr TEXT,
    is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
    priority       INTEGER     NOT NULL DEFAULT 0,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT no_self_loop CHECK (source_node_id <> target_node_id),
    UNIQUE (canvas_id, source_node_id, source_port, target_node_id, target_port)
);


-- ============================================================
-- 5. EXECUTION ENGINE
-- ============================================================

CREATE TABLE executions (
    id                    UUID        NOT NULL DEFAULT uuid_generate_v4(),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    canvas_id             UUID        NOT NULL REFERENCES canvas_graphs(id) ON DELETE CASCADE,
    canvas_version        INTEGER     NOT NULL DEFAULT 1,
    triggered_by          UUID        REFERENCES users(id) ON DELETE SET NULL,
    execution_type        VARCHAR(20) NOT NULL DEFAULT 'manual'
                              CHECK (execution_type IN ('manual','auto','scheduled','api','webhook')),
    status                VARCHAR(20) NOT NULL DEFAULT 'pending'
                              CHECK (status IN ('pending','queued','running','paused','completed','failed','cancelled','timeout')),
    progress_percent      INTEGER     NOT NULL DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
    current_node_id       UUID,
    completed_nodes       INTEGER     NOT NULL DEFAULT 0,
    total_nodes           INTEGER,
    initial_inputs        JSONB       NOT NULL DEFAULT '{}',
    final_outputs         JSONB,
    metadata              JSONB       NOT NULL DEFAULT '{}',
    queued_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at            TIMESTAMPTZ,
    completed_at          TIMESTAMPTZ,
    duration_ms           INTEGER GENERATED ALWAYS AS (
                              CASE WHEN completed_at IS NOT NULL AND started_at IS NOT NULL
                              THEN EXTRACT(EPOCH FROM (completed_at - started_at))::INTEGER * 1000
                              ELSE NULL END
                          ) STORED,
    credits_consumed      INTEGER     NOT NULL DEFAULT 0,
    storage_used_bytes    BIGINT      NOT NULL DEFAULT 0,
    error_node_id         UUID,
    error_message         TEXT,
    error_stack           TEXT,
    retry_of_execution_id UUID,
    retry_of_created_at   TIMESTAMPTZ,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

ALTER TABLE executions ADD CONSTRAINT fk_execution_retry
    FOREIGN KEY (retry_of_execution_id, retry_of_created_at)
    REFERENCES executions(id, created_at)
    ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;

-- Monthly partitions 2025–2026
CREATE TABLE executions_2025_01 PARTITION OF executions FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE executions_2025_02 PARTITION OF executions FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE executions_2025_03 PARTITION OF executions FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE executions_2025_04 PARTITION OF executions FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE executions_2025_05 PARTITION OF executions FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE executions_2025_06 PARTITION OF executions FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE executions_2025_07 PARTITION OF executions FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE executions_2025_08 PARTITION OF executions FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE executions_2025_09 PARTITION OF executions FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE executions_2025_10 PARTITION OF executions FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE executions_2025_11 PARTITION OF executions FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE executions_2025_12 PARTITION OF executions FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE executions_2026_01 PARTITION OF executions FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE executions_2026_02 PARTITION OF executions FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE executions_2026_03 PARTITION OF executions FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE executions_2026_04 PARTITION OF executions FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE executions_2026_05 PARTITION OF executions FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE executions_2026_06 PARTITION OF executions FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE executions_2026_07 PARTITION OF executions FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE executions_2026_08 PARTITION OF executions FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE executions_2026_09 PARTITION OF executions FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE executions_2026_10 PARTITION OF executions FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE executions_2026_11 PARTITION OF executions FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE executions_2026_12 PARTITION OF executions FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

-- ────────────────────────────────────────────────────────────

CREATE TABLE node_executions (
    id                   UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    execution_id         UUID        NOT NULL,
    execution_created_at TIMESTAMPTZ NOT NULL,
    node_id              UUID        NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
    status               execution_status NOT NULL DEFAULT 'idle',
    started_at           TIMESTAMPTZ,
    completed_at         TIMESTAMPTZ,
    duration_ms          INTEGER GENERATED ALWAYS AS (
                             CASE WHEN completed_at IS NOT NULL AND started_at IS NOT NULL
                             THEN EXTRACT(EPOCH FROM (completed_at - started_at))::INTEGER * 1000
                             ELSE NULL END
                         ) STORED,
    input_data           JSONB       NOT NULL DEFAULT '{}',
    output_data          JSONB       NOT NULL DEFAULT '{}',
    model_id             UUID        REFERENCES ai_models(id) ON DELETE SET NULL,
    prompt_tokens        INTEGER,
    completion_tokens    INTEGER,
    cost_usd             NUMERIC(10,6),
    credits_consumed     INTEGER     NOT NULL DEFAULT 0,
    cache_hit            BOOLEAN     NOT NULL DEFAULT FALSE,
    cache_key_used       VARCHAR(64),
    logs                 TEXT,
    logs_truncated       BOOLEAN     NOT NULL DEFAULT FALSE,
    error_message        TEXT,
    error_stack          TEXT,
    retry_attempt        INTEGER     NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    FOREIGN KEY (execution_id, execution_created_at)
        REFERENCES executions(id, created_at) ON DELETE CASCADE
);


-- ============================================================
-- 6. ASSET STORAGE
-- ============================================================

CREATE TABLE assets (
    id                       UUID       PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id             UUID       NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    created_by               UUID       REFERENCES users(id) ON DELETE SET NULL,
    asset_type               asset_type NOT NULL,
    mime_type                VARCHAR(100),
    filename                 VARCHAR(255),
    storage_provider         VARCHAR(20) NOT NULL DEFAULT 's3',
    storage_bucket           VARCHAR(100) NOT NULL,
    storage_key              TEXT       NOT NULL,
    cdn_url                  TEXT,
    file_size_bytes          BIGINT     NOT NULL DEFAULT 0,
    checksum                 VARCHAR(64),
    dimensions               JSONB,
    metadata                 JSONB      NOT NULL DEFAULT '{}',
    source_canvas_id         UUID       REFERENCES canvas_graphs(id) ON DELETE SET NULL,
    source_node_execution_id UUID       REFERENCES node_executions(id) ON DELETE SET NULL,
    generation_params        JSONB,
    parent_asset_id          UUID       REFERENCES assets(id) ON DELETE SET NULL,
    version_number           INTEGER    NOT NULL DEFAULT 1,
    is_latest_version        BOOLEAN    NOT NULL DEFAULT TRUE,
    prompt_embedding         VECTOR(1536),
    is_deleted               BOOLEAN    NOT NULL DEFAULT FALSE,
    deleted_at               TIMESTAMPTZ,
    deleted_by               UUID       REFERENCES users(id) ON DELETE SET NULL,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (storage_bucket, storage_key)
);

CREATE TABLE asset_variants (
    id              UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_id        UUID         NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    variant_name    VARCHAR(50)  NOT NULL,
    storage_key     TEXT         NOT NULL UNIQUE,
    cdn_url         TEXT,
    file_size_bytes BIGINT       NOT NULL DEFAULT 0,
    mime_type       VARCHAR(100),
    dimensions      JSONB,
    metadata        JSONB        NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (asset_id, variant_name)
);

CREATE TABLE asset_tags (
    asset_id   UUID        NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    tag        VARCHAR(50) NOT NULL,
    created_by UUID        REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (asset_id, tag)
);


-- ============================================================
-- 7. VERSIONING & HISTORY
-- ============================================================

CREATE TABLE workflow_versions (
    id             UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    canvas_id      UUID          NOT NULL REFERENCES canvas_graphs(id) ON DELETE CASCADE,
    version_number INTEGER       NOT NULL,
    created_by     UUID          REFERENCES users(id) ON DELETE SET NULL,
    label          VARCHAR(100),
    snapshot       JSONB         NOT NULL,
    change_summary TEXT,
    action         version_action NOT NULL DEFAULT 'updated',
    created_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    UNIQUE (canvas_id, version_number)
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE asset_versions (
    id             UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_id       UUID        NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    version_number INTEGER     NOT NULL,
    created_by     UUID        REFERENCES users(id) ON DELETE SET NULL,
    storage_key    TEXT        NOT NULL,
    file_size_bytes BIGINT     NOT NULL DEFAULT 0,
    change_note    TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (asset_id, version_number)
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE audit_log (
    id           UUID        NOT NULL DEFAULT uuid_generate_v4(),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    workspace_id UUID        NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    actor_id     UUID        REFERENCES users(id) ON DELETE SET NULL,
    entity_type  VARCHAR(30) NOT NULL
                     CHECK (entity_type IN ('workspace','canvas','node','asset','execution',
                                            'comment','team','user','api_key','template')),
    entity_id    UUID        NOT NULL,
    action       VARCHAR(50) NOT NULL,
    old_values   JSONB,
    new_values   JSONB,
    change_summary TEXT,
    metadata     JSONB       NOT NULL DEFAULT '{}',
    ip_address   INET,
    user_agent   TEXT,
    request_id   UUID,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE audit_log_2025_q1 PARTITION OF audit_log FOR VALUES FROM ('2025-01-01') TO ('2025-04-01');
CREATE TABLE audit_log_2025_q2 PARTITION OF audit_log FOR VALUES FROM ('2025-04-01') TO ('2025-07-01');
CREATE TABLE audit_log_2025_q3 PARTITION OF audit_log FOR VALUES FROM ('2025-07-01') TO ('2025-10-01');
CREATE TABLE audit_log_2025_q4 PARTITION OF audit_log FOR VALUES FROM ('2025-10-01') TO ('2026-01-01');
CREATE TABLE audit_log_2026_q1 PARTITION OF audit_log FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE audit_log_2026_q2 PARTITION OF audit_log FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE audit_log_2026_q3 PARTITION OF audit_log FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE audit_log_2026_q4 PARTITION OF audit_log FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');


-- ============================================================
-- 8. PRODUCT FEATURES
-- ============================================================

CREATE TABLE templates (
    id             UUID           PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id   UUID           REFERENCES workspaces(id) ON DELETE CASCADE,
    created_by     UUID           NOT NULL REFERENCES users(id),
    name           VARCHAR(200)   NOT NULL,
    description    TEXT,
    thumbnail_url  TEXT,
    category       VARCHAR(50),
    tags           TEXT[]         NOT NULL DEFAULT '{}',
    difficulty     difficulty_level,
    graph_data     JSONB          NOT NULL,
    input_schema   JSONB,
    example_inputs JSONB,
    usage_count    INTEGER        NOT NULL DEFAULT 0,
    fork_count     INTEGER        NOT NULL DEFAULT 0,
    rating_avg     NUMERIC(3,2)   NOT NULL DEFAULT 0.00 CHECK (rating_avg BETWEEN 0 AND 5),
    rating_count   INTEGER        NOT NULL DEFAULT 0,
    is_public      BOOLEAN        NOT NULL DEFAULT FALSE,
    is_featured    BOOLEAN        NOT NULL DEFAULT FALSE,
    is_official    BOOLEAN        NOT NULL DEFAULT FALSE,
    embedding      VECTOR(1536),
    created_at     TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE published_apps (
    id              UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    canvas_id       UUID         NOT NULL REFERENCES canvas_graphs(id) ON DELETE CASCADE,
    published_by    UUID         REFERENCES users(id) ON DELETE SET NULL,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    icon_url        TEXT,
    slug            VARCHAR(100) UNIQUE NOT NULL,
    input_fields    JSONB,
    output_display  JSONB,
    theme           JSONB,
    access          access_type  NOT NULL DEFAULT 'workspace',
    password_hash   VARCHAR(255),
    allowed_emails  TEXT[],
    allowed_domains TEXT[],
    run_count       INTEGER      NOT NULL DEFAULT 0,
    unique_users    INTEGER      NOT NULL DEFAULT 0,
    last_run_at     TIMESTAMPTZ,
    published_at    TIMESTAMPTZ,
    unpublished_at  TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE comments (
    id                UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    canvas_id         UUID        NOT NULL REFERENCES canvas_graphs(id) ON DELETE CASCADE,
    node_id           UUID        REFERENCES nodes(id) ON DELETE CASCADE,
    parent_comment_id UUID        REFERENCES comments(id) ON DELETE CASCADE,
    position_x        FLOAT,
    position_y        FLOAT,
    content           TEXT        NOT NULL,
    content_type      VARCHAR(20) NOT NULL DEFAULT 'text'
                          CHECK (content_type IN ('text','voice','screenshot','recording')),
    attachments       JSONB,
    created_by        UUID        NOT NULL REFERENCES users(id),
    resolved_at       TIMESTAMPTZ,
    resolved_by       UUID        REFERENCES users(id),
    embedding         VECTOR(1536),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE presence_cursors (
    id                UUID    PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id        UUID    NOT NULL REFERENCES user_sessions(id) ON DELETE CASCADE,
    canvas_id         UUID    NOT NULL REFERENCES canvas_graphs(id) ON DELETE CASCADE,
    user_id           UUID    NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cursor_x          FLOAT   NOT NULL DEFAULT 0,
    cursor_y          FLOAT   NOT NULL DEFAULT 0,
    selected_node_ids UUID[]  NOT NULL DEFAULT '{}',
    is_dragging       BOOLEAN NOT NULL DEFAULT FALSE,
    is_panning        BOOLEAN NOT NULL DEFAULT FALSE,
    viewport_zoom     FLOAT   NOT NULL DEFAULT 1.0,
    viewport_x        FLOAT   NOT NULL DEFAULT 0,
    viewport_y        FLOAT   NOT NULL DEFAULT 0,
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (session_id, canvas_id)
);


-- ============================================================
-- 9. INDEXES
-- ============================================================

-- Users
CREATE INDEX idx_users_email           ON users(email);
CREATE INDEX idx_users_handle          ON users(handle)       WHERE handle IS NOT NULL;
CREATE INDEX idx_users_preferences_gin ON users               USING GIN (preferences);
CREATE INDEX idx_users_embedding       ON users               USING hnsw (embedding vector_cosine_ops) WHERE embedding IS NOT NULL;

-- Workspaces
CREATE INDEX idx_workspaces_slug       ON workspaces(slug)    WHERE deleted_at IS NULL;
CREATE INDEX idx_workspaces_plan       ON workspaces(plan);
CREATE INDEX idx_workspaces_settings   ON workspaces          USING GIN (settings);

-- Membership
CREATE INDEX idx_wm_workspace          ON workspace_members(workspace_id);
CREATE INDEX idx_wm_user               ON workspace_members(user_id);
CREATE INDEX idx_teams_workspace       ON teams(workspace_id);
CREATE INDEX idx_sessions_user         ON user_sessions(user_id);
CREATE INDEX idx_sessions_status       ON user_sessions(status) WHERE status IN ('online','editing','away');
CREATE INDEX idx_api_keys_user         ON api_keys(user_id);
CREATE INDEX idx_api_keys_active       ON api_keys(workspace_id) WHERE revoked_at IS NULL;

-- AI Models
CREATE INDEX idx_ai_models_provider    ON ai_models(provider);
CREATE INDEX idx_ai_models_modality    ON ai_models(modality)  WHERE is_active = TRUE;
CREATE INDEX idx_ai_models_embedding   ON ai_models            USING hnsw (embedding vector_cosine_ops) WHERE embedding IS NOT NULL;
CREATE INDEX idx_model_providers_ws    ON model_providers(workspace_id);

-- Canvas
CREATE INDEX idx_canvas_workspace      ON canvas_graphs(workspace_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_canvas_status         ON canvas_graphs(status)       WHERE deleted_at IS NULL;
CREATE INDEX idx_canvas_tags           ON canvas_graphs               USING GIN (tags);
CREATE INDEX idx_canvas_title_trgm     ON canvas_graphs               USING GIN (title gin_trgm_ops);
CREATE INDEX idx_canvas_embedding      ON canvas_graphs               USING hnsw (embedding vector_cosine_ops) WHERE embedding IS NOT NULL;

-- Nodes & Edges
CREATE INDEX idx_nodes_canvas          ON nodes(canvas_id);
CREATE INDEX idx_nodes_canvas_status   ON nodes(canvas_id, execution_status);
CREATE INDEX idx_node_ports_node       ON node_ports(node_id);
CREATE INDEX idx_node_configs_inputs   ON node_configs                USING GIN (inputs jsonb_path_ops);
CREATE INDEX idx_edges_canvas          ON edges(canvas_id);
CREATE INDEX idx_edges_source          ON edges(source_node_id);
CREATE INDEX idx_edges_target          ON edges(target_node_id);

-- Executions
CREATE INDEX idx_exec_canvas           ON executions(canvas_id, created_at DESC);
CREATE INDEX idx_exec_status           ON executions(status)    WHERE status IN ('pending','queued','running');
CREATE INDEX idx_node_exec_execution   ON node_executions(execution_id, execution_created_at);
CREATE INDEX idx_node_exec_node        ON node_executions(node_id);

-- Assets
CREATE INDEX idx_assets_workspace      ON assets(workspace_id)  WHERE is_deleted = FALSE;
CREATE INDEX idx_assets_type           ON assets(asset_type)    WHERE is_deleted = FALSE;
CREATE INDEX idx_assets_filename_trgm  ON assets                USING GIN (filename gin_trgm_ops);
CREATE INDEX idx_assets_metadata_gin   ON assets                USING GIN (metadata);
CREATE INDEX idx_assets_embedding      ON assets                USING hnsw (prompt_embedding vector_cosine_ops) WHERE prompt_embedding IS NOT NULL;
CREATE INDEX idx_asset_tags_tag        ON asset_tags(tag);

-- Versions & Audit
CREATE INDEX idx_wf_versions_canvas    ON workflow_versions(canvas_id, version_number DESC);
CREATE INDEX idx_asset_versions_asset  ON asset_versions(asset_id,    version_number DESC);
CREATE INDEX idx_audit_workspace       ON audit_log(workspace_id, created_at DESC);
CREATE INDEX idx_audit_entity          ON audit_log(entity_type, entity_id);

-- Templates & Features
CREATE INDEX idx_templates_public      ON templates(is_public, is_featured) WHERE is_public = TRUE;
CREATE INDEX idx_templates_name_trgm   ON templates                USING GIN (name gin_trgm_ops);
CREATE INDEX idx_templates_embedding   ON templates                USING hnsw (embedding vector_cosine_ops) WHERE embedding IS NOT NULL;
CREATE INDEX idx_comments_canvas       ON comments(canvas_id);
CREATE INDEX idx_comments_unresolved   ON comments(canvas_id)      WHERE resolved_at IS NULL;
CREATE INDEX idx_presence_canvas       ON presence_cursors(canvas_id);


-- ============================================================
-- 10. FUNCTIONS & TRIGGERS
-- ============================================================

-- Generic updated_at
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DO $$
DECLARE t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'users','workspaces','teams','ai_models','model_providers',
        'canvas_graphs','nodes','node_configs','assets',
        'templates','published_apps','comments'
    ] LOOP
        EXECUTE format(
            'CREATE TRIGGER trg_%I_updated_at
             BEFORE UPDATE ON %I
             FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at()',
            t, t
        );
    END LOOP;
END;
$$;

-- ── Node counter ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_update_node_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE canvas_graphs SET node_count = node_count + 1 WHERE id = NEW.canvas_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE canvas_graphs SET node_count = GREATEST(node_count - 1, 0) WHERE id = OLD.canvas_id;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_node_count
    AFTER INSERT OR DELETE ON nodes
    FOR EACH ROW EXECUTE FUNCTION fn_update_node_count();

-- ── Edge counter ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_update_edge_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE canvas_graphs SET edge_count = edge_count + 1 WHERE id = NEW.canvas_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE canvas_graphs SET edge_count = GREATEST(edge_count - 1, 0) WHERE id = OLD.canvas_id;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_edge_count
    AFTER INSERT OR DELETE ON edges
    FOR EACH ROW EXECUTE FUNCTION fn_update_edge_count();

-- ── Team member counter ────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_update_team_member_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE teams SET member_count = member_count + 1 WHERE id = NEW.team_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE teams SET member_count = GREATEST(member_count - 1, 0) WHERE id = OLD.team_id;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_team_member_count
    AFTER INSERT OR DELETE ON team_members
    FOR EACH ROW EXECUTE FUNCTION fn_update_team_member_count();

-- ── Auto-snapshot on version bump ─────────────────────────
CREATE OR REPLACE FUNCTION fn_snapshot_workflow_version()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_snapshot JSONB;
BEGIN
    IF OLD.current_version = NEW.current_version THEN RETURN NEW; END IF;

    SELECT jsonb_build_object(
        'canvas', row_to_json(NEW)::jsonb,
        'nodes',  COALESCE((
            SELECT jsonb_agg(n) FROM (
                SELECT nd.*, nc.inputs, nc.model_params
                FROM nodes nd
                LEFT JOIN node_configs nc ON nc.node_id = nd.id
                WHERE nd.canvas_id = NEW.id
            ) n
        ), '[]'::jsonb),
        'edges', COALESCE((
            SELECT jsonb_agg(e) FROM edges e WHERE e.canvas_id = NEW.id
        ), '[]'::jsonb)
    ) INTO v_snapshot;

    INSERT INTO workflow_versions
        (canvas_id, version_number, created_by, snapshot, action)
    VALUES
        (NEW.id, NEW.current_version, NEW.updated_by, v_snapshot, 'updated')
    ON CONFLICT (canvas_id, version_number) DO NOTHING;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_workflow_version_snapshot
    AFTER UPDATE OF current_version ON canvas_graphs
    FOR EACH ROW EXECUTE FUNCTION fn_snapshot_workflow_version();

-- ── Semantic search helpers ────────────────────────────────
CREATE OR REPLACE FUNCTION search_assets_by_prompt(
    p_workspace_id UUID,
    p_embedding    VECTOR(1536),
    p_limit        INTEGER    DEFAULT 20,
    p_threshold    FLOAT      DEFAULT 0.70,
    p_asset_type   asset_type DEFAULT NULL
)
RETURNS TABLE (asset_id UUID, filename VARCHAR, cdn_url TEXT,
               asset_type asset_type, similarity FLOAT)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT a.id, a.filename, a.cdn_url, a.asset_type,
           (1 - (a.prompt_embedding <=> p_embedding))::FLOAT
    FROM assets a
    WHERE a.workspace_id = p_workspace_id
      AND a.is_deleted   = FALSE
      AND a.prompt_embedding IS NOT NULL
      AND (p_asset_type IS NULL OR a.asset_type = p_asset_type)
      AND (1 - (a.prompt_embedding <=> p_embedding)) >= p_threshold
    ORDER BY a.prompt_embedding <=> p_embedding
    LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION search_canvases(
    p_workspace_id UUID,
    p_embedding    VECTOR(1536),
    p_limit        INTEGER DEFAULT 10,
    p_threshold    FLOAT   DEFAULT 0.65
)
RETURNS TABLE (canvas_id UUID, title VARCHAR, similarity FLOAT)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.title,
           (1 - (c.embedding <=> p_embedding))::FLOAT
    FROM canvas_graphs c
    WHERE c.workspace_id = p_workspace_id
      AND c.deleted_at   IS NULL
      AND c.embedding    IS NOT NULL
      AND (1 - (c.embedding <=> p_embedding)) >= p_threshold
    ORDER BY c.embedding <=> p_embedding
    LIMIT p_limit;
END;
$$;

-- ── Restore canvas to previous version ────────────────────
CREATE OR REPLACE FUNCTION restore_canvas_version(
    p_canvas_id   UUID,
    p_version     INTEGER,
    p_restored_by UUID
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_snapshot JSONB;
    v_new_ver  INTEGER;
BEGIN
    SELECT snapshot INTO v_snapshot
    FROM workflow_versions
    WHERE canvas_id = p_canvas_id AND version_number = p_version;

    IF v_snapshot IS NULL THEN
        RAISE EXCEPTION 'Version % not found for canvas %', p_version, p_canvas_id;
    END IF;

    DELETE FROM edges WHERE canvas_id = p_canvas_id;
    DELETE FROM nodes WHERE canvas_id = p_canvas_id;

    INSERT INTO nodes (
        id, canvas_id, position_x, position_y, width, height, z_index,
        category, node_type, node_version, label, color, icon,
        cache_enabled, max_retries, timeout_seconds
    )
    SELECT
        (n->>'id')::UUID, p_canvas_id,
        (n->>'position_x')::FLOAT,   (n->>'position_y')::FLOAT,
        (n->>'width')::FLOAT,        (n->>'height')::FLOAT,
        COALESCE((n->>'z_index')::INT, 0),
        (n->>'category')::node_category,
        n->>'node_type',
        COALESCE(n->>'node_version','1.0.0'),
        n->>'label', n->>'color', n->>'icon',
        COALESCE((n->>'cache_enabled')::BOOLEAN, TRUE),
        COALESCE((n->>'max_retries')::INT, 3),
        COALESCE((n->>'timeout_seconds')::INT, 300)
    FROM jsonb_array_elements(v_snapshot->'nodes') AS n;

    INSERT INTO node_configs (node_id, inputs, model_params)
    SELECT
        (n->>'id')::UUID,
        COALESCE(n->'inputs', '{}'::jsonb),
        COALESCE(n->'model_params', '{}'::jsonb)
    FROM jsonb_array_elements(v_snapshot->'nodes') AS n
    ON CONFLICT (node_id) DO UPDATE
        SET inputs = EXCLUDED.inputs, model_params = EXCLUDED.model_params;

    INSERT INTO edges (
        id, canvas_id, source_node_id, source_port,
        target_node_id, target_port, edge_type, data_type
    )
    SELECT
        (e->>'id')::UUID, p_canvas_id,
        (e->>'source_node_id')::UUID, e->>'source_port',
        (e->>'target_node_id')::UUID, e->>'target_port',
        COALESCE((e->>'edge_type')::edge_type, 'direct'),
        COALESCE((e->>'data_type')::data_type, 'any')
    FROM jsonb_array_elements(v_snapshot->'edges') AS e;

    SELECT COALESCE(MAX(version_number), 0) + 1
    INTO v_new_ver FROM workflow_versions WHERE canvas_id = p_canvas_id;

    UPDATE canvas_graphs
    SET current_version = v_new_ver, updated_by = p_restored_by
    WHERE id = p_canvas_id;

    INSERT INTO workflow_versions
        (canvas_id, version_number, created_by, snapshot, action, change_summary)
    VALUES
        (p_canvas_id, v_new_ver, p_restored_by, v_snapshot, 'restored',
         format('Restored to version %s', p_version));
END;
$$;


-- ============================================================
-- 11. ROW-LEVEL SECURITY
-- ============================================================

ALTER TABLE workspaces    ENABLE ROW LEVEL SECURITY;
ALTER TABLE canvas_graphs ENABLE ROW LEVEL SECURITY;
ALTER TABLE nodes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets        ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log     ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION current_user_id() RETURNS UUID
LANGUAGE sql STABLE AS $$
    SELECT NULLIF(current_setting('app.current_user_id', TRUE), '')::UUID;
$$;

CREATE POLICY pol_workspace_member ON workspaces FOR ALL USING (
    id IN (SELECT workspace_id FROM workspace_members WHERE user_id = current_user_id())
);

CREATE POLICY pol_canvas_member ON canvas_graphs FOR ALL USING (
    workspace_id IN (SELECT workspace_id FROM workspace_members WHERE user_id = current_user_id())
    AND deleted_at IS NULL
);

CREATE POLICY pol_nodes_member ON nodes FOR ALL USING (
    canvas_id IN (
        SELECT id FROM canvas_graphs
        WHERE workspace_id IN (
            SELECT workspace_id FROM workspace_members WHERE user_id = current_user_id()
        ) AND deleted_at IS NULL
    )
);

CREATE POLICY pol_assets_member ON assets FOR ALL USING (
    workspace_id IN (SELECT workspace_id FROM workspace_members WHERE user_id = current_user_id())
    AND is_deleted = FALSE
);

CREATE POLICY pol_audit_read ON audit_log FOR SELECT USING (
    workspace_id IN (SELECT workspace_id FROM workspace_members WHERE user_id = current_user_id())
);

-- ============================================================
-- END OF CORE SCHEMA
-- ============================================================
