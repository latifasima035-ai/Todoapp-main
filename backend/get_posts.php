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
    die(json_encode(['status' => 'error', 'message' => 'Connection failed']));
}

$page = isset($_GET['page']) ? intval($_GET['page']) : 1;
$user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
$limit = 10;
$offset = ($page - 1) * $limit;

// Get total posts count
$count_query = "SELECT COUNT(*) as total FROM community_posts";
$count_result = $conn->query($count_query);
$total = $count_result->fetch_assoc()['total'];

// Get posts with comments count and like status using prepared statement
$sql = "SELECT p.id, p.user_id, p.user_email, p.content, p.image_url, p.likes_count, 
               p.created_at, COUNT(DISTINCT c.id) as comments_count,
               CASE WHEN l.user_id = ? THEN 1 ELSE 0 END as is_liked
        FROM community_posts p
        LEFT JOIN community_comments c ON p.id = c.post_id
        LEFT JOIN community_likes l ON p.id = l.post_id AND l.user_id = ?
        GROUP BY p.id, p.user_id, p.user_email, p.content, p.image_url, p.likes_count, p.created_at
        ORDER BY p.created_at DESC
        LIMIT ? OFFSET ?";

$stmt = $conn->prepare($sql);
$stmt->bind_param("iiii", $user_id, $user_id, $limit, $offset);
$stmt->execute();
$result = $stmt->get_result();
$posts = [];

while ($row = $result->fetch_assoc()) {
    $posts[] = $row;
}

echo json_encode([
    'status' => 'success',
    'posts' => $posts,
    'total' => $total,
    'page' => $page,
    'has_more' => ($offset + $limit) < $total
]);

$conn->close();
?>
