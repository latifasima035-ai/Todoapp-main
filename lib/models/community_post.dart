class CommunityPost {
  final String postId;
  final int userId;
  final String userName;
  final String content;
  final DateTime timestamp;
  final List<int> likes; // List of user IDs who liked

  CommunityPost({
    required this.postId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.timestamp,
    required this.likes,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'content': content,
      'timestamp': timestamp,
      'likes': likes,
    };
  }

  // Create from Firestore document
  factory CommunityPost.fromMap(Map<String, dynamic> map) {
    return CommunityPost(
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? 0,
      userName: map['userName'] ?? 'Anonymous',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'].millisecondsSinceEpoch)
          : DateTime.now(),
      likes: List<int>.from(map['likes'] ?? []),
    );
  }
}
