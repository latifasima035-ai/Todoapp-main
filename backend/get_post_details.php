<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');

$servername = "community-db.cv42ysoe0sqi.eu-north-1.rds.amazonaws.com";
$username = "admin";
$password = "community#123";
$dbname = "community_db";

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die(json_encode(['status' => 'error', 'message' => 'Connection failed: ' . $conn->connect_error]));
}

if (!isset($_GET['post_id'])) {
    echo json_encode(['status' => 'error', 'message' => 'Missing post_id']);
    exit;
}

$post_id = intval($_GET['post_id']);
$user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;

// Get post using prepared statement
$post_query = "SELECT id, user_id, user_email, content, image_url, likes_count, created_at FROM community_posts WHERE id = ?";
$post_stmt = $conn->prepare($post_query);
$post_stmt->bind_param("i", $post_id);
$post_stmt->execute();
$post_result = $post_stmt->get_result();

if ($post_result->num_rows === 0) {
    echo json_encode(['status' => 'error', 'message' => 'Post not found']);
    exit;
}

$post = $post_result->fetch_assoc();

// Get comments using prepared statement - with parent_comment_id for replies
$comments_query = "SELECT id, user_id, user_email, comment_text, parent_comment_id, COALESCE(likes_count, 0) as likes_count, created_at FROM community_comments WHERE post_id = ? ORDER BY created_at ASC";
$comments_stmt = $conn->prepare($comments_query);
$comments_stmt->bind_param("i", $post_id);
$comments_stmt->execute();
$comments_result = $comments_stmt->get_result();
$comments = [];

while ($row = $comments_result->fetch_assoc()) {
    // Check if this comment is liked by current user
    if ($user_id > 0) {
        $like_check = "SELECT COUNT(*) as cnt FROM community_comment_likes WHERE comment_id = ? AND user_id = ?";
        $like_stmt = $conn->prepare($like_check);
        $like_stmt->bind_param("ii", $row['id'], $user_id);
        $like_stmt->execute();
        $like_result = $like_stmt->get_result();
        $like_row = $like_result->fetch_assoc();
        $row['is_liked'] = ($like_row['cnt'] > 0) ? 1 : 0;
        $like_stmt->close();
    } else {
        $row['is_liked'] = 0;
    }
    $comments[] = $row;
}

echo json_encode([
    'status' => 'success',
    'post' => $post,
    'comments' => $comments,
    'comments_count' => count($comments)
]);

$conn->close();
?>
