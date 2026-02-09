-- ===================================================
-- COMMUNITY WALL DATABASE TABLES
-- ===================================================

-- Community Posts Table
CREATE TABLE IF NOT EXISTS community_posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    user_email VARCHAR(255) NOT NULL,
    content LONGTEXT NOT NULL,
    image_url VARCHAR(500),
    likes_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX(user_id),
    INDEX(created_at)
);

-- Community Comments Table
CREATE TABLE IF NOT EXISTS community_comments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    user_email VARCHAR(255) NOT NULL,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(post_id) REFERENCES community_posts(id) ON DELETE CASCADE,
    INDEX(post_id),
    INDEX(user_id),
    INDEX(created_at)
);

-- Community Likes Table
CREATE TABLE IF NOT EXISTS community_likes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_post_user (post_id, user_id),
    FOREIGN KEY(post_id) REFERENCES community_posts(id) ON DELETE CASCADE,
    INDEX(user_id)
);

-- ===================================================
-- QUERIES TO CHECK
-- ===================================================
-- SELECT * FROM community_posts ORDER BY created_at DESC;
-- SELECT * FROM community_comments WHERE post_id = 1;
-- SELECT * FROM community_likes WHERE post_id = 1;
