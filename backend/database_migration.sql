-- ===================================================
-- DATABASE MIGRATION FOR HABIT TRACKER
-- Add notification_ids column to habits table
-- ===================================================

-- Run this SQL command on your database to add the notification_ids column
-- This column will store the notification IDs as JSON text

ALTER TABLE habits
ADD COLUMN notification_ids TEXT DEFAULT NULL;

-- Add target_count to habits (how many times per period)
ALTER TABLE habits
ADD COLUMN target_count INT DEFAULT 1;

-- Add icon_name to habits table to store selected icon
ALTER TABLE habits
ADD COLUMN icon_name VARCHAR(50) DEFAULT 'directions_walk';

-- Create habit_logs table to track completions
-- Drop existing habit_logs so we recreate with the intended schema
DROP TABLE IF EXISTS habit_logs;

-- Create habit_logs table to track completions
CREATE TABLE habit_logs (
	id INT AUTO_INCREMENT PRIMARY KEY,
	habit_id INT NOT NULL,
	user_id INT NOT NULL,
	completed_at DATE NOT NULL,
	completed_at_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	INDEX(habit_id),
	INDEX(user_id),
	INDEX(completed_at),
	CONSTRAINT unique_daily_habit UNIQUE KEY (habit_id, user_id, completed_at)
);

-- Verify the column was added
-- Run this to check:
-- DESCRIBE habits;

-- Expected output should show a new column:
-- notification_ids | TEXT | YES | NULL

-- ===================================================
-- NOTES:
-- - The notification_ids column stores JSON data as TEXT
-- - Example value: {"monday":1230,"tuesday":1231,"friday":1234}
-- - This allows the app to cancel specific notifications when needed
-- ===================================================
