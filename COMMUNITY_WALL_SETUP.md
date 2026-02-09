# Community Wall - Complete Setup & Implementation Guide

## ✅ Current Status

| Component | Status | Details |
|-----------|--------|---------|
| Database Schema | ✅ Complete | 3 tables with proper relationships |
| AWS RDS Instance | ✅ Complete | community-db.cv42ysoe0sqi.eu-north-1.rds.amazonaws.com |
| PHP Backend APIs | ✅ Complete | 5 endpoints updated with correct credentials |
| Flutter UI Screens | ✅ Complete | 2 screens with full HTTP integration |
| Navigation Integration | ✅ Complete | "Wall" tab in bottom navigation |

---

## Overview

The Community Wall feature allows users to create posts, add comments, and like posts. All data is stored in AWS RDS MySQL with a PHP REST API backend.

### Tech Stack
- **Backend**: PHP on hackdefenders.com
- **Database**: AWS RDS MySQL (community_db)
- **Frontend**: Flutter with HTTP package
- **API Format**: RESTful JSON

---

## Database Architecture

### 3 Tables (Already Created)

#### 1. `community_posts`
```sql
CREATE TABLE community_posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    user_email VARCHAR(255) NOT NULL,
    content LONGTEXT NOT NULL,
    image_url VARCHAR(500),
    likes_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX(user_id),
    INDEX(created_at)
)
```

#### 2. `community_comments`
```sql
CREATE TABLE community_comments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    user_email VARCHAR(255) NOT NULL,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(post_id) REFERENCES community_posts(id) ON DELETE CASCADE,
    INDEX(post_id),
    INDEX(user_id),
    INDEX(created_at)
)
```

#### 3. `community_likes`
```sql
CREATE TABLE community_likes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_post_user (post_id, user_id),
    FOREIGN KEY(post_id) REFERENCES community_posts(id) ON DELETE CASCADE,
    INDEX(user_id)
)
```

---

## Backend PHP API Endpoints

### Base URL
```
https://hackdefenders.com/Minahil/Habit/
```

### Database Connection (All Files)
```php
$host = "community-db.cv42ysoe0sqi.eu-north-1.rds.amazonaws.com";
$db = "community_db";
$user = "admin";
$pass = "community#123";
```

### 1. Create Post
**Endpoint**: `POST /create_post.php`

**Request Body**:
```json
{
  "user_id": 1,
  "user_email": "user@example.com",
  "content": "This is my post",
  "image_url": "https://..."  // optional
}
```

**Response**:
```json
{
  "status": "success",
  "message": "Post created successfully",
  "post_id": 123
}
```

---

### 2. Get Posts (Paginated)
**Endpoint**: `GET /get_posts.php?page=1`

**Query Parameters**:
- `page` (integer): Page number (default: 1)
- `limit` (per-page): 10 posts

**Response**:
```json
{
  "status": "success",
  "posts": [
    {
      "id": 1,
      "user_id": 1,
      "user_email": "john@example.com",
      "content": "Post content",
      "image_url": null,
      "likes_count": 5,
      "comments_count": 2,
      "created_at": "2024-01-22 10:30:00"
    }
  ],
  "total": 150,
  "page": 1,
  "has_more": true
}
```

---

### 3. Get Post Details with Comments
**Endpoint**: `GET /get_post_details.php?post_id=1`

**Query Parameters**:
- `post_id` (integer): Post ID

**Response**:
```json
{
  "status": "success",
  "post": {
    "id": 1,
    "user_id": 1,
    "user_email": "john@example.com",
    "content": "Post content",
    "image_url": null,
    "likes_count": 5,
    "created_at": "2024-01-22 10:30:00"
  },
  "comments": [
    {
      "id": 10,
      "post_id": 1,
      "user_id": 2,
      "user_email": "jane@example.com",
      "comment_text": "Great post!",
      "created_at": "2024-01-22 10:35:00"
    }
  ]
}
```

---

### 4. Add Comment
**Endpoint**: `POST /add_comment.php`

**Request Body**:
```json
{
  "post_id": 1,
  "user_id": 2,
  "user_email": "jane@example.com",
  "comment_text": "This is a comment"
}
```

**Response**:
```json
{
  "status": "success",
  "message": "Comment added successfully",
  "comment_id": 456
}
```

---

### 5. Toggle Like
**Endpoint**: `POST /like_post.php`

**Request Body**:
```json
{
  "post_id": 1,
  "user_id": 2
}
```

**Response**:
```json
{
  "status": "success",
  "message": "Like toggled"
}
```

---

## Flutter Implementation

### File Structure

