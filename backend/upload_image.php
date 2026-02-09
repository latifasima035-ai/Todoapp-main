<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

$servername = "community-db.cv42ysoe0sqi.eu-north-1.rds.amazonaws.com";
$username = "admin";
$password = "community#123";
$dbname = "community_db";

// Create uploads directory if it doesn't exist
$upload_dir = __DIR__ . '/uploads/community_images/';
if (!is_dir(__DIR__ . '/uploads')) {
    mkdir(__DIR__ . '/uploads', 0755, true);
}
if (!is_dir($upload_dir)) {
    mkdir($upload_dir, 0755, true);
}

// Check if image data is provided
if (!isset($_POST['image_data'])) {
    echo json_encode(['status' => 'error', 'message' => 'No image data provided']);
    exit;
}

$image_data = $_POST['image_data'];

// Validate base64 image
if (strpos($image_data, 'data:image/') === 0) {
    // Extract base64 content
    $image_data = substr($image_data, strpos($image_data, ',') + 1);
} else {
    echo json_encode(['status' => 'error', 'message' => 'Invalid image format']);
    exit;
}

$image_data = base64_decode($image_data);

if (!$image_data) {
    echo json_encode(['status' => 'error', 'message' => 'Failed to decode image']);
    exit;
}

// Create temporary file to process
$temp_file = tempnam(sys_get_temp_dir(), 'img_');
file_put_contents($temp_file, $image_data);

// Validate image
$image_info = getimagesize($temp_file);
if (!$image_info) {
    unlink($temp_file);
    echo json_encode(['status' => 'error', 'message' => 'Invalid image file']);
    exit;
}

// Check file size (max 5MB)
if (filesize($temp_file) > 5242880) {
    unlink($temp_file);
    echo json_encode(['status' => 'error', 'message' => 'Image too large (max 5MB)']);
    exit;
}

// Allow only JPG and PNG
$allowed_types = ['image/jpeg', 'image/png'];
$mime_type = $image_info['mime'];
if (!in_array($mime_type, $allowed_types)) {
    unlink($temp_file);
    echo json_encode(['status' => 'error', 'message' => 'Only JPG and PNG images allowed']);
    exit;
}

// Load image based on type
if ($mime_type == 'image/jpeg') {
    $image = imagecreatefromjpeg($temp_file);
} else {
    $image = imagecreatefrompng($temp_file);
}

if (!$image) {
    unlink($temp_file);
    echo json_encode(['status' => 'error', 'message' => 'Failed to process image']);
    exit;
}

// Get original dimensions
$original_width = imagesx($image);
$original_height = imagesy($image);

// Resize if needed (max width 1200px)
$max_width = 1200;
if ($original_width > $max_width) {
    $ratio = $max_width / $original_width;
    $new_width = $max_width;
    $new_height = (int)($original_height * $ratio);
    
    $resized_image = imagecreatetruecolor($new_width, $new_height);
    if ($mime_type == 'image/png') {
        imagealphablending($resized_image, false);
        imagesavealpha($resized_image, true);
    }
    imagecopyresampled($resized_image, $image, 0, 0, 0, 0, $new_width, $new_height, $original_width, $original_height);
    imagedestroy($image);
    $image = $resized_image;
}

// Generate unique filename
$filename = 'img_' . time() . '_' . rand(1000, 9999) . '.jpg';
$file_path = $upload_dir . $filename;
$relative_path = 'uploads/community_images/' . $filename;

// Save compressed JPG
imagejpeg($image, $file_path, 80); // 80% quality for compression
imagedestroy($image);
unlink($temp_file);

if (!file_exists($file_path)) {
    echo json_encode(['status' => 'error', 'message' => 'Failed to save image']);
    exit;
}

// Return full URL
$full_url = 'https://hackdefenders.com/Minahil/Amazon/uploads/community_images/' . $filename;

echo json_encode([
    'status' => 'success',
    'message' => 'Image uploaded successfully',
    'image_url' => $full_url,
    'file_size' => filesize($file_path)
]);
?>
