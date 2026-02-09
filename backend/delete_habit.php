<?php
require_once "db.php";

// Set headers for CORS and JSON
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

$data = json_decode(file_get_contents("php://input"), true);
$habit_id = $data['habit_id'] ?? null;

if (!$habit_id) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "habit_id required"]);
    exit();
}

// Fetch existing notification_ids before deleting
$sql = "SELECT notification_ids FROM habits WHERE id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $habit_id);
$stmt->execute();
$res = $stmt->get_result();
$row = $res->fetch_assoc();
$old_notification_ids = $row['notification_ids'] ?? null;
$stmt->close();

// Delete the habit
$sql = "DELETE FROM habits WHERE id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $habit_id);

if ($stmt->execute()) {
    echo json_encode([
        "status" => "success",
        "message" => "Habit deleted",
        "notification_ids" => $old_notification_ids
    ]);
} else {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Failed to delete habit"]);
}

$stmt->close();
$conn->close();
?>