```
lib/screens/
├── community_wall_screen.dart      (Main posts feed)
├── post_detail_screen.dart         (Post + comments)
└── home_page.dart                  (Navigation integration)
```

### Main Screens

#### CommunityWallScreen
**Location**: `lib/screens/community_wall_screen.dart`

**Features**:
- ✅ Create new posts with text
- ✅ Infinite scrolling post feed
- ✅ Like/unlike posts
- ✅ View post details and comments
- ✅ Real-time like count updates

**Key Methods**:
```dart
_loadPosts()              // Fetch first page
_loadMorePosts()          // Load next page
_createPost()             // Create new post
_toggleLike()             // Like/unlike post
```

---

#### PostDetailScreen
**Location**: `lib/screens/post_detail_screen.dart`

**Features**:
- ✅ Display full post with user info
- ✅ Show all comments with timestamps
- ✅ Add new comments
- ✅ Display comment count

**Key Methods**:
```dart
_loadPostDetails()        // Fetch post and comments
_addComment()             // Post new comment
```

---

## Step-by-Step Deployment

### 1. Verify Database Tables Exist

Visit in browser:
```
https://hackdefenders.com/Minahil/Habit/create_community_tables.php
```

Expected output:
```
✅ Connected to database 'community_db'
✅ Table 'community_posts' created successfully
✅ Table 'community_comments' created successfully
✅ Table 'community_likes' created successfully
✅ All tables created successfully!
```

### 2. Test Create Post API

```bash
curl -X POST https://hackdefenders.com/Minahil/Habit/create_post.php \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "user_email": "test@example.com",
    "content": "Test post"
  }'
```

Expected:
```json
{"status": "success", "message": "Post created successfully", "post_id": 1}
```

### 3. Test Get Posts API

```bash
curl "https://hackdefenders.com/Minahil/Habit/get_posts.php?page=1"
```

Expected: Array of posts with pagination

### 4. Test Add Comment

```bash
curl -X POST https://hackdefenders.com/Minahil/Habit/add_comment.php \
  -H "Content-Type: application/json" \
  -d '{
    "post_id": 1,
    "user_id": 1,
    "user_email": "test@example.com",
    "comment_text": "Test comment"
  }'
```

### 5. Test Like Post

```bash
curl -X POST https://hackdefenders.com/Minahil/Habit/like_post.php \
  -H "Content-Type: application/json" \
  -d '{"post_id": 1, "user_id": 1}'
```

### 6. Run Flutter App

1. Build and run the app on device/emulator
2. Log in with any user account
3. Tap "Wall" in bottom navigation
4. Create a test post
5. Like the post
6. View post details and add comment

---

## Navigation Integration

### Home Page Bottom Navigation

The "Wall" tab is already integrated in `home_page.dart`:

```dart
bottomNavigationBar: BottomAppBar(
  // ... other config
  child: Row(
    children: [
      _buildNavItem(icon: Icons.today_rounded, label: "Tasks", index: 0),
      _buildNavItem(icon: Icons.directions_walk_rounded, label: "Steps", index: 2),
      SizedBox(width: 60), // FAB space
      _buildNavItem(icon: Icons.chat_bubble_rounded, label: "Wall", index: 3),
      _buildNavItem(icon: Icons.settings_rounded, label: "Settings", index: 4),
    ],
  ),
)
```

---

## Troubleshooting

### Issue: "Unknown database 'community_db'"
**Cause**: Database name mismatch
**Solution**: Already fixed in all PHP files (uses underscore, not dash)

### Issue: API returns 500 error
**Check**:
1. Database connection: Visit `create_community_tables.php`
2. File permissions on web server
3. PHP error logs

### Issue: Posts not showing in Flutter
**Check**:
1. Network requests in browser DevTools (F12)
2. Verify `get_posts.php` returns data
3. Check user_id is passed correctly

### Issue: Comments not posting
**Check**:
1. post_id exists in database
2. user_email is being sent with request
3. Check `add_comment.php` response status

### Issue: Like button not working
**Check**:
1. post_id is valid
2. user_id is passed correctly
3. Check `like_post.php` for errors

---

## Performance Optimization

### Pagination
- Default: 10 posts per page
- Modify in `get_posts.php`: `$limit = 10;`

### Database Indexes
- ✅ `user_id` on posts and comments
- ✅ `created_at` on posts and comments
- ✅ `post_id` on comments and likes
- ✅ UNIQUE constraint on (post_id, user_id) in likes

### Caching Strategy (Future)
- Cache post list for 30 seconds
- Refresh on user actions
- Use SQLite locally for offline view

---

## Security Recommendations

### Current Implementation
- ✅ User email tracked for moderation
- ✅ Foreign key constraints enforce data integrity

