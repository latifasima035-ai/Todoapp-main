<?php
require_once "db.php";

// Set headers for CORS and JSON
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

$data = json_decode(file_get_contents("php://input"), true);

$habit_id       = $data['habit_id'] ?? null;
$habit_name     = $data['habit_name'] ?? null;
$category       = $data['category'] ?? null;
$frequency_type = $data['frequency_type'] ?? null;
$quantity       = $data['quantity'] ?? null;
$reminder_time  = $data['reminder_time'] ?? null;
$reminder_days  = $data['reminder_days'] ?? null;
$target_count   = $data['target_count'] ?? 1;
$icon_name      = $data['icon_name'] ?? 'directions_walk';

if (!$habit_id || !$habit_name) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Required fields missing"]);
    exit();
}

// Fetch old notification_ids before update
$sql = "SELECT notification_ids FROM habits WHERE id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $habit_id);
$stmt->execute();
$res = $stmt->get_result();
$row = $res->fetch_assoc();
$old_notification_ids = $row['notification_ids'] ?? null;
$stmt->close();

// Update habit
$sql = "UPDATE habits SET habit_name = ?, category = ?, frequency_type = ?, target_count = ?, quantity = ?, reminder_time = ?, reminder_days = ?, icon_name = ? WHERE id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("sssiisssi", $habit_name, $category, $frequency_type, $target_count, $quantity, $reminder_time, $reminder_days, $icon_name, $habit_id);

if ($stmt->execute()) {
    // Fetch the updated target_count to confirm
    $sql2 = "SELECT target_count FROM habits WHERE id = ?";
    $stmt2 = $conn->prepare($sql2);
    $stmt2->bind_param("i", $habit_id);
    $stmt2->execute();
    $res2 = $stmt2->get_result();
    $row2 = $res2->fetch_assoc();
    $stored_target = intval($row2['target_count'] ?? 1);
    $stmt2->close();

    echo json_encode([
        "status" => "success",
        "message" => "Habit updated successfully",
        "habit_id" => $habit_id,
        "old_notification_ids" => $old_notification_ids,
        "stored_target_count" => $stored_target
    ]);
} else {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Failed to update habit: " . $stmt->error]);
}

$stmt->close();
$conn->close();
?>
