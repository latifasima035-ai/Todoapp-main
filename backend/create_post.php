<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

// Database connection
$servername = "community-db.cv42ysoe0sqi.eu-north-1.rds.amazonaws.com";
$username = "admin";
$password = "community#123";
$dbname = "community_db";

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die(json_encode(['status' => 'error', 'message' => 'Connection failed: ' . $conn->connect_error]));
}

$data = json_decode(file_get_contents("php://input"), true);

if (!$data || !isset($data['user_id']) || !isset($data['user_email']) || !isset($data['content'])) {
    echo json_encode(['status' => 'error', 'message' => 'Missing required fields']);
    exit;
}

$user_id = intval($data['user_id']);
$user_email = $conn->real_escape_string($data['user_email']);
$content = $conn->real_escape_string($data['content']);
$image_url = isset($data['image_url']) ? $conn->real_escape_string($data['image_url']) : null;

$sql = "INSERT INTO community_posts (user_id, user_email, content, image_url, likes_count)
        VALUES ($user_id, '$user_email', '$content', " . ($image_url ? "'$image_url'" : "NULL") . ", 0)";

if ($conn->query($sql) === TRUE) {
    $post_id = $conn->insert_id;
    echo json_encode([
        'status' => 'success',
        'message' => 'Post created successfully',
        'post_id' => $post_id
    ]);
} else {
    echo json_encode(['status' => 'error', 'message' => 'Failed to create post: ' . $conn->error]);
}

$conn->close();
?>
