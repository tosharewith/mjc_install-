-- LangGraph Checkpoints Table Schema
-- Required for mmjc-agents service (LangGraph state persistence)
-- Database: mmjc
-- Compatible with: PostgreSQL 16.x

-- Create checkpoints table for LangGraph state management
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

-- Create index for efficient querying
CREATE INDEX IF NOT EXISTS idx_checkpoints_thread_id
    ON checkpoints (thread_id);

CREATE INDEX IF NOT EXISTS idx_checkpoints_parent
    ON checkpoints (parent_checkpoint_id)
    WHERE parent_checkpoint_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_checkpoints_created_at
    ON checkpoints (created_at DESC);

-- Create trigger to update updated_at timestamp
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

-- Grant permissions (adjust username as needed)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON checkpoints TO your_app_user;

-- Cleanup old checkpoints (optional - run periodically)
-- DELETE FROM checkpoints
-- WHERE created_at < NOW() - INTERVAL '30 days';

COMMENT ON TABLE checkpoints IS 'LangGraph agent state checkpoints for conversation persistence';
COMMENT ON COLUMN checkpoints.thread_id IS 'Unique identifier for conversation thread';
COMMENT ON COLUMN checkpoints.checkpoint_ns IS 'Namespace for organizing checkpoints';
COMMENT ON COLUMN checkpoints.checkpoint_id IS 'Unique identifier for this checkpoint';
COMMENT ON COLUMN checkpoints.parent_checkpoint_id IS 'Reference to parent checkpoint';
COMMENT ON COLUMN checkpoints.checkpoint IS 'Serialized checkpoint data';
COMMENT ON COLUMN checkpoints.metadata IS 'Additional metadata for the checkpoint';
