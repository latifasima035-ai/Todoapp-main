<?php
require_once "db.php";

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type');

$habit_id = $_GET['habit_id'] ?? null;
$user_id = $_GET['user_id'] ?? null;

if (!$habit_id || !$user_id) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "habit_id and user_id required"]);
    exit();
}

// Get habit details (frequency, target_count)
$sql = "SELECT frequency_type, target_count FROM habits WHERE id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $habit_id);
$stmt->execute();
$res = $stmt->get_result();
if (!$row = $res->fetch_assoc()) {
    echo json_encode(["status" => "error", "message" => "Habit not found"]);
    exit();
}
$frequency = $row['frequency_type'];
$target = intval($row['target_count'] ?? 1);
$stmt->close();

// Compute completed_count based on frequency
if ($frequency === 'daily') {
    $sql = "SELECT COUNT(*) as cnt FROM habit_logs WHERE habit_id = ? AND user_id = ? AND completed_at = CURDATE()";
} else if ($frequency === 'weekly') {
    // Use YEARWEEK with mode 1 (Monday start)
    $sql = "SELECT COUNT(*) as cnt FROM habit_logs WHERE habit_id = ? AND user_id = ? AND YEARWEEK(completed_at,1) = YEARWEEK(CURDATE(),1)";
} else {
    // monthly or default
    $sql = "SELECT COUNT(*) as cnt FROM habit_logs WHERE habit_id = ? AND user_id = ? AND MONTH(completed_at) = MONTH(CURDATE()) AND YEAR(completed_at) = YEAR(CURDATE())";
}

$stmt = $conn->prepare($sql);
$stmt->bind_param("ii", $habit_id, $user_id);
$stmt->execute();
$res = $stmt->get_result();
$row = $res->fetch_assoc();
$count = intval($row['cnt'] ?? 0);
$stmt->close();

$progress = $target > 0 ? round($count / $target, 4) : 0;

echo json_encode([
    "status" => "success",
    "habit_id" => intval($habit_id),
    "completed_count" => $count,
    "target_count" => $target,
    "progress" => $progress
]);

$conn->close();
?>
