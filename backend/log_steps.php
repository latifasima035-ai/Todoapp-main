<?php
require_once "db.php";

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

$data = json_decode(file_get_contents("php://input"), true);
$user_id = $data['user_id'] ?? null;
$steps = $data['steps'] ?? null;
$date = $data['date'] ?? date('Y-m-d');

// Debug logging
error_log("=== LOG_STEPS DEBUG ===");
error_log("Raw input: " . file_get_contents("php://input"));
error_log("Decoded user_id: $user_id, steps: $steps, date: $date");

if (!$user_id || $steps === null) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "user_id and steps are required",
        "received_user_id" => $user_id,
        "received_steps" => $steps
    ]);
    exit();
}

// Ensure date is valid
if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
    $date = date('Y-m-d');
}

try {
    // Check if step log exists for this user and date
    $check_sql = "SELECT id FROM step_logs WHERE user_id = ? AND log_date = ?";
    $check_stmt = $conn->prepare($check_sql);
    $check_stmt->bind_param("is", $user_id, $date);
    $check_stmt->execute();
    $result = $check_stmt->get_result();
    $check_stmt->close();

    error_log("Check query result rows: " . $result->num_rows);

    if ($result->num_rows > 0) {
        // Update existing record
        error_log("Updating existing record for user $user_id on $date");
        $update_sql = "UPDATE step_logs SET steps = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ? AND log_date = ?";
        $update_stmt = $conn->prepare($update_sql);
        
        if (!$update_stmt) {
            error_log("Prepare failed: " . $conn->error);
            throw new Exception("Prepare failed: " . $conn->error);
        }
        
        $update_stmt->bind_param("iis", $steps, $user_id, $date);
        
        if (!$update_stmt->execute()) {
            error_log("Execute failed: " . $update_stmt->error);
            throw new Exception("Update failed: " . $update_stmt->error);
        }
        $update_stmt->close();
        
        error_log("✅ Updated record");
        echo json_encode([
            "status" => "success",
            "message" => "Steps logged successfully (updated)",
            "user_id" => $user_id,
            "steps" => $steps,
            "date" => $date,
            "action" => "update"
        ]);
    } else {
        // Insert new record
        error_log("Inserting new record for user $user_id on $date with $steps steps");
        $insert_sql = "INSERT INTO step_logs (user_id, log_date, steps) VALUES (?, ?, ?)";
        $insert_stmt = $conn->prepare($insert_sql);
        
        if (!$insert_stmt) {
            error_log("Prepare failed: " . $conn->error);
            throw new Exception("Prepare failed: " . $conn->error);
        }
        
        $insert_stmt->bind_param("isi", $user_id, $date, $steps);
        
        if (!$insert_stmt->execute()) {
            error_log("Execute failed: " . $insert_stmt->error);
            throw new Exception("Insert failed: " . $insert_stmt->error);
        }
        $insert_stmt->close();
        
        error_log("✅ Inserted new record");
        echo json_encode([
            "status" => "success",
            "message" => "Steps logged successfully",
            "user_id" => $user_id,
            "steps" => $steps,
            "date" => $date,
            "action" => "insert"
        ]);
    }
    
    $conn->close();
} catch (Exception $e) {
    error_log("Exception: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Database error: " . $e->getMessage()
    ]);
}
?>
