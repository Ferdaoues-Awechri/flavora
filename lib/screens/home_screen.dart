// lib/screens/home_screen.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'search_screen.dart';
import 'add_recipe_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;

  // track expanded state per post id
  final Set<String> _expandedPosts = {};

  // show heart animation per post id
  final Map<String, bool> _showHeart = {};

  // local animation controllers are not persisted across rebuilds;
  // we'll do a simple timed opacity heart overlay for simplicity
  void _triggerHeart(String postId) {
    setState(() => _showHeart[postId] = true);
    Timer(const Duration(milliseconds: 700), () {
      setState(() => _showHeart[postId] = false);
    });
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return "Just now";
    if (difference.inMinutes < 60) return "${difference.inMinutes} min ago";
    if (difference.inHours < 24) return "${difference.inHours} hrs ago";
    if (difference.inDays < 7) return "${difference.inDays} days ago";
    // older: show date
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  // ------------------------------
  // LIKE ❤️ (ensures likes array exists and is updated)
  Future<void> toggleLike(String recipeId, bool isLiked) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance.collection('recipes').doc(recipeId);

    // optimistic small animation trigger
    _triggerHeart(recipeId);

    await docRef.update({
      'likes': isLiked
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
      'likesCount': FieldValue.increment(isLiked ? -1 : 1),
    });
  }

  // SAVE 🔖
  Future<void> toggleSave(String recipeId, bool isSaved) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance.collection('recipes').doc(recipeId);
    await docRef.update({
      'savers': isSaved
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
      'savesCount': FieldValue.increment(isSaved ? -1 : 1),
    });
  }

  // COMMENT 💬
  Future<void> addComment(String recipeId, String text) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final ref = FirebaseFirestore.instance
        .collection('recipes')
        .doc(recipeId)
        .collection('comments');

    await ref.add({
      'text': text,
      'userId': currentUser.uid,
      'username': currentUser.displayName ?? "User",
      'createdAt': Timestamp.now(),
    });

    // Increment counter
    await FirebaseFirestore.instance
        .collection('recipes')
        .doc(recipeId)
        .update({'commentsCount': FieldValue.increment(1)});
  }

  // DELETE RECIPE
  Future<void> deleteRecipe(String recipeId) async {
    await FirebaseFirestore.instance.collection('recipes').doc(recipeId).delete();
  }

  // EDIT RECIPE
  void editRecipe(Map<String, dynamic> recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRecipeScreen(recipe: recipe),
      ),
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  // MAIN BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildUserSection(),
              _buildFeed(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF45104),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddRecipeScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset('assets/images/burn orange.png', height: 36),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
              ),
            IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  );
                },
              ),
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildUserSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=3'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? "Hello Chef!",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    fontFamily: 'Inter',
                  ),
                ),
                const Text(
                  "What will you cook today?",
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: Color(0xFFF45104))),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "No recipes yet 🍽\nBe the first to share one!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = Map<String, dynamic>.from(doc.data() as Map);
            data['id'] = doc.id;
            return _buildPostCard(data);
          },
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> recipe) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final recipeId = recipe['id'] as String;

    // defensive reads
    final List likesList = (recipe['likes'] is List) ? recipe['likes'] : <dynamic>[];
    final List saversList = (recipe['savers'] is List) ? recipe['savers'] : <dynamic>[];

    final bool isLiked = currentUserId != null && likesList.contains(currentUserId);
    final bool isSaved = currentUserId != null && saversList.contains(currentUserId);

    final int likes = (recipe['likesCount'] ?? 0) as int;
    final int saves = (recipe['savesCount'] ?? 0) as int;
    final int comments = (recipe['commentsCount'] ?? 0) as int;

    final createdAt = recipe['createdAt'] as Timestamp?;

    return Card(
      color: Colors.white, // white card
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // USER INFO
        ListTile(
          leading: const CircleAvatar(
            radius: 22,
            backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=6'),
          ),
          title: Text(recipe['username'] ?? "User"),
          subtitle: Text(formatTimestamp(createdAt)),
          trailing: recipe['userId'] == currentUserId
              ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') editRecipe(recipe);
                    if (value == 'delete') deleteRecipe(recipeId);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text("Edit")),
                    const PopupMenuItem(value: 'delete', child: Text("Delete")),
                  ],
                )
              : null,
        ),

        // IMAGE / MEDIA with double-tap like
        GestureDetector(
          onDoubleTap: () {
            if (currentUserId == null) return;
            if (!isLiked) toggleLike(recipeId, isLiked);
            _triggerHeart(recipeId);
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (recipe['mediaUrl'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    recipe['mediaUrl'],
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 220,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, size: 64),
                    ),
                  ),
                ),
              // Heart overlay animation (simple fade/scale)
              if (_showHeart[recipeId] == true)
                Positioned.fill(
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 400),
                      opacity: _showHeart[recipeId]! ? 1.0 : 0.0,
                      child: const Icon(Icons.favorite, size: 120, color: Colors.white70),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // DESCRIPTION + expandable
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(recipe['title'] ?? "",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _buildExpandableDescription(recipe['description'] ?? "", recipe['id'] as String),
            ],
          ),
        ),

        // ACTIONS (like, comment, save) — save placed next to comment
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
                color: isLiked ? Colors.red : Colors.black,
                onPressed: () {
                  if (currentUserId == null) return;
                  toggleLike(recipeId, isLiked);
                },
              ),
              Text(likes.toString()),

              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () => _showComments(recipe),
              ),
              Text(comments.toString()),

              IconButton(
                icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                color: isSaved ? Colors.orange : Colors.black,
                onPressed: () {
                  if (currentUserId == null) return;
                  toggleSave(recipeId, isSaved);
                },
              ),
              Text(saves.toString()),

              const Spacer(),

              // optionally show publish date abbreviated (already in subtitle)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(formatTimestamp(createdAt), style: const TextStyle(color: Colors.black54)),
              )
            ],
          ),
        ),
      ]),
    );
  }

  // Expandable description widget that tracks per-post expansion
  Widget _buildExpandableDescription(String text, String postId) {
    final isExpanded = _expandedPosts.contains(postId);

    // We show up to 2 lines collapsed
    return LayoutBuilder(builder: (context, constraints) {
      final span = TextSpan(text: text);
      final tp = TextPainter(
        text: span,
        maxLines: 2,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: constraints.maxWidth);

      final isOverflowing = tp.didExceedMaxLines;

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          text,
          maxLines: isExpanded ? 999 : 2,
          overflow: TextOverflow.fade,
        ),
        if (isOverflowing)
          GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded)
                  _expandedPosts.remove(postId);
                else
                  _expandedPosts.add(postId);
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                isExpanded ? "Show less" : "Read more",
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ]);
    });
  }

  // Comments bottom sheet — shows comment text + timeago
  void _showComments(Map<String, dynamic> recipe) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("Comments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),

            SizedBox(
              height: 320,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('recipes')
                    .doc(recipe['id'])
                    .collection('comments')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (_, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final comments = snapshot.data!.docs;
                  if (comments.isEmpty) {
                    return const Center(child: Text("No comments yet"));
                  }

                  return ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (_, index) {
                      final doc = comments[index];
                      final c = Map<String, dynamic>.from(doc.data() as Map);
                      final created = c['createdAt'] as Timestamp?;
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(c['username'] ?? "User"),
                        subtitle: Text("${c['text'] ?? ''} • ${formatTimestamp(created)}"),
                      );
                    },
                  );
                },
              ),
            ),

            // COMMENT INPUT
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    decoration: InputDecoration(
                      hintText: "Write a comment...",
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFFF45104)),
                  onPressed: () {
                    if (commentController.text.trim().isEmpty) return;
                    addComment(recipe['id'], commentController.text.trim());
                    Navigator.pop(context);
                  },
                )
              ],
            )
          ]),
        );
      },
    );
  }
}
