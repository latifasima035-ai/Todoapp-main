import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'post_detail_screen.dart';

class CommunityWallScreen extends StatefulWidget {
  final int userId;
  final String userEmail;

  const CommunityWallScreen({
    required this.userId,
    required this.userEmail,
    Key? key,
  }) : super(key: key);

  @override
  State<CommunityWallScreen> createState() => _CommunityWallScreenState();
}

class _CommunityWallScreenState extends State<CommunityWallScreen> {
  final TextEditingController _postController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  
  List<Map<String, dynamic>> posts = [];
  Set<int> likedPostIds = {};
  File? _selectedImage;
  bool _isUploadingImage = false;
  String? _uploadedImageUrl;
  
  int currentPage = 1;
  bool isLoading = false;
  bool hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (hasMore && !isLoading) {
        _loadMorePosts();
      }
    }
  }

  Future<void> _loadPosts() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://hackdefenders.com/Minahil/Amazon/get_posts.php?page=1&user_id=${widget.userId}'),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            posts = List<Map<String, dynamic>>.from(data['posts'] ?? []);
            hasMore = data['has_more'] ?? false;
            currentPage = 1;
            // Build set of liked post IDs
            likedPostIds.clear();
            for (var post in posts) {
              if (post['is_liked'] == true || post['is_liked'] == 1) {
                likedPostIds.add(post['id']);
              }
            }
          });
        }
      }
    } catch (e) {
      print('Error loading posts: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> _loadMorePosts() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://hackdefenders.com/Minahil/Amazon/get_posts.php?page=${currentPage + 1}&user_id=${widget.userId}'),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            final newPosts = List<Map<String, dynamic>>.from(data['posts'] ?? []);
            posts.addAll(newPosts);
            hasMore = data['has_more'] ?? false;
            currentPage += 1;
            // Update liked post IDs
            for (var post in newPosts) {
              if (post['is_liked'] == true || post['is_liked'] == 1) {
                likedPostIds.add(post['id']);
              }
            }
          });
        }
      }
    } catch (e) {
      print('Error loading more posts: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image selected')),
      );
      return;
    }

    setState(() => _isUploadingImage = true);
    try {
      // Read image and convert to base64
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,' + base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://hackdefenders.com/Minahil/Amazon/upload_image.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'image_data': base64Image},
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _uploadedImageUrl = data['image_url'];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image uploaded!'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${data['message']}')),
          );
        }
      }
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
    setState(() => _isUploadingImage = false);
  }

  Future<void> _createPost() async {
    if (_postController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://hackdefenders.com/Minahil/Amazon/create_post.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'user_email': widget.userEmail,
          'content': _postController.text.trim(),
          'image_url': _uploadedImageUrl,
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          // Close keyboard
          FocusScope.of(context).unfocus();
          
          _postController.clear();
          setState(() {
            _selectedImage = null;
            _uploadedImageUrl = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post created successfully!'), backgroundColor: Colors.green),
          );
          _loadPosts(); // Refresh the feed
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${data['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: HTTP ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _toggleLike(int postId, int currentLikes) async {
    try {
      // Optimistically update UI
      setState(() {
        if (likedPostIds.contains(postId)) {
          likedPostIds.remove(postId);
        } else {
          likedPostIds.add(postId);
        }
      });

      final response = await http.post(
        Uri.parse('https://hackdefenders.com/Minahil/Amazon/like_post.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'post_id': postId,
          'user_id': widget.userId,
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _loadPosts(); // Refresh to update like count
        }
      }
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  Future<void> _deletePost(int postId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final response = await http.post(
                    Uri.parse('https://hackdefenders.com/Minahil/Amazon/delete_post.php'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'post_id': postId,
                      'user_id': widget.userId,
                    }),
                  ).timeout(const Duration(seconds: 15));

                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    if (data['status'] == 'success') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post deleted!'), backgroundColor: Colors.green),
                      );
                      _loadPosts();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${data['message']}')),
                      );
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _postController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Wall', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Post Creation Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _postController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                // Image preview
                if (_selectedImage != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImage!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImage = null;
                              _uploadedImageUrl = null;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image, color: Colors.deepPurple),
                      onPressed: _pickImage,
                      tooltip: 'Pick image',
                    ),
                    const SizedBox(width: 8),
                    if (_selectedImage != null && _uploadedImageUrl == null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploadingImage ? null : _uploadImage,
                          icon: _isUploadingImage
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cloud_upload),
                          label: Text(_isUploadingImage ? 'Uploading...' : 'Upload Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
                      ),
                    if (_uploadedImageUrl != null)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Text('Image Ready', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _createPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // Posts Feed
          Expanded(
            child: isLoading && posts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : posts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('No posts yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: posts.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == posts.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            );
                          }

                          final post = posts[index];
                          return PostCard(
                            post: post,
                            userId: widget.userId,
                            isLiked: likedPostIds.contains(post['id']),
                            onLike: () => _toggleLike(post['id'], post['likes_count']),
                            onCommentTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PostDetailScreen(
                                    postId: post['id'],
                                    userId: widget.userId,
                                    userEmail: widget.userEmail,
                                  ),
                                ),
                              ).then((_) => _loadPosts());
                            },
                            onDelete: () => _deletePost(post['id']),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// Post Card Widget
class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final int userId;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onCommentTap;
  final VoidCallback? onDelete;

  const PostCard({
    required this.post,
    required this.userId,
    required this.isLiked,
    required this.onLike,
    required this.onCommentTap,
    this.onDelete,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: Text(
                    post['user_email']?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['user_email'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        _formatTime(post['created_at']),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Post Content
            Text(
              post['content'] ?? '',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            // Post Image
            if (post['image_url'] != null && post['image_url'].toString().isNotEmpty)
              Container(
                height: 200,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                child: Image.network(
                  post['image_url'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported),
                    );
                  },
                ),
              ),
            // Engagement Stats
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('${post['likes_count'] ?? 0} Likes', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  Text('${post['comments_count'] ?? 0} Comments', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            const Divider(),
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: onLike,
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.deepPurple,
                  ),
                  label: Text(
                    'Like',
                    style: TextStyle(
                      color: isLiked ? Colors.red : Colors.deepPurple,
                    ),
                  ),
                  style: TextButton.styleFrom(foregroundColor: isLiked ? Colors.red : Colors.deepPurple),
                ),
                TextButton.icon(
                  onPressed: onCommentTap,
                  icon: const Icon(Icons.comment_outlined),
                  label: const Text('Comment'),
                  style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
                ),
                if (post['user_id'] == userId && onDelete != null)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return dateStr.substring(0, 10);
    } catch (e) {
      return dateStr;
    }
  }
}
