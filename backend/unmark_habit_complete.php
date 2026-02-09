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

if (!$habit_id || !$user_id) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "habit_id and user_id required"]);
    exit();
}

if (!$date) {
    $date = date('Y-m-d');
}

// Delete the most recent completion entry for this date
$sql = "DELETE FROM habit_logs WHERE habit_id = ? AND user_id = ? AND DATE(completed_at) = ? LIMIT 1";
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
    if ($stmt->affected_rows > 0) {
        error_log("Successfully deleted 1 record for habit $habit_id on $date");
        echo json_encode(["status" => "success", "message" => "Marked as incomplete", "date" => $date]);
    } else {
        error_log("No records found to delete for habit $habit_id on $date");
        echo json_encode(["status" => "success", "message" => "No completion found to remove", "date" => $date]);
    }
} else {
    http_response_code(500);
    $error_msg = "Execute failed: " . $stmt->error;
    echo json_encode(["status" => "error", "message" => $error_msg, "sql_error" => $stmt->error]);
    error_log($error_msg . " for habit_id=$habit_id, user_id=$user_id, date=$date");
}

$stmt->close();
$conn->close();
?>
