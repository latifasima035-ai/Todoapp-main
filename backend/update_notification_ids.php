<?php
require_once "db.php";

// Set headers for CORS and JSON
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

// Get JSON data from Flutter
$data = json_decode(file_get_contents("php://input"), true);

$habit_id = $data['habit_id'] ?? null;
$notification_ids = $data['notification_ids'] ?? null;

// Check required fields
if (!$habit_id || !$notification_ids) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "Required fields missing (habit_id, notification_ids)"
    ]);
    exit();
}

// Update the habit with notification IDs
$sql = "UPDATE habits SET notification_ids = ? WHERE id = ?";

$stmt = $conn->prepare($sql);
$stmt->bind_param("si", $notification_ids, $habit_id);

// Execute and respond
if ($stmt->execute()) {
    echo json_encode([
        "status" => "success",
        "message" => "Notification IDs updated successfully"
    ]);
} else {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Failed to update notification IDs: " . $stmt->error
    ]);
}

$stmt->close();
$conn->close();
?>
