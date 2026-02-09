<?php
require_once "db.php";

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

$data = json_decode(file_get_contents("php://input"), true);
$habit_id = $data['habit_id'] ?? null;
$user_id = $data['user_id'] ?? null;
$date = $data['date'] ?? null; // optional, YYYY-MM-DD

// Debug: Log what was received
error_log("Raw input: " . file_get_contents("php://input"));
error_log("Decoded data: " . json_encode($data));
error_log("habit_id: $habit_id, user_id: $user_id, date: $date");

if (!$habit_id || !$user_id) {
    http_response_code(400);
    echo json_encode([
        "status" => "error", 
        "message" => "habit_id and user_id required",
        "received_data" => $data,
        "habit_id" => $habit_id,
        "user_id" => $user_id
    ]);
    error_log("Missing required fields - habit_id: $habit_id, user_id: $user_id");
    exit();
}

if (!$date) {
    $date = date('Y-m-d');
}

// Get habit's frequency and target_count
$sql = "SELECT frequency_type, target_count FROM habits WHERE id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $habit_id);
$stmt->execute();
$res = $stmt->get_result();
if (!$row = $res->fetch_assoc()) {
    http_response_code(404);
    echo json_encode(["status" => "error", "message" => "Habit not found"]);
    exit();
}
$frequency = $row['frequency_type'];
$target_count = intval($row['target_count'] ?? 1);
$stmt->close();

// Check current count based on frequency
if ($frequency === 'daily') {
    $count_sql = "SELECT COUNT(*) as cnt FROM habit_logs WHERE habit_id = ? AND user_id = ? AND completed_at = ?";
} else if ($frequency === 'weekly') {
    $count_sql = "SELECT COUNT(*) as cnt FROM habit_logs WHERE habit_id = ? AND user_id = ? AND YEARWEEK(completed_at,1) = YEARWEEK(?,1)";
} else {
    // monthly or default
    $count_sql = "SELECT COUNT(*) as cnt FROM habit_logs WHERE habit_id = ? AND user_id = ? AND MONTH(completed_at) = MONTH(?) AND YEAR(completed_at) = YEAR(?)";
}

$count_stmt = $conn->prepare($count_sql);
if ($frequency === 'daily') {
    $count_stmt->bind_param("iis", $habit_id, $user_id, $date);
} else if ($frequency === 'weekly') {
    $count_stmt->bind_param("iis", $habit_id, $user_id, $date);
} else {
    $count_stmt->bind_param("iiss", $habit_id, $user_id, $date, $date);
}

$count_stmt->execute();
$count_res = $count_stmt->get_result();
$count_row = $count_res->fetch_assoc();
$current_count = intval($count_row['cnt'] ?? 0);
$count_stmt->close();

// Check if already at target
if ($current_count >= $target_count) {
    http_response_code(400);
    echo json_encode([
        "status" => "error", 
        "message" => "Already completed $target_count times this $frequency",
        "current_count" => $current_count,
        "target_count" => $target_count
    ]);
    $conn->close();
    exit();
}

// Insert a completion row
error_log("INSERT attempt: habit_id=$habit_id, user_id=$user_id, date=$date");
$sql = "INSERT INTO habit_logs (habit_id, user_id, completed_at) VALUES (?, ?, ?)";
$stmt = $conn->prepare($sql);

if (!$stmt) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Prepare failed: " . $conn->error]);
    error_log("Prepare failed: " . $conn->error);
    $conn->close();
    exit();
}

$stmt->bind_param("iis", $habit_id, $user_id, $date);

if ($stmt->execute()) {
    error_log("✅ INSERT SUCCESS: habit_id=$habit_id, user_id=$user_id, date=$date, inserted ID=" . $stmt->insert_id);
    
    // Verify it was inserted
    $verify_sql = "SELECT * FROM habit_logs WHERE habit_id = ? AND user_id = ? AND DATE(completed_at) = ?";
    $verify_stmt = $conn->prepare($verify_sql);
    $verify_stmt->bind_param("iis", $habit_id, $user_id, $date);
    $verify_stmt->execute();
    $verify_res = $verify_stmt->get_result();
    error_log("Verification: found " . $verify_res->num_rows . " rows for this completion");
    $verify_stmt->close();
    
    echo json_encode([
        "status" => "success",
        "message" => "Marked complete",
        "date" => $date,
        "current_count" => $current_count + 1,
        "target_count" => $target_count
    ]);
} else {
    http_response_code(500);
    $error_msg = "Execute failed: " . $stmt->error;
    echo json_encode(["status" => "error", "message" => $error_msg]);
    error_log("❌ INSERT FAILED: $error_msg for habit_id=$habit_id, user_id=$user_id, date=$date");
}

$stmt->close();
$conn->close();
?>
