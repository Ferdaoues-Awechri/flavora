import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'add_recipe_screen.dart';
import 'notifications_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  final Set<String> _expandedPosts = {};
  final Map<String, bool> _showHeart = {};

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
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
    if (diff.inHours < 24) return "${diff.inHours} hrs ago";
    if (diff.inDays < 7) return "${diff.inDays} days ago";
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

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

    await FirebaseFirestore.instance
        .collection('recipes')
        .doc(recipeId)
        .update({'commentsCount': FieldValue.increment(1)});
  }

  Future<void> toggleLike(String recipeId, bool isLiked) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance.collection('recipes').doc(recipeId);

    _triggerHeart(recipeId);

    await docRef.update({
      'likes': isLiked
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
      'likesCount': FieldValue.increment(isLiked ? -1 : 1),
    });
  }

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

  Future<void> deleteRecipe(String recipeId) async {
    await FirebaseFirestore.instance.collection('recipes').doc(recipeId).delete();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Recipe deleted')));
  }

  void editRecipe(Map<String, dynamic> recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddRecipeScreen(recipe: recipe)),
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

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
          ),
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
          CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage(user?.photoURL ?? 'https://i.pravatar.cc/150?img=3'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.displayName ?? "Hello Chef!",
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        fontFamily: 'Inter')),
                const Text("What will you cook today?",
                    style: TextStyle(color: Colors.black54)),
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
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: Color(0xFFF45104))),
          );
        }
        if (snapshot.data!.docs.isEmpty) {
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

    final List likesList = (recipe['likes'] is List) ? recipe['likes'] : <dynamic>[];
    final List saversList = (recipe['savers'] is List) ? recipe['savers'] : <dynamic>[];
    final List tags = (recipe['tags'] is List) ? recipe['tags'] : <dynamic>[];
    final List imagesBase64 = recipe['images'] ?? [];

    final bool isLiked = currentUserId != null && likesList.contains(currentUserId);
    final bool isSaved = currentUserId != null && saversList.contains(currentUserId);
    final int likes = (recipe['likesCount'] ?? 0) as int;
    final int saves = (recipe['savesCount'] ?? 0) as int;
    final int comments = (recipe['commentsCount'] ?? 0) as int;
    final createdAt = recipe['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // USER + MENU
        ListTile(
          leading: recipe['userId'] != null
              ? CircleAvatar(
                  radius: 22,
                  backgroundImage: NetworkImage(recipe['photoUrl'] ?? 'https://i.pravatar.cc/100'),
                )
              : null,
          title: Text(recipe['username'] ?? "Recipe Posted"),
          subtitle: Text(formatTimestamp(createdAt)),
          trailing: recipe['userId'] == currentUserId
              ? PopupMenuButton<String>(
                  color: Colors.white,
                  icon: const Icon(Icons.more_vert, color: Colors.black),
                  onSelected: (value) {
                    if (value == 'edit') editRecipe(recipe);
                    if (value == 'delete') deleteRecipe(recipeId);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: const [
                            Icon(Icons.edit, color: Colors.black),
                            SizedBox(width: 8),
                            Text("Edit"),
                          ],
                        )),
                    PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text("Delete"),
                          ],
                        )),
                  ],
                )
              : null,
        ),

        // IMAGES with dots indicator
        if (imagesBase64.isNotEmpty)
          SizedBox(
            height: 220,
            child: PageView.builder(
              itemCount: imagesBase64.length,
              onPageChanged: (index) => setState(() => _currentImageIndex[recipeId] = index),
              itemBuilder: (context, index) {
                final imgBytes = base64Decode(imagesBase64[index]);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(imgBytes, fit: BoxFit.cover, width: double.infinity),
                );
              },
            ),
          )
        else
          Container(height: 220, color: Colors.grey[200]),

        // Dots indicator
        if (imagesBase64.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                imagesBase64.length,
                (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: (_currentImageIndex[recipeId] ?? 0) == i
                              ? const Color(0xFFF45104)
                              : Colors.grey[300],
                          shape: BoxShape.circle),
                    )),
          ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(recipe['title'] ?? "",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: tags
                  .map((t) => Text("#$t",
                      style: const TextStyle(
                          color: Color(0xFFF45104), fontWeight: FontWeight.w500)))
                  .toList(),
            ),

            const SizedBox(height: 6),
            _buildExpandableDescription(recipe['description'] ?? "", recipeId),
            const SizedBox(height: 6),
          ]),
        ),

        // ACTIONS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
                color: isLiked ? Colors.red : Colors.black,
                onPressed: () => toggleLike(recipeId, isLiked),
              ),
              Text(likes.toString()),
              IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => _showComments(recipe)),
              Text(comments.toString()),
              IconButton(
                icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                color: isSaved ? Colors.orange : Colors.black,
                onPressed: () => toggleSave(recipeId, isSaved),
              ),
              Text(saves.toString()),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child:
                    Text(formatTimestamp(createdAt), style: const TextStyle(color: Colors.black54)),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  final Map<String, int> _currentImageIndex = {};

  Widget _buildExpandableDescription(String text, String postId) {
    final isExpanded = _expandedPosts.contains(postId);
    return LayoutBuilder(builder: (context, constraints) {
      final span = TextSpan(text: text);
      final tp = TextPainter(
          text: span, maxLines: 2, textDirection: TextDirection.ltr)
        ..layout(maxWidth: constraints.maxWidth);
      final isOverflowing = tp.didExceedMaxLines;

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text, maxLines: isExpanded ? 999 : 2, overflow: TextOverflow.fade),
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
              child: Text(isExpanded ? "Show less" : "Read more",
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
            ),
          ),
      ]);
    });
  }

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
              left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("Comments",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final comments = snapshot.data!.docs;
                  if (comments.isEmpty) return const Center(child: Text("No comments yet"));
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
