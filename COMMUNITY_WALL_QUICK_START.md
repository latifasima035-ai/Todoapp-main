# Community Wall - Quick Reference

## ✅ What's Implemented

### Database (AWS RDS)
- ✅ 3 tables with proper schema
- ✅ Foreign keys with CASCADE delete
- ✅ Indexes for performance
- ✅ Connection tested and working

### Backend (PHP APIs)
- ✅ create_post.php - Create posts
- ✅ get_posts.php - Paginated feed
- ✅ get_post_details.php - Post + comments
- ✅ add_comment.php - Add comments
- ✅ like_post.php - Toggle likes
- ✅ All use correct DB credentials

### Frontend (Flutter)
- ✅ CommunityWallScreen - Main feed
- ✅ PostDetailScreen - Detailed view
- ✅ Navigation integration - "Wall" tab
- ✅ Full HTTP API integration
- ✅ userEmail parameter added

---

## 🚀 To Deploy

### 1. Upload PHP Files
Upload to: `https://hackdefenders.com/Minahil/Habit/`
- create_post.php
- get_posts.php
- get_post_details.php
- add_comment.php
- like_post.php

### 2. Verify Database
Visit: `https://hackdefenders.com/Minahil/Habit/create_community_tables.php`
Expected: All tables created ✅

### 3. Test APIs
```bash
# Create post
curl -X POST https://hackdefenders.com/Minahil/Habit/create_post.php \
  -H "Content-Type: application/json" \
  -d '{"user_id":1,"user_email":"test@example.com","content":"test"}'

# Get posts
curl "https://hackdefenders.com/Minahil/Habit/get_posts.php?page=1"
```

### 4. Run App
- Build and run Flutter app
- Log in with user account
- Tap "Wall" in bottom navigation
- Create, comment, and like posts

---

## 📊 Database Info

**Host**: community-db.cv42ysoe0sqi.eu-north-1.rds.amazonaws.com
**Database**: community_db
**User**: admin
**Password**: community#123

**Tables**:
- community_posts (posts)
- community_comments (comments on posts)
- community_likes (like tracking)

---

## 🔗 API Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | /create_post.php | Create new post |
| GET | /get_posts.php?page=1 | Get paginated posts |
| GET | /get_post_details.php?post_id=1 | Get post with comments |
| POST | /add_comment.php | Add comment to post |
| POST | /like_post.php | Toggle like on post |

---

## 🎯 Features

- ✅ Create posts with text
- ✅ Add optional images
- ✅ Infinite scroll feed
- ✅ Like/unlike posts
- ✅ Add comments
- ✅ View all comments
- ✅ Real-time updates

---

## 📱 Flutter Screens

**CommunityWallScreen**
- Post creation card at top
- Infinite scrolling feed
- Like button with count
- Tap post for details

**PostDetailScreen**
- Full post with image
- All comments listed
- Add comment input
- Real-time comment addition

---

## ⚙️ Database Schema Quick View

```
posts (id, user_id, user_email, content, image_url, likes_count, created_at)
comments (id, post_id, user_id, user_email, comment_text, created_at)
likes (id, post_id, user_id) [UNIQUE on post_id + user_id]
```

---

## 🐛 If Something's Wrong

1. Check DB connection: Visit create_community_tables.php
2. Check API: Use curl commands above
3. Check Flutter logs: Look for HTTP errors
4. Check credentials: All files use correct username/password
5. Check AWS Security Group: May need to allow more IPs

---

**Status**: Ready for Production Deployment ✅
