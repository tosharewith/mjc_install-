-- MMJC Database Initialization Script
-- Database: mmjc
-- PostgreSQL Version: 16.x
--
-- This script initializes the database for the MMJC application suite
-- including tables required by:
-- - mmjc-agents (LangGraph)
-- - mmjc-po
-- - mmjc-frontend
-- - Other MMJC services

-- ============================================================================
-- 1. EXTENSIONS
-- ============================================================================
-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable JSONB operations
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- ============================================================================
-- 2. LANGGRAPH CHECKPOINTS TABLE
-- ============================================================================
-- Required for mmjc-agents service (LangGraph state persistence)

CREATE TABLE IF NOT EXISTS checkpoints (
    thread_id TEXT NOT NULL,
    checkpoint_ns TEXT NOT NULL DEFAULT '',
    checkpoint_id TEXT NOT NULL,
    parent_checkpoint_id TEXT,
    type TEXT,
    checkpoint JSONB NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (thread_id, checkpoint_ns, checkpoint_id)
);

-- Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_checkpoints_thread_id
    ON checkpoints (thread_id);

CREATE INDEX IF NOT EXISTS idx_checkpoints_parent
    ON checkpoints (parent_checkpoint_id)
    WHERE parent_checkpoint_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_checkpoints_created_at
    ON checkpoints (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_checkpoints_metadata_gin
    ON checkpoints USING gin (metadata);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_checkpoints_updated_at
    BEFORE UPDATE ON checkpoints
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE checkpoints IS 'LangGraph agent state checkpoints for conversation persistence';

-- ============================================================================
-- 3. APPLICATION TABLES
-- ============================================================================
-- Add other application-specific tables here as needed

-- Example: User sessions table
-- CREATE TABLE IF NOT EXISTS user_sessions (
--     session_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--     user_id TEXT NOT NULL,
--     created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
--     expires_at TIMESTAMP WITH TIME ZONE,
--     metadata JSONB DEFAULT '{}'
-- );

-- ============================================================================
-- 4. PERMISSIONS
-- ============================================================================
-- Grant appropriate permissions to application users
-- Replace 'ibm_cloud_971c0f4f_db43_4a27_9d6b_45d548902957' with your actual username

-- GRANT SELECT, INSERT, UPDATE, DELETE ON checkpoints TO ibm_cloud_971c0f4f_db43_4a27_9d6b_45d548902957;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ibm_cloud_971c0f4f_db43_4a27_9d6b_45d548902957;

-- ============================================================================
-- 5. MAINTENANCE FUNCTIONS
-- ============================================================================

-- Function to cleanup old checkpoints (recommended to run periodically)
CREATE OR REPLACE FUNCTION cleanup_old_checkpoints(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM checkpoints
    WHERE created_at < NOW() - (days_to_keep || ' days')::INTERVAL;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_checkpoints IS 'Deletes checkpoints older than specified days (default: 30)';

-- Example usage:
-- SELECT cleanup_old_checkpoints(30);  -- Remove checkpoints older than 30 days

-- ============================================================================
-- 6. VERIFICATION QUERIES
-- ============================================================================

-- Verify table creation
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'checkpoints') THEN
        RAISE NOTICE '✓ checkpoints table created successfully';
    ELSE
        RAISE WARNING '✗ checkpoints table NOT created';
    END IF;
END $$;

-- Display table information
SELECT
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count,
    pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) as total_size
FROM information_schema.tables t
WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE'
ORDER BY table_name;
