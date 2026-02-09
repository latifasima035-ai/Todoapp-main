<?php
$host = "community-db.cv42ysoe0sqi.eu-north-1.rds.amazonaws.com";
$db   = "community_db";
$user = "admin";
$pass = "community#123";

$conn = new mysqli($host, $user, $pass, $db, 3306);
if ($conn->connect_error) {
    die("❌ Connection FAILED: " . $conn->connect_error);
}

echo "✅ Connected to database '$db'<br><br>";

// 1️⃣ Create community_posts table
$sql_posts = "
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

if ($conn->query($sql_posts) === TRUE) {
    echo "✅ Table 'community_posts' created successfully<br>";
} else {
    echo "⚠️ Error creating 'community_posts': " . $conn->error . "<br>";
}

// 2️⃣ Create community_comments table
$sql_comments = "
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

if ($conn->query($sql_comments) === TRUE) {
    echo "✅ Table 'community_comments' created successfully<br>";
} else {
    echo "⚠️ Error creating 'community_comments': " . $conn->error . "<br>";
}

// 3️⃣ Create community_likes table
$sql_likes = "
CREATE TABLE IF NOT EXISTS community_likes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_post_user (post_id, user_id),
    FOREIGN KEY(post_id) REFERENCES community_posts(id) ON DELETE CASCADE,
    INDEX(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

if ($conn->query($sql_likes) === TRUE) {
    echo "✅ Table 'community_likes' created successfully<br>";
} else {
    echo "⚠️ Error creating 'community_likes': " . $conn->error . "<br>";
}

echo "<br><strong>✅ All tables created successfully!</strong><br>";

// Test queries
echo "<br><strong>Test Queries:</strong><br>";
echo "1. SELECT * FROM community_posts ORDER BY created_at DESC;<br>";
echo "2. SELECT * FROM community_comments WHERE post_id = 1;<br>";
echo "3. SELECT * FROM community_likes WHERE post_id = 1;<br>";

$conn->close();
?>
