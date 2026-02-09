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

// Check if already liked
$check_sql = "SELECT id FROM community_comment_likes WHERE comment_id = ? AND user_id = ?";
$check_stmt = $conn->prepare($check_sql);
$check_stmt->bind_param("ii", $comment_id, $user_id);
$check_stmt->execute();
$check_result = $check_stmt->get_result();

if ($check_result->num_rows > 0) {
    // Already liked, remove like
    $delete_sql = "DELETE FROM community_comment_likes WHERE comment_id = ? AND user_id = ?";
    $delete_stmt = $conn->prepare($delete_sql);
    $delete_stmt->bind_param("ii", $comment_id, $user_id);
    $delete_stmt->execute();
    
    // Update comment likes count
    $update_sql = "UPDATE community_comments SET likes_count = likes_count - 1 WHERE id = ?";
    $update_stmt = $conn->prepare($update_sql);
    $update_stmt->bind_param("i", $comment_id);
    $update_stmt->execute();
    
    // Get updated likes count
    $get_sql = "SELECT likes_count FROM community_comments WHERE id = ?";
    $get_stmt = $conn->prepare($get_sql);
    $get_stmt->bind_param("i", $comment_id);
    $get_stmt->execute();
    $get_result = $get_stmt->get_result();
    $get_row = $get_result->fetch_assoc();
    
    echo json_encode(['status' => 'success', 'message' => 'Like removed', 'likes_count' => $get_row['likes_count']]);
} else {
    // Add like
    $insert_sql = "INSERT INTO community_comment_likes (comment_id, user_id, created_at) VALUES (?, ?, NOW())";
    $insert_stmt = $conn->prepare($insert_sql);
    $insert_stmt->bind_param("ii", $comment_id, $user_id);
    $insert_stmt->execute();
    
    // Update comment likes count
    $update_sql = "UPDATE community_comments SET likes_count = likes_count + 1 WHERE id = ?";
    $update_stmt = $conn->prepare($update_sql);
    $update_stmt->bind_param("i", $comment_id);
    $update_stmt->execute();
    
    // Get updated likes count
    $get_sql = "SELECT likes_count FROM community_comments WHERE id = ?";
    $get_stmt = $conn->prepare($get_sql);
    $get_stmt->bind_param("i", $comment_id);
    $get_stmt->execute();
    $get_result = $get_stmt->get_result();
    $get_row = $get_result->fetch_assoc();
    
    echo json_encode(['status' => 'success', 'message' => 'Like added', 'likes_count' => $get_row['likes_count']]);
}

$conn->close();
?>
