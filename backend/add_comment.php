<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

$servername = "community-db.cv42ysoe0sqi.eu-north-1.rds.amazonaws.com";
$username = "admin";
$password = "community#123";
$dbname = "community_db";

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die(json_encode(['status' => 'error', 'message' => 'Connection failed']));
}

$data = json_decode(file_get_contents("php://input"), true);

if (!$data || !isset($data['post_id']) || !isset($data['user_id']) || !isset($data['user_email']) || !isset($data['comment_text'])) {
    echo json_encode(['status' => 'error', 'message' => 'Missing required fields']);
    exit;
}

$post_id = intval($data['post_id']);
$user_id = intval($data['user_id']);
$user_email = $data['user_email'];
$comment_text = $data['comment_text'];
$parent_comment_id = isset($data['parent_comment_id']) ? intval($data['parent_comment_id']) : null;

// Use prepared statement for security
if ($parent_comment_id === null) {
    $stmt = $conn->prepare("INSERT INTO community_comments (post_id, user_id, user_email, comment_text) VALUES (?, ?, ?, ?)");
    $stmt->bind_param("iiss", $post_id, $user_id, $user_email, $comment_text);
} else {
    $stmt = $conn->prepare("INSERT INTO community_comments (post_id, user_id, user_email, comment_text, parent_comment_id) VALUES (?, ?, ?, ?, ?)");
    $stmt->bind_param("iissi", $post_id, $user_id, $user_email, $comment_text, $parent_comment_id);
}

if ($stmt->execute()) {
    $comment_id = $stmt->insert_id;
    echo json_encode([
        'status' => 'success',
        'message' => 'Comment added successfully',
        'comment_id' => $comment_id
    ]);
} else {
    echo json_encode(['status' => 'error', 'message' => 'Failed to add comment: ' . $stmt->error]);
}

$stmt->close();
$conn->close();
?>
