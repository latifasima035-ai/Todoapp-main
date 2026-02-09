import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_post.dart';

class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'community_posts';

  // Create a new post
  Future<void> createPost({
    required int userId,
    required String userName,
    required String content,
  }) async {
    try {
      final postId = _firestore.collection(collectionName).doc().id;
      
      await _firestore.collection(collectionName).doc(postId).set({
        'postId': postId,
        'userId': userId,
        'userName': userName,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
      });
    } catch (e) {
      print('Error creating post: $e');
      rethrow;
    }
  }

  // Get all posts as stream (real-time updates)
  Stream<List<CommunityPost>> getPosts() {
    return _firestore
        .collection(collectionName)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CommunityPost.fromMap(doc.data()))
              .toList();
        });
  }

  // Like/Unlike a post
  Future<void> toggleLike(String postId, int userId) async {
    try {
      final postDoc = await _firestore
          .collection(collectionName)
          .doc(postId)
          .get();

      final post = CommunityPost.fromMap(postDoc.data() as Map<String, dynamic>);
      
      if (post.likes.contains(userId)) {
        // Unlike
        await _firestore.collection(collectionName).doc(postId).update({
          'likes': FieldValue.arrayRemove([userId]),
        });
      } else {
        // Like
        await _firestore.collection(collectionName).doc(postId).update({
          'likes': FieldValue.arrayUnion([userId]),
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
      rethrow;
    }
  }

  // Delete a post
  Future<void> deletePost(String postId, int userId) async {
    try {
      final postDoc = await _firestore
          .collection(collectionName)
          .doc(postId)
          .get();

      final post = CommunityPost.fromMap(postDoc.data() as Map<String, dynamic>);
      
      // Only allow post owner to delete
      if (post.userId == userId) {
        await _firestore.collection(collectionName).doc(postId).delete();
      }
    } catch (e) {
      print('Error deleting post: $e');
      rethrow;
    }
  }
}
