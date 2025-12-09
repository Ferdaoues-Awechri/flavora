import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  DocumentSnapshot? recipeDoc;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    recipeDoc = await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .get();

    setState(() => loading = false);
  }

  // ---------------------------------------------------------
  // DETECT BASE64
  // ---------------------------------------------------------
  bool _looksLikeBase64(String? input) {
    if (input == null) return false;
    try {
      base64Decode(input);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------
  // IMAGE BUILDER
  // ---------------------------------------------------------
  Widget _buildImage(String? media) {
    if (media == null || media.isEmpty) {
      return Container(
        height: 260,
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, size: 64),
      );
    }

    if (_looksLikeBase64(media)) {
      try {
        return Image.memory(
          base64Decode(media),
          height: 260,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } catch (_) {}
    }

    return Image.network(
      media,
      height: 260,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Container(height: 260, color: Colors.grey[200]),
    );
  }

  // ---------------------------------------------------------
  // AVATAR BUILDER
  // ---------------------------------------------------------
  Widget _buildAvatar(String? avatar) {
    if (avatar != null && avatar.isNotEmpty && _looksLikeBase64(avatar)) {
      try {
        return CircleAvatar(
          radius: 22,
          backgroundImage: MemoryImage(base64Decode(avatar)),
        );
      } catch (_) {}
    }

    return const CircleAvatar(
        radius: 22, child: Icon(Icons.person, size: 22));
  }

  // ---------------------------------------------------------
  // LIKE TOGGLE
  // ---------------------------------------------------------
  Future<void> toggleLike() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .collection('likes')
        .doc(uid);

    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({"userId": uid, "createdAt": Timestamp.now()});
    }
  }

  // ---------------------------------------------------------
  // SAVE TOGGLE
  // ---------------------------------------------------------
  Future<void> toggleSave() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final saveDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedRecipes')
        .doc(widget.recipeId);

    final snap = await saveDoc.get();
    if (snap.exists) {
      await saveDoc.delete();
    } else {
      await saveDoc.set({
        "recipeId": widget.recipeId,
        "savedAt": Timestamp.now(),
      });
    }
  }

  // ---------------------------------------------------------
  // COMMENTS BOTTOM SHEET
  // ---------------------------------------------------------
  void _showComments(Map<String, dynamic> recipe) {
    final controller = TextEditingController();
    final recipeId = widget.recipeId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Comments",
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              SizedBox(
                height: 300,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('recipes')
                      .doc(recipeId)
                      .collection('comments')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (_, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(child: Text("No comments yet"));
                    }

                    return ListView(
                      children: docs.map((d) {
                        final c = d.data() as Map<String, dynamic>;
                        Timestamp? ts = c['createdAt'] as Timestamp?;
                        String formatted = ts != null
                            ? ts.toDate().toString().substring(0, 16)
                            : "";

                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(c['username'] ?? "User"),
                          subtitle: Text("${c['text']} • $formatted"),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: "Write a comment...",
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.send, color: Color(0xFFF45104)),
                    onPressed: () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;

                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;

                      await FirebaseFirestore.instance
                          .collection('recipes')
                          .doc(recipeId)
                          .collection('comments')
                          .add({
                        "text": text,
                        "userId": user.uid,
                        "username": user.displayName ?? "User",
                        "createdAt": Timestamp.now()
                      });

                      Navigator.pop(context);
                    },
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------
  // UI
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFFF45104))),
      );
    }

    if (recipeDoc == null || !recipeDoc!.exists) {
      return const Scaffold(
        body: Center(child: Text("Recipe not found")),
      );
    }

    final data = recipeDoc!.data() as Map<String, dynamic>;
    final String title = data['title'] ?? "";
    final String description = data['description'] ?? "";
    final String? media = data['mediaUrl'];

    final String authorPhoto = data['authorPhoto'] ?? "";
    final String username = data['username'] ?? "User";
    final Timestamp? createdAt = data['createdAt'];

    final formattedDate = createdAt != null
        ? createdAt.toDate().toString().substring(0, 16)
        : "";

    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Check if saved
    final savedStream = uid != null
        ? FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('savedRecipes')
            .doc(widget.recipeId)
            .snapshots()
        : Stream<DocumentSnapshot>.empty();

    // Likes stream
    final likesStream = FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .collection('likes')
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.3,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Recipe",
            style: TextStyle(color: Colors.black, fontFamily: "Inter")),
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(media),

            // HEADER USER
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _buildAvatar(authorPhoto),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      Text(formattedDate,
                          style: const TextStyle(color: Colors.black54))
                    ],
                  )
                ],
              ),
            ),

            // TITLE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Inter")),
            ),

            const SizedBox(height: 12),

            // BUTTONS & COUNTS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  // LIKE
                  StreamBuilder<QuerySnapshot>(
                    stream: likesStream,
                    builder: (_, snap) {
                      final likes = snap.hasData ? snap.data!.docs.length : 0;
                      final isLiked = snap.hasData &&
                          uid != null &&
                          snap.data!.docs.any((d) => d.id == uid);

                      return Row(
                        children: [
                          IconButton(
                            onPressed: toggleLike,
                            icon: Icon(
                              isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.red,
                            ),
                          ),
                          Text(likes.toString()),
                        ],
                      );
                    },
                  ),

                  const SizedBox(width: 14),

                  // SAVE
                  StreamBuilder<DocumentSnapshot>(
                    stream: savedStream,
                    builder: (_, snap) {
                      final saved =
                          snap.hasData && snap.data != null && snap.data!.exists;

                      return IconButton(
                        icon: Icon(
                          saved ? Icons.bookmark : Icons.bookmark_border,
                          color: saved ? Colors.orange : Colors.black,
                        ),
                        onPressed: toggleSave,
                      );
                    },
                  ),

                  const Spacer(),

                  IconButton(
                    onPressed: () => _showComments(data),
                    icon: const Icon(Icons.chat_bubble_outline),
                  )
                ],
              ),
            ),

            const SizedBox(height: 16),

            // DESCRIPTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(description,
                  style: const TextStyle(
                      fontSize: 16, height: 1.4, color: Colors.black87)),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
