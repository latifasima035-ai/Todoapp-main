-- ===================================================
-- ADD STEP TARGET SUPPORT TO HABITS
-- ===================================================

-- Add step_target column to habits table (if not exists)
-- This stores the number of steps needed to auto-complete the habit
ALTER TABLE habits
ADD COLUMN step_target INT DEFAULT 5000;

-- Example: A "Walk" habit might need 5000 steps
-- An "Exercise" habit might need 10000 steps

-- Query to check:
-- SELECT id, habit_name, quantity, step_target FROM habits;

-- ===================================================
-- NOTES:
-- - step_target is in steps (e.g., 5000 steps)
-- - If step_target = 0, the habit won't auto-complete from steps
-- - You can set step_target per habit based on its purpose
-- ===================================================
