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

if (!$data || !isset($data['post_id']) || !isset($data['user_id'])) {
    echo json_encode(['status' => 'error', 'message' => 'Missing required fields']);
    exit;
}

$post_id = intval($data['post_id']);
$user_id = intval($data['user_id']);

// Check if already liked
$check_query = "SELECT id FROM community_likes WHERE post_id = $post_id AND user_id = $user_id";
$check_result = $conn->query($check_query);

if ($check_result->num_rows > 0) {
    // Already liked, remove like
    $delete_sql = "DELETE FROM community_likes WHERE post_id = $post_id AND user_id = $user_id";
    $conn->query($delete_sql);
    
    // Update likes count
    $update_sql = "UPDATE community_posts SET likes_count = likes_count - 1 WHERE id = $post_id";
    $conn->query($update_sql);
    
    echo json_encode(['status' => 'success', 'action' => 'unlike']);
} else {
    // Add like
    $created_at = date('Y-m-d H:i:s');
    $insert_sql = "INSERT INTO community_likes (post_id, user_id, created_at) VALUES ($post_id, $user_id, '$created_at')";
    
    if ($conn->query($insert_sql) === TRUE) {
        // Update likes count
        $update_sql = "UPDATE community_posts SET likes_count = likes_count + 1 WHERE id = $post_id";
        $conn->query($update_sql);
        
        echo json_encode(['status' => 'success', 'action' => 'like']);
    } else {
        echo json_encode(['status' => 'error', 'message' => 'Error: ' . $conn->error]);
    }
}

$conn->close();
?>