### For Production
1. **SQL Injection**: Use prepared statements
2. **XSS**: Sanitize user content before display
3. **Rate Limiting**: Add on POST endpoints
4. **Authentication**: Add JWT tokens
5. **Content Moderation**: Filter inappropriate content
6. **IP Restriction**: Update AWS Security Group

---

## File Changes Summary

### Backend Files (Updated DB Credentials)
- `backend/create_post.php`
- `backend/get_posts.php`
- `backend/get_post_details.php`
- `backend/add_comment.php`
- `backend/like_post.php`

### Flutter Files (Created/Updated)
- `lib/screens/community_wall_screen.dart` - NEW
- `lib/screens/post_detail_screen.dart` - UPDATED
- `lib/screens/home_page.dart` - UPDATED (userEmail param)
- `lib/main.dart` - UPDATED (userEmail pass)
- `lib/screens/login_screen.dart` - UPDATED (userEmail pass)

---

## Next Steps

1. ✅ Upload all PHP files to hackdefenders.com
2. ✅ Test all API endpoints
3. ✅ Test Flutter app on device
4. ⏳ Add image upload support
5. ⏳ Add user profiles
6. ⏳ Add post/comment deletion
7. ⏳ Add content moderation

---

## Database Maintenance

### Check All Posts
```sql
SELECT * FROM community_posts ORDER BY created_at DESC;
```

### Check Comments for Specific Post
```sql
SELECT * FROM community_comments WHERE post_id = 1;
```

### Check Who Liked a Post
```sql
SELECT * FROM community_likes WHERE post_id = 1;
```

### Delete a Post (Cascades)
```sql
DELETE FROM community_posts WHERE id = 1;
```

### Clear All Community Data
```sql
DELETE FROM community_likes;
DELETE FROM community_comments;
DELETE FROM community_posts;
```

---

## Support & Debugging

**Common Errors & Solutions**:

| Error | Cause | Solution |
|-------|-------|----------|
| Connection FAILED | AWS Security Group restricted | Allow 0.0.0.0/0 in inbound rules |
| Unknown database | Database name typo | Check underscore vs dash |
| Posts not showing | API not returning data | Verify `get_posts.php` works |
| Comments empty | Not fetching properly | Check post_id in query |
| Like not working | User already liked | Check `community_likes` constraints |

---

**Deployment Status**: 🟢 Ready for Testing

### 3️⃣ Update Flutter App

In your main navigation, add Community Wall screen:

```dart
// In home_page.dart or navigation
if (selectedIndex == 4) {
  return CommunityWallScreen(
    userId: userId,
    userEmail: userEmail,
  );
}
```

### 4️⃣ Test

1. Build and run app:
```
flutter run
```

2. Navigate to Community Wall
3. Try creating a post
4. Like and comment
5. Check database

## 🗄️ Database Structure

```
community_posts
├── id (PRIMARY KEY)
├── user_id
├── user_email
├── content (LONGTEXT)
├── image_url (optional)
├── likes_count
├── created_at
└── updated_at

community_comments
├── id (PRIMARY KEY)
├── post_id (FOREIGN KEY → community_posts)
├── user_id
├── user_email
├── comment_text
└── created_at

community_likes
├── id (PRIMARY KEY)
├── post_id (FOREIGN KEY → community_posts)
├── user_id
└── created_at
```

## ⚙️ Features Implemented

✅ **Create Posts** - Users can share text/images
✅ **View All Posts** - Paginated timeline
✅ **Like Posts** - Toggle like/unlike
✅ **Comment** - Add comments to posts
✅ **View Comments** - See all comments on a post
✅ **Real-time Updates** - Refresh to see new content
✅ **User Identification** - Shows user email with posts
✅ **Timestamps** - Shows when post/comment was made

## 🔐 Security Notes

⚠️ **For Production:**
- Add authentication tokens
- Validate user input server-side
- Use prepared statements (already done)
- Restrict Security Group to specific IPs
- Use HTTPS only
- Add rate limiting

## 📱 API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/create_post.php` | POST | Create new post |
| `/get_posts.php` | GET | Get all posts (paginated) |
| `/get_post_details.php` | GET | Get post + comments |
| `/add_comment.php` | POST | Add comment to post |
| `/like_post.php` | POST | Like/unlike post |

## 🐛 Troubleshooting

**Posts not showing?**
- Check database connection in PHP files
- Verify RDS security group allows traffic
- Check `community_posts` table exists

**Can't like/comment?**
- Check `user_id` is being sent correctly
- Verify user exists in `users` table
- Check database permissions

**Images not loading?**
- Ensure `image_url` field has valid URL
- Check CORS headers in PHP
