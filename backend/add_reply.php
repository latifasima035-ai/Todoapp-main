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

if (!isset($data['post_id']) || !isset($data['user_id']) || !isset($data['user_email']) || !isset($data['comment_text'])) {
    echo json_encode(['status' => 'error', 'message' => 'Missing required fields']);
    exit;
}

$post_id = intval($data['post_id']);
$user_id = intval($data['user_id']);
$user_email = $data['user_email'];
$comment_text = $data['comment_text'];
$parent_comment_id = isset($data['parent_comment_id']) ? intval($data['parent_comment_id']) : null;

// Insert comment
$sql = "INSERT INTO community_comments (post_id, user_id, user_email, comment_text, parent_comment_id, likes_count, created_at) 
        VALUES (?, ?, ?, ?, ?, 0, NOW())";
$stmt = $conn->prepare($sql);

if ($parent_comment_id) {
    $stmt->bind_param("iissi", $post_id, $user_id, $user_email, $comment_text, $parent_comment_id);
} else {
    $parent_comment_id = null;
    $stmt->bind_param("iisss", $post_id, $user_id, $user_email, $comment_text, $parent_comment_id);
}

if ($stmt->execute()) {
    echo json_encode(['status' => 'success', 'message' => 'Comment added successfully']);
} else {
    echo json_encode(['status' => 'error', 'message' => 'Failed to add comment']);
}

$conn->close();
?>
