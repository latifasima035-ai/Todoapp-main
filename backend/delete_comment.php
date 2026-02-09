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

if (!isset($data['comment_id']) || !isset($data['user_id'])) {
    echo json_encode(['status' => 'error', 'message' => 'Missing comment_id or user_id']);
    exit;
}

$comment_id = intval($data['comment_id']);
$user_id = intval($data['user_id']);

// Verify comment exists and user owns it or is post owner
$check_sql = "SELECT c.user_id, c.post_id FROM community_comments c WHERE c.id = ?";
$check_stmt = $conn->prepare($check_sql);
$check_stmt->bind_param("i", $comment_id);
$check_stmt->execute();
$check_result = $check_stmt->get_result();

if ($check_result->num_rows === 0) {
    echo json_encode(['status' => 'error', 'message' => 'Comment not found']);
    exit;
}

$comment = $check_result->fetch_assoc();

// Check if user is comment owner or post owner
$post_owner_sql = "SELECT user_id FROM community_posts WHERE id = ?";
$post_stmt = $conn->prepare($post_owner_sql);
$post_stmt->bind_param("i", $comment['post_id']);
$post_stmt->execute();
$post_result = $post_stmt->get_result();
$post = $post_result->fetch_assoc();

if ($comment['user_id'] != $user_id && $post['user_id'] != $user_id) {
    echo json_encode(['status' => 'error', 'message' => 'You can only delete your own comments or comments on your posts']);
    exit;
}

// Delete comment likes first
$delete_likes_sql = "DELETE FROM community_comment_likes WHERE comment_id = ?";
$delete_likes_stmt = $conn->prepare($delete_likes_sql);
$delete_likes_stmt->bind_param("i", $comment_id);
$delete_likes_stmt->execute();

// Delete the comment
$delete_sql = "DELETE FROM community_comments WHERE id = ?";
$delete_stmt = $conn->prepare($delete_sql);
$delete_stmt->bind_param("i", $comment_id);

if ($delete_stmt->execute()) {
    echo json_encode(['status' => 'success', 'message' => 'Comment deleted successfully']);
} else {
    echo json_encode(['status' => 'error', 'message' => 'Failed to delete comment']);
}

$conn->close();
?>
