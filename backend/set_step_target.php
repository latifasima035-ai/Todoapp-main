<?php
require_once "db.php";

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

$data = json_decode(file_get_contents("php://input"), true);
$user_id = $data['user_id'] ?? null;
$target_steps = $data['target_steps'] ?? null;
$date = $data['date'] ?? date('Y-m-d');

// Validate input
if (!$user_id || !$target_steps) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "user_id and target_steps are required"
    ]);
    exit();
}

// Ensure date is in YYYY-MM-DD format
if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
    $date = date('Y-m-d');
}

try {
    // Check if record exists for this user and date
    $check_sql = "SELECT id FROM step_targets WHERE user_id = ? AND target_date = ?";
    $check_stmt = $conn->prepare($check_sql);
    $check_stmt->bind_param("is", $user_id, $date);
    $check_stmt->execute();
    $result = $check_stmt->get_result();
    $check_stmt->close();

    if ($result->num_rows > 0) {
        // Update existing record
        $update_sql = "UPDATE step_targets SET target_steps = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ? AND target_date = ?";
        $update_stmt = $conn->prepare($update_sql);
        $update_stmt->bind_param("iis", $target_steps, $user_id, $date);
        
        if (!$update_stmt->execute()) {
            throw new Exception("Update failed: " . $update_stmt->error);
        }
        $update_stmt->close();
        
        echo json_encode([
            "status" => "success",
            "message" => "Step target updated",
            "user_id" => $user_id,
            "target_steps" => $target_steps,
            "date" => $date
        ]);
    } else {
        // Insert new record
        $insert_sql = "INSERT INTO step_targets (user_id, target_date, target_steps) VALUES (?, ?, ?)";
        $insert_stmt = $conn->prepare($insert_sql);
        $insert_stmt->bind_param("isi", $user_id, $date, $target_steps);
        
        if (!$insert_stmt->execute()) {
            throw new Exception("Insert failed: " . $insert_stmt->error);
        }
        $insert_stmt->close();
        
        echo json_encode([
            "status" => "success",
            "message" => "Step target created",
            "user_id" => $user_id,
            "target_steps" => $target_steps,
            "date" => $date
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
