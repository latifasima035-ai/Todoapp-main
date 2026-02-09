<?php
require_once "db.php";

// Set headers for CORS and JSON
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type');

$user_id = $_GET['user_id'] ?? null;

if (!$user_id) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "User ID required"
    ]);
    exit();
}

// Select all fields including id, target_count, notification_ids and icon_name
$sql = "SELECT id, habit_name, category, frequency_type, target_count, quantity, reminder_time, reminder_days, notification_ids, icon_name
    FROM habits WHERE user_id = ?";

$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $user_id);
$stmt->execute();

$result = $stmt->get_result();
$habits = [];

while ($row = $result->fetch_assoc()) {
    $habits[] = $row;
}

if (count($habits) > 0) {
    echo json_encode([
        "status" => "success",
        "data" => $habits,
        "message" => "Habits retrieved successfully"
    ]);
} else {
    echo json_encode([
        "status" => "success",
        "data" => [],
        "message" => "No habits found for this user"
    ]);
}

$stmt->close();
$conn->close();
?>
