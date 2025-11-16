import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> recipe;
  const PostCard({super.key, required this.recipe});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  String get uid => FirebaseAuth.instance.currentUser!.uid;

  void toggleLike(String recipeId, bool isLiked) async {
    final ref = FirebaseFirestore.instance.collection('recipes').doc(recipeId);

    await ref.update({
      'likes': isLiked
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
      'likesCount': FieldValue.increment(isLiked ? -1 : 1),
    });
  }

  void toggleSave(String recipeId, bool isSaved) async {
    final ref = FirebaseFirestore.instance.collection('recipes').doc(recipeId);

    await ref.update({
      'savers': isSaved
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
      'savesCount': FieldValue.increment(isSaved ? -1 : 1),
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final recipeId = recipe['id'];

    bool isLiked = (recipe['likes'] ?? []).contains(uid);
    bool isSaved = (recipe['savers'] ?? []).contains(uid);

    return Card(
      elevation: 0.8,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // USER HEADER
          ListTile(
            leading: const CircleAvatar(
              backgroundImage: NetworkImage('https://i.pravatar.cc/120'),
            ),
            title: Text(recipe['username'] ?? "User"),
            subtitle: Text(recipe['createdAt']?.toDate().toString() ?? ""),
            trailing: const Icon(Icons.more_vert),
          ),

          // IMAGE
          if (recipe['mediaUrl'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                recipe['mediaUrl'],
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          // TEXT CONTENT
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe['title'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 5),
                Text(recipe['description'],
                    style: const TextStyle(color: Colors.black87)),
              ],
            ),
          ),

          // ACTIONS
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.black,
                ),
                onPressed: () => toggleLike(recipeId, isLiked),
              ),
              Text("${recipe['likesCount'] ?? 0}"),

              const SizedBox(width: 5),

              // IconButton(
              //   icon: const Icon(Icons.chat_bubble_outline),
              //   // onPressed: () => _showComments(context, recipe),
              // ),
              // Text("${recipe['commentsCount'] ?? 0}"),

              const Spacer(),

              IconButton(
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: isSaved ? Colors.orange : Colors.black,
                ),
                onPressed: () => toggleSave(recipeId, isSaved),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
