// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:convert';
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

  // store Firestore user doc so we can read photoBase64 / photoUrl
  DocumentSnapshot? _userDoc;

  // local transient state for heart overlay
  final Map<String, bool> _showHeart = {};

  void _triggerHeart(String postId) {
    setState(() => _showHeart[postId] = true);
    Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeart[postId] = false);
    });
  }

  @override
  void initState() {
    super.initState();
    // load current user Firestore doc from collection 'users/{uid}'
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .then((doc) {
            if (mounted) {
              setState(() {
                _userDoc = doc;
              });
            }
          })
          .catchError((error) {
            // silently ignore, keep _userDoc null (we still fallback to auth info)
          });
    }
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
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  // ---------------------
  // Utilities for image handling
  bool _looksLikeBase64(String? input) {
    if (input == null) return false;
    final cleaned = input.replaceAll(RegExp(r'\s+'), '');
    // quick regex check for base64 characters
    if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleaned)) return false;
    // length should be multiple of 4 ideally, allow small deviations
    if (cleaned.length % 4 != 0 && cleaned.length < 100) {
      // still try to decode — some small base64 strings exist (like tiny PNGs)
    }
    try {
      base64Decode(cleaned);
      return true;
    } catch (_) {
      return false;
    }
  }

  Widget _buildImage(String? media) {
    if (media == null || media.isEmpty) {
      return Container(height: 220, color: Colors.grey[200]);
    }

    if (_looksLikeBase64(media)) {
      try {
        final bytes = base64Decode(media);
        return Image.memory(
          bytes,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 220,
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image, size: 64),
          ),
        );
      } catch (e) {
        return Container(
          height: 220,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, size: 64),
        );
      }
    } else {
      // assume it's a URL
      return Image.network(
        media,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                          (progress.expectedTotalBytes ?? 1)
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          height: 220,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, size: 64),
        ),
      );
    }
  }

  // reusable avatar builder: accepts either a base64 string or a URL
  Widget _buildUserAvatar(String? avatar) {
    if (avatar == null || avatar.isEmpty) {
      return const Icon(Icons.person, size: 36);
    }

    final isBase64 = _looksLikeBase64(avatar);

    if (isBase64) {
      try {
        final bytes = base64Decode(avatar);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 36),
        );
      } catch (e) {
        return const Icon(Icons.person, size: 36);
      }
    }

    // fallback → normal URL
    return Image.network(
      avatar,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 36),
    );
  }

  // ---------------------
  // LIKE — implemented via subcollection: /recipes/{recipeId}/likes/{uid}
  Future<void> toggleLikeSubcollection(String recipeId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final likeDoc = FirebaseFirestore.instance
        .collection('recipes')
        .doc(recipeId)
        .collection('likes')
        .doc(uid);

    try {
      final snapshot = await likeDoc.get();
      if (snapshot.exists) {
        await likeDoc.delete();
      } else {
        await likeDoc.set({'userId': uid, 'createdAt': Timestamp.now()});
      }
    } on FirebaseException catch (e) {
      // permission or network error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update like: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected error while liking')),
      );
    }
  }

  // ---------------------
  // SAVE — store per-user under /users/{uid}/savedRecipes/{recipeId}
  Future<void> toggleSavePerUser(String recipeId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final saveDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedRecipes')
        .doc(recipeId);

    try {
      final snap = await saveDoc.get();

      if (snap.exists) {
        // UNSAVE
        await saveDoc.delete();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Removed from saved')));
        }
      } else {
        // SAVE
        await saveDoc.set({
          'recipeId': recipeId,
          'userId': uid,
          'savedAt': Timestamp.now(),
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  // ---------------------
  // COMMENT: adds comment document under /recipes/{recipeId}/comments
  Future<void> addComment(String recipeId, String text) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final ref = FirebaseFirestore.instance
        .collection('recipes')
        .doc(recipeId)
        .collection('comments');

    try {
      await ref.add({
        'text': text,
        'userId': currentUser.uid,
        'username': currentUser.displayName ?? 'User',
        'createdAt': Timestamp.now(),
      });
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add comment: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected error while commenting')),
      );
    }
  }

  Future<void> deleteRecipe(String recipeId) async {
    try {
      await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId)
          .delete();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Recipe deleted')));
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected error while deleting')),
      );
    }
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

  // ---------------------
  // BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildUserSection(),
            Expanded(
              child: _buildFeed(),
            ), // feed takes remaining space (no nested scrollview)
          ],
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person_outline),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserSection() {
    // if we have loaded the Firestore user doc, prefer its photoBase64/photoUrl/username
    String? photoField;
    String? usernameField;

    if (_userDoc != null && _userDoc!.data() != null) {
      final data = _userDoc!.data() as Map<String, dynamic>;
      final photoBase64 = data['photoBase64'] as String?;
      final photoUrl = data['photoUrl'] as String?;
      photoField = (photoBase64 != null && photoBase64.isNotEmpty)
          ? photoBase64
          : (photoUrl ?? user?.photoURL);
      usernameField = data['username'] as String?;
    } else {
      // fallback to FirebaseAuth profile
      photoField = user?.photoURL;
      usernameField = user?.displayName;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 56,
              height: 56,
              child: _buildUserAvatar(photoField),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usernameField ?? user?.displayName ?? "Hello Chef!",
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
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFF45104)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                "No recipes yet 🍽\nBe the first to share one!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return RefreshIndicator(
          onRefresh: () async {
            // just re-pull from server by awaiting one snapshot read
            await FirebaseFirestore.instance.collection('recipes').get();
          },
          child: ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = Map<String, dynamic>.from(doc.data() as Map);
              data['id'] = doc.id;
              return _buildPostCard(data);
            },
          ),
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> recipe) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final recipeId = recipe['id'] as String;
    final createdAt = recipe['createdAt'] as Timestamp?;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: ClipOval(
              child: SizedBox(
                width: 44,
                height: 44,
                child: _buildUserAvatar(recipe['authorPhoto']),
              ),
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
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text("Edit")),
                      PopupMenuItem(value: 'delete', child: Text("Delete")),
                    ],
                  )
                : null,
          ),

          // Media area
          GestureDetector(
            onDoubleTap: () {
              if (currentUserId == null) return;
              // optimistic local heart animation
              _triggerHeart(recipeId);
              toggleLikeSubcollection(recipeId);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildImage(recipe['mediaUrl'] as String?),
                ),
                if (_showHeart[recipeId] == true)
                  const Positioned.fill(
                    child: Center(
                      child: Icon(
                        Icons.favorite,
                        size: 120,
                        color: Colors.white70,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // title + description
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe['title'] ?? "",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                _buildExpandableDescription(
                  recipe['description'] ?? "",
                  recipeId,
                ),
              ],
            ),
          ),

          // actions row — note: counts are computed from subcollections / user saved doc
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                // Likes: show live count from likes subcollection
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('recipes')
                      .doc(recipeId)
                      .collection('likes')
                      .snapshots(),
                  builder: (context, snap) {
                    final likes = snap.hasData ? snap.data!.docs.length : 0;
                    final bool isLiked =
                        snap.hasData &&
                        currentUserId != null &&
                        snap.data!.docs.any((d) => d.id == currentUserId);
                    return Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                          ),
                          color: isLiked ? Colors.red : Colors.black,
                          onPressed: () {
                            if (currentUserId == null) return;
                            _triggerHeart(recipeId);
                            toggleLikeSubcollection(recipeId);
                          },
                        ),
                        Text(likes.toString()),
                      ],
                    );
                  },
                ),

                const SizedBox(width: 8),

                // Comments: live count from comments subcollection
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('recipes')
                      .doc(recipeId)
                      .collection('comments')
                      .snapshots(),
                  builder: (context, snap) {
                    final comments = snap.hasData ? snap.data!.docs.length : 0;
                    return Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline),
                          onPressed: () => _showComments(recipe),
                        ),
                        Text(comments.toString()),
                      ],
                    );
                  },
                ),

                const SizedBox(width: 8),

                // Save: per-user savedRecipes
                StreamBuilder<DocumentSnapshot>(
                  stream: currentUserId != null
                      ? FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUserId)
                            .collection('savedRecipes')
                            .doc(recipeId)
                            .snapshots()
                      : const Stream.empty(),
                  builder: (context, snap) {
                    final saved = snap.hasData && snap.data!.exists;
                    return Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            saved ? Icons.bookmark : Icons.bookmark_border,
                          ),
                          color: saved ? Colors.orange : Colors.black,
                          onPressed: () {
                            if (currentUserId == null) return;
                            toggleSavePerUser(recipeId);
                          },
                        ),
                        // we don't show global save count (it requires different rules). show placeholder or 0
                        const SizedBox(width: 4),
                      ],
                    );
                  },
                ),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    formatTimestamp(createdAt),
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableDescription(String text, String postId) {
    // simple two-line collapse/expand without heavy state: keep toggled state in a Set if needed
    bool isExpanded = false;
    // store expansion in memory keyed by postId using a map on StatefulWidget would be fine,
    // but keep simple: small local approach using a map stored in state
    // We'll implement using a Set in State
    // (create _expandedPosts set if not present)
    // reuse the existing set behavior from your previous code:
    final expanded = <String>{}; // temporary: we'll use real one below

    // Use a real set on state:
    // declare outside: final Set<String> _expandedPosts = {};
    // but we didn't declare above to keep code compact. Let's add it:
    // NOTE: for this rewritten file we already used local earlier, so we'll implement properly below.

    return _ExpandableDescription(text: text);
  }

  // comments bottom sheet
  void _showComments(Map<String, dynamic> recipe) {
    final TextEditingController commentController = TextEditingController();
    final recipeId = recipe['id'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Comments",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              SizedBox(
                height: 320,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('recipes')
                      .doc(recipeId)
                      .collection('comments')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (_, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final comments = snapshot.data!.docs;
                    if (comments.isEmpty)
                      return const Center(child: Text("No comments yet"));
                    return ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (_, index) {
                        final doc = comments[index];
                        final c = Map<String, dynamic>.from(doc.data() as Map);
                        final created = c['createdAt'] as Timestamp?;
                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(c['username'] ?? "User"),
                          subtitle: Text(
                            "${c['text'] ?? ''} • ${formatTimestamp(created)}",
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // comment input
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFFF45104)),
                    onPressed: () {
                      final text = commentController.text.trim();
                      if (text.isEmpty) return;
                      addComment(recipeId, text);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// small reusable widget for expandable description to keep main file tidy
class _ExpandableDescription extends StatefulWidget {
  final String text;
  const _ExpandableDescription({required this.text});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(text: text);
        final tp = TextPainter(
          text: span,
          maxLines: 2,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final isOverflowing = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              maxLines: _expanded ? 999 : 2,
              overflow: TextOverflow.fade,
            ),
            if (isOverflowing)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    _expanded ? "Show less" : "Read more",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
