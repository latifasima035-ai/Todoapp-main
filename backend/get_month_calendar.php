<?php
require_once "db.php";

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type');

$user_id = $_GET['user_id'] ?? $_REQUEST['user_id'] ?? null;
$habit_id = $_GET['habit_id'] ?? $_REQUEST['habit_id'] ?? null;
$month = $_GET['month'] ?? $_REQUEST['month'] ?? null;
$year = $_GET['year'] ?? $_REQUEST['year'] ?? null;

if (!$user_id || !$habit_id || !$month || !$year) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "user_id, habit_id, month and year required"]);
    exit();
}

$user_id = intval($user_id);
$habit_id = intval($habit_id);
$month = intval($month);
$year = intval($year);

$daysInMonth = cal_days_in_month(CAL_GREGORIAN, $month, $year);
$rows = [];

for ($day = 1; $day <= $daysInMonth; $day++) {
    $rows[strval($day)] = false;
}

$startDate = sprintf("%04d-%02d-01", $year, $month);
$endDate = sprintf("%04d-%02d-%02d", $year, $month, $daysInMonth);

$sql = "SELECT DAY(completed_at) as day FROM habit_logs WHERE user_id = ? AND habit_id = ? AND completed_at >= ? AND completed_at <= ?";
$stmt = $conn->prepare($sql);

if (!$stmt) {
    echo json_encode(["status" => "error", "message" => "Database error"]);
    exit();
}

$stmt->bind_param("iiss", $user_id, $habit_id, $startDate, $endDate);
$stmt->execute();
$res = $stmt->get_result();

while ($r = $res->fetch_assoc()) {
    $day = intval($r['day']);
    $rows[strval($day)] = true;
}

echo json_encode([
    "status" => "success",
    "month" => $month,
    "year" => $year,
    "data" => (object)$rows
]);

$stmt->close();
$conn->close();
?>
