CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE submission_status AS ENUM (
    'pending',
    'scanning',
    'approved',
    'rejected'
);

CREATE TABLE apps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    flatpak_id TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    summary TEXT,
    description TEXT,
    developer_name TEXT NOT NULL,
    developer_email TEXT NOT NULL,
    version TEXT NOT NULL,
    category TEXT NOT NULL,
    icon_url TEXT,
    download_url TEXT,
    permissions JSONB NOT NULL DEFAULT '[]',
    status submission_status NOT NULL DEFAULT 'pending',
    scan_passed BOOLEAN,
    scan_report JSONB,
    downloads BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE submission_audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    app_id UUID NOT NULL REFERENCES apps(id),
    action TEXT NOT NULL,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_apps_flatpak_id ON apps(flatpak_id);
CREATE INDEX idx_apps_status ON apps(status);
CREATE INDEX idx_apps_category ON apps(category);
CREATE INDEX idx_audit_app_id ON submission_audit_log(app_id);
