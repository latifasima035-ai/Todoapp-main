<?php
require_once "db.php";

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

// Get JSON data from Flutter
$data = json_decode(file_get_contents("php://input"), true);

$user_id        = $data['user_id'] ?? null;
$habit_name     = $data['habit_name'] ?? null;
$category       = $data['category'] ?? null;
$frequency_type = $data['frequency_type'] ?? null;
$quantity       = $data['quantity'] ?? null;
$reminder_time  = $data['reminder_time'] ?? null;
$reminder_days  = $data['reminder_days'] ?? null;
$target_count   = $data['target_count'] ?? 1;
$icon_name      = $data['icon_name'] ?? 'directions_walk';

// Check required fields
if (!$user_id || !$habit_name) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "Required fields missing"
    ]);
    exit();
}

// Insert into habits table including target_count, reminder_days, and icon_name
$sql = "INSERT INTO habits
        (user_id, habit_name, category, frequency_type, target_count, quantity, reminder_time, reminder_days, icon_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";

$stmt = $conn->prepare($sql);
if (!$stmt) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Prepare failed: " . $conn->error
    ]);
    exit();
}
$stmt->bind_param(
    "isssiisss",
    $user_id,
    $habit_name,
    $category,
    $frequency_type,
    $target_count,
    $quantity,
    $reminder_time,
    $reminder_days,
    $icon_name
);

// Execute and respond
if ($stmt->execute()) {
    // Get the inserted habit ID - CRITICAL for notifications!
    $habit_id = $conn->insert_id;

    // Fetch stored target_count to confirm what was saved
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
        "message" => "Habit added successfully",
        "habit_id" => $habit_id,
        "stored_target_count" => $stored_target
    ]);
} else {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Failed to add habit: " . $stmt->error
    ]);
}

$stmt->close();
$conn->close();
?>
