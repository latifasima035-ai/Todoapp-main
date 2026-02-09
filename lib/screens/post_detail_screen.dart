import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PostDetailScreen extends StatefulWidget {
  final int postId;
  final int userId;
  final String userEmail;

  const PostDetailScreen({
    Key? key,
    required this.postId,
    required this.userId,
    required this.userEmail,
  }) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
  Set<int> _likedCommentIds = {};
  Set<int> _expandedCommentIds = {};
  int? _replyingToCommentId;
  bool _isLoading = true;
  bool _isAddingComment = false;

  @override
  void initState() {
    super.initState();
    _loadPostDetails();
  }

  Future<void> _loadPostDetails({bool silentFail = false}) async {
    try {
      final url = 'https://hackdefenders.com/Minahil/Amazon/get_post_details.php?post_id=${widget.postId}&user_id=${widget.userId}';
      print('Loading post details from: $url');
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Decoded JSON: $data');
        
        if (data['status'] == 'success') {
          setState(() {
            _post = data['post'];
            _comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
            _isLoading = false;
            // Build liked comments set
            _likedCommentIds.clear();
            for (var comment in _comments) {
              // Use is_liked from API response (can be 0, 1, or true/false)
              var isLiked = comment['is_liked'];
              if (isLiked == true || isLiked == 1 || isLiked == '1') {
                _likedCommentIds.add(comment['id']);
              }
            }
          });
        } else {
          if (!silentFail) {
            setState(() {
              _isLoading = false;
            });
            print('API Error: ${data['message']}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${data['message'] ?? 'Unknown error'}')),
            );
          }
        }
      } else {
        if (!silentFail) {
          setState(() {
            _isLoading = false;
          });
          print('HTTP Error: ${response.statusCode}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: HTTP ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      print('Exception loading post details: $e');
      if (!silentFail) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment')),
      );
      return;
    }

    setState(() => _isAddingComment = true);
    try {
      final response = await http.post(
        Uri.parse('https://hackdefenders.com/Minahil/Amazon/add_comment.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'post_id': widget.postId,
          'user_id': widget.userId,
          'user_email': widget.userEmail,
          'comment_text': _commentController.text.trim(),
          'parent_comment_id': _replyingToCommentId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          // Close keyboard
          FocusScope.of(context).unfocus();
          
          _commentController.clear();
          _cancelReply();
          // Reload post details to get new comments
          await _loadPostDetails(silentFail: true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comment added!'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${data['message'] ?? 'Failed to add comment'}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: HTTP ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    setState(() => _isAddingComment = false);
  }

  Future<void> _deletePost() async {
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
                      'post_id': widget.postId,
                      'user_id': widget.userId,
                    }),
                  ).timeout(const Duration(seconds: 15));

                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    if (data['status'] == 'success') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post deleted!'), backgroundColor: Colors.green),
                      );
                      Future.delayed(const Duration(milliseconds: 500), () {
                        Navigator.pop(context);
                      });
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

  Future<void> _likeComment(int commentId) async {
    try {
      final response = await http.post(
        Uri.parse('https://hackdefenders.com/Minahil/Amazon/like_comment.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'comment_id': commentId,
          'user_id': widget.userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          // Reload post details to get updated like status
          await _loadPostDetails(silentFail: true);
          print('Comment liked successfully, reloaded data');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${data['message']}')),
          );
        }
      }
    } catch (e) {
      print('Error liking comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteComment(int commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.post(
        Uri.parse('https://hackdefenders.com/Minahil/Amazon/delete_comment.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'comment_id': commentId,
          'user_id': widget.userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _comments.removeWhere((c) => c['id'] == commentId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comment deleted')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${data['message']}')),
          );
        }
      }
    } catch (e) {
      print('Error deleting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _replyToComment(int commentId) {
    setState(() {
      _replyingToCommentId = commentId;
    });
    _commentController.clear();
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
    });
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Post Details'),
          backgroundColor: Colors.deepPurple,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading post details...'),
            ],
          ),
        ),
      );
    }

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Post Details'),
          backgroundColor: Colors.deepPurple,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Post not found or failed to load'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadPostDetails,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_post != null && _post!['user_id'] == widget.userId)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deletePost,
              tooltip: 'Delete post',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.deepPurple,
                                  child: Text(
                                    _post!['user_email']?.substring(0, 1).toUpperCase() ?? 'U',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _post!['user_email'] ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        _formatTime(_post!['created_at']),
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _post!['content'] ?? '',
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                            if (_post!['image_url'] != null && _post!['image_url'].toString().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _post!['image_url'],
                                  height: 250,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 250,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image_not_supported),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Divider(color: Colors.grey[300]),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                '${_post!['likes_count'] ?? 0} Likes • ${_comments.length} Comments',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Comments (${_comments.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No comments yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.where((c) => c['parent_comment_id'] == null || c['parent_comment_id'] == 0).length,
                      itemBuilder: (context, index) {
                        // Get only parent comments
                        final parentComments = _comments.where((c) => c['parent_comment_id'] == null || c['parent_comment_id'] == 0).toList();
                        final comment = parentComments[index];
                        final commentId = comment['id'];
                        final isLiked = _likedCommentIds.contains(commentId);
                        final canDelete = comment['user_id'] == widget.userId || _post!['user_id'] == widget.userId;
                        final isExpanded = _expandedCommentIds.contains(commentId);
                        
                        // Get all replies for this comment
                        final replies = _comments.where((c) => c['parent_comment_id'] == commentId).toList();
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Parent comment
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.deepPurple.withOpacity(0.5),
                                        child: Text(
                                          comment['user_email']?.substring(0, 1).toUpperCase() ?? 'U',
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              comment['user_email'] ?? 'Unknown',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            Text(
                                              _formatTime(comment['created_at']),
                                              style: TextStyle(color: Colors.grey[600], fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    comment['comment_text'] ?? '',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${comment['likes_count'] ?? 0} likes',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              isLiked ? Icons.favorite : Icons.favorite_border,
                                              color: isLiked ? Colors.red : Colors.grey,
                                              size: 18,
                                            ),
                                            onPressed: () => _likeComment(commentId),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            icon: const Icon(Icons.reply, size: 18, color: Colors.deepPurple),
                                            onPressed: () => _replyToComment(commentId),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          if (canDelete) ...[
                                            const SizedBox(width: 12),
                                            IconButton(
                                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                              onPressed: () => _deleteComment(commentId),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                  // Show replies count and expand button
                                  if (replies.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (isExpanded) {
                                            _expandedCommentIds.remove(commentId);
                                          } else {
                                            _expandedCommentIds.add(commentId);
                                          }
                                        });
                                      },
                                      child: Text(
                                        isExpanded
                                            ? '▼ Hide ${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}'
                                            : '▶ View ${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                                        style: const TextStyle(
                                          color: Colors.deepPurple,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    // Show replies when expanded
                                    if (isExpanded) ...[
                                      const SizedBox(height: 12),
                                      Divider(color: Colors.grey[300]),
                                      const SizedBox(height: 8),
                                      ...replies.map((reply) {
                                        final replyIsLiked = _likedCommentIds.contains(reply['id']);
                                        final replyCanDelete = reply['user_id'] == widget.userId || _post!['user_id'] == widget.userId;
                                        
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            padding: const EdgeInsets.all(10),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 13,
                                                      backgroundColor: Colors.deepPurple.withOpacity(0.7),
                                                      child: Text(
                                                        reply['user_email']?.substring(0, 1).toUpperCase() ?? 'U',
                                                        style: const TextStyle(color: Colors.white, fontSize: 10),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            reply['user_email'] ?? 'Unknown',
                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                                          ),
                                                          Text(
                                                            _formatTime(reply['created_at']),
                                                            style: TextStyle(color: Colors.grey[600], fontSize: 9),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  reply['comment_text'] ?? '',
                                                  style: const TextStyle(fontSize: 11),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      '${reply['likes_count'] ?? 0} likes',
                                                      style: TextStyle(color: Colors.grey[600], fontSize: 9),
                                                    ),
                                                    Row(
                                                      children: [
                                                        IconButton(
                                                          icon: Icon(
                                                            replyIsLiked ? Icons.favorite : Icons.favorite_border,
                                                            color: replyIsLiked ? Colors.red : Colors.grey,
                                                            size: 15,
                                                          ),
                                                          onPressed: () => _likeComment(reply['id']),
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                        ),
                                                        if (replyCanDelete) ...[
                                                          const SizedBox(width: 8),
                                                          IconButton(
                                                            icon: const Icon(Icons.delete, size: 15, color: Colors.red),
                                                            onPressed: () => _deleteComment(reply['id']),
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (_replyingToCommentId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Replying to ${_comments.firstWhere((c) => c['id'] == _replyingToCommentId, orElse: () => {})['user_email'] ?? 'user'}',
                            style: const TextStyle(fontSize: 12, color: Colors.deepPurple),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: _cancelReply,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isAddingComment ? null : _addComment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                      child: _isAddingComment
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }
}
