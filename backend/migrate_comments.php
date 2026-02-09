<?php
header('Content-Type: application/json');

$servername = "community-db.cv42ysoe0sqi.eu-north-1.rds.amazonaws.com";
$username = "admin";
$password = "community#123";
$dbname = "community_db";

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die(json_encode(['status' => 'error', 'message' => 'Connection failed: ' . $conn->connect_error]));
}

$results = [];

// 1. Add parent_comment_id column to community_comments if it doesn't exist
$check_parent = "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='community_comments' AND COLUMN_NAME='parent_comment_id'";
$result = $conn->query($check_parent);
if ($result->num_rows === 0) {
    $sql = "ALTER TABLE community_comments ADD COLUMN parent_comment_id INT NULL DEFAULT NULL";
    if ($conn->query($sql)) {
        $results[] = 'Added parent_comment_id column';
    } else {
        $results[] = 'Error adding parent_comment_id: ' . $conn->error;
    }
} else {
    $results[] = 'parent_comment_id column already exists';
}

// 2. Add likes_count column to community_comments if it doesn't exist
$check_likes = "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='community_comments' AND COLUMN_NAME='likes_count'";
$result = $conn->query($check_likes);
if ($result->num_rows === 0) {
    $sql = "ALTER TABLE community_comments ADD COLUMN likes_count INT DEFAULT 0";
    if ($conn->query($sql)) {
        $results[] = 'Added likes_count column';
    } else {
        $results[] = 'Error adding likes_count: ' . $conn->error;
    }
} else {
    $results[] = 'likes_count column already exists';
}

// 3. Create community_comment_likes table if it doesn't exist
$check_table = "SHOW TABLES LIKE 'community_comment_likes'";
$result = $conn->query($check_table);
if ($result->num_rows === 0) {
    $sql = "CREATE TABLE community_comment_likes (
        comment_id INT NOT NULL,
        user_id INT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (comment_id, user_id),
        FOREIGN KEY (comment_id) REFERENCES community_comments(id) ON DELETE CASCADE
    )";
    if ($conn->query($sql)) {
        $results[] = 'Created community_comment_likes table';
    } else {
        $results[] = 'Error creating community_comment_likes: ' . $conn->error;
    }
} else {
    $results[] = 'community_comment_likes table already exists';
}

$conn->close();

echo json_encode([
    'status' => 'success',
    'message' => 'Database migration completed',
    'results' => $results
]);
?>
