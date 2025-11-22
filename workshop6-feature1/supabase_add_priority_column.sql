-- Add priority column to clients table in Supabase
-- Run this in your Supabase SQL Editor

ALTER TABLE clients 
ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'normal';

-- Optional: Add a check constraint to ensure only valid priority values
ALTER TABLE clients 
ADD CONSTRAINT check_priority 
CHECK (priority IN ('normal', 'urgent', 'vip'));

-- Optional: Update existing rows to have 'normal' priority if they don't have one
UPDATE clients 
SET priority = 'normal' 
WHERE priority IS NULL;

