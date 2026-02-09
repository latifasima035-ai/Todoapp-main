-- ===================================================
-- DATABASE MIGRATION FOR STEP COUNTER FEATURE
-- Create tables for daily step tracking
-- ===================================================

-- Create step_targets table (stores user's daily step goals)
CREATE TABLE IF NOT EXISTS step_targets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    target_date DATE NOT NULL,
    target_steps INT NOT NULL DEFAULT 5000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_user_date (user_id, target_date),
    INDEX(user_id),
    INDEX(target_date)
);

-- Create step_logs table (stores daily step counts from sensor/manual entry)
CREATE TABLE IF NOT EXISTS step_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    log_date DATE NOT NULL,
    steps INT NOT NULL DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_user_log_date (user_id, log_date),
    INDEX(user_id),
    INDEX(log_date)
);

-- ===================================================
-- NOTES:
-- - step_targets: Stores the daily goal (e.g., 6000 steps today)
-- - step_logs: Stores actual steps completed each day
-- - Both tables use DATE (YYYY-MM-DD) for daily grouping
-- - is_completed flag marks when user reaches target
-- ===================================================
