<?php
require_once "db.php";

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

echo json_encode([
    "status" => "info",
    "message" => "Database Structure Check"
], JSON_PRETTY_PRINT);

echo "\n\n=== habit_logs TABLE STRUCTURE ===\n";
$sql = "DESCRIBE habit_logs";
$result = $conn->query($sql);
while ($row = $result->fetch_assoc()) {
    echo json_encode($row, JSON_PRETTY_PRINT) . "\n";
}

echo "\n\n=== SAMPLE DATA FROM habit_logs ===\n";
$sql = "SELECT * FROM habit_logs LIMIT 5";
$result = $conn->query($sql);
while ($row = $result->fetch_assoc()) {
    echo json_encode($row, JSON_PRETTY_PRINT) . "\n";
}

echo "\n\n=== habit_logs COUNT ===\n";
$sql = "SELECT COUNT(*) as total FROM habit_logs";
$result = $conn->query($sql);
$row = $result->fetch_assoc();
echo "Total records: " . $row['total'] . "\n";

echo "\n\n=== UNIQUE HABITS IN LOG ===\n";
$sql = "SELECT DISTINCT habit_id, user_id, COUNT(*) as entries FROM habit_logs GROUP BY habit_id, user_id";
$result = $conn->query($sql);
while ($row = $result->fetch_assoc()) {
    echo json_encode($row, JSON_PRETTY_PRINT) . "\n";
}

$conn->close();
?>
