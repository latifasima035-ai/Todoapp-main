<?php
header('Content-Type: application/json');

$host = 'community-db.cv42ysoe0sqi.eu-north-1.rds.amazonaws.com';
$user = 'admin';
$password = 'community#123';
$database = 'community_db';

$conn = new mysqli($host, $user, $password, $database);

if ($conn->connect_error) {
    die(json_encode(['status' => 'error', 'message' => 'Connection failed: ' . $conn->connect_error]));
}

$data = json_decode(file_get_contents("php://input"), true);

if (!isset($data['post_id']) || !isset($data['user_id'])) {
    echo json_encode(['status' => 'error', 'message' => 'Missing post_id or user_id']);
    exit;
}

$post_id = intval($data['post_id']);
$user_id = intval($data['user_id']);

// Verify that the user owns this post
$check_sql = "SELECT user_id FROM community_posts WHERE id = ?";
$check_stmt = $conn->prepare($check_sql);
$check_stmt->bind_param("i", $post_id);
$check_stmt->execute();
$check_result = $check_stmt->get_result();

if ($check_result->num_rows === 0) {
    echo json_encode(['status' => 'error', 'message' => 'Post not found']);
    exit;
}

$post = $check_result->fetch_assoc();
if ($post['user_id'] != $user_id) {
    echo json_encode(['status' => 'error', 'message' => 'You can only delete your own posts']);
    exit;
}

// Delete comments associated with this post
$delete_comments_sql = "DELETE FROM community_comments WHERE post_id = ?";
$delete_comments_stmt = $conn->prepare($delete_comments_sql);
$delete_comments_stmt->bind_param("i", $post_id);
$delete_comments_stmt->execute();

// Delete likes associated with this post
$delete_likes_sql = "DELETE FROM community_likes WHERE post_id = ?";
$delete_likes_stmt = $conn->prepare($delete_likes_sql);
$delete_likes_stmt->bind_param("i", $post_id);
$delete_likes_stmt->execute();

// Delete the post
$delete_sql = "DELETE FROM community_posts WHERE id = ? AND user_id = ?";
$delete_stmt = $conn->prepare($delete_sql);
$delete_stmt->bind_param("ii", $post_id, $user_id);

if ($delete_stmt->execute()) {
    echo json_encode(['status' => 'success', 'message' => 'Post deleted successfully']);
} else {
    echo json_encode(['status' => 'error', 'message' => 'Failed to delete post']);
}

$conn->close();
?>
