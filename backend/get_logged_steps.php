<?php
require_once "db.php";

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');

$user_id = $_GET['user_id'] ?? null;
$date = $_GET['date'] ?? date('Y-m-d');

if (!$user_id) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "user_id is required"
    ]);
    exit();
}

// Ensure date is valid
if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
    $date = date('Y-m-d');
}

try {
    $sql = "SELECT id, user_id, log_date, steps, created_at, updated_at FROM step_logs WHERE user_id = ? AND log_date = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("is", $user_id, $date);
    $stmt->execute();
    $result = $stmt->get_result();
    $stmt->close();

    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        echo json_encode([
            "status" => "success",
            "data" => $row
        ]);
    } else {
        // No steps logged for this date yet
        echo json_encode([
            "status" => "success",
            "data" => null,
            "message" => "No steps logged for this date yet"
        ]);
    }
    
    $conn->close();
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Database error: " . $e->getMessage()
    ]);
}
?>
