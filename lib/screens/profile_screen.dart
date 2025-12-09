import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'edit_profile_screen.dart';
import 'recipe_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? uid;
  const ProfileScreen({super.key, this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String get viewedUid =>
      widget.uid ?? FirebaseAuth.instance.currentUser!.uid;
  String? currentUid;

  Stream<DocumentSnapshot>? userStream;
  Stream<QuerySnapshot>? postsStream;

  int totalLikes = 0;
  int totalSaves = 0;

  @override
  void initState() {
    super.initState();
    currentUid = FirebaseAuth.instance.currentUser?.uid;

    _tabController = TabController(length: 2, vsync: this);

    userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(viewedUid)
        .snapshots();

    postsStream = FirebaseFirestore.instance
        .collection('recipes')
        .where('userId', isEqualTo: viewedUid)
        .snapshots();

    _listenToTotals();
  }

  // -----------------------------
  // TOTAL LIKES + SAVES
  // -----------------------------
  void _listenToTotals() {
    FirebaseFirestore.instance
        .collection('recipes')
        .where('userId', isEqualTo: viewedUid)
        .snapshots()
        .listen((snap) {
      int likeSum = 0;
      int saveSum = 0;

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;

        likeSum += (data['likesCount'] ?? 0) as int;

        final savers = data['savers'] as List? ?? [];
        saveSum += savers.length;
      }

      setState(() {
        totalLikes = likeSum;
        totalSaves = saveSum;
      });
    });
  }

  // -----------------------------
  // GET SAVED POSTS STREAM
  // -----------------------------
  Stream<QuerySnapshot> getSavedPostsStream(String uid) async* {
    final savedDocs = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedRecipes')
        .get();

    final ids =
        savedDocs.docs.map((d) => d['recipeId'] as String).toList();

    if (ids.isEmpty) {
      yield QuerySnapshotFake([]);
      return;
    }

    yield* FirebaseFirestore.instance
        .collection('recipes')
        .where(FieldPath.documentId, whereIn: ids)
        .snapshots();
  }

  // -----------------------------
  // IMAGE BUILDER (BASE64 / URL)
  // -----------------------------
  Widget _buildRecipeImage(Map<String, dynamic> data) {
    String? media = data['mediaUrl'];

    if (media == null || media.isEmpty) {
      return Container(color: Colors.grey[200]);
    }

    try {
      final bytes = base64Decode(media);
      return Image.memory(bytes, fit: BoxFit.cover);
    } catch (_) {
      return Image.network(
        media,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Container(color: Colors.grey[200]),
      );
    }
  }

  // -----------------------------
  // AVATAR BUILDER
  // -----------------------------
  Widget _avatarWidget(String? photoBase64) {
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      return CircleAvatar(
        radius: 56,
        backgroundImage: MemoryImage(base64Decode(photoBase64)),
      );
    }
    return const CircleAvatar(
        radius: 56, child: Icon(Icons.person, size: 40));
  }

  // -----------------------------
  // STAT LABEL
  // -----------------------------
  Widget _statItem(String label, int value) {
    return Column(
      children: [
        Text(value.toString(),
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwn = currentUid == viewedUid;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading:
            Navigator.canPop(context) ? BackButton(color: Colors.black) : null,
        centerTitle: true,
        title:
            const Text('Profile', style: TextStyle(color: Colors.black)),
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: userStream,
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFF45104)));
          }

          final data =
              userSnap.data!.data() as Map<String, dynamic>? ?? {};
          final username = data['username'] ?? "user";
          final bio = data['bio'] ?? "";
          final photoBase64 = data['photoBase64'];

          return Column(
            children: [
              const SizedBox(height: 20),
              Center(child: _avatarWidget(photoBase64)),
              const SizedBox(height: 12),
              Text('@$username',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 18)),
              const SizedBox(height: 12),

              // -----------------------------
              // STATS (LIKES + SAVES)
              // -----------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statItem("Likes", totalLikes),
                  const SizedBox(width: 36),
                  _statItem("Saved", totalSaves),
                ],
              ),

              const SizedBox(height: 12),
              if (bio.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Text(bio,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black87)),
                ),

              const SizedBox(height: 14),

              // -----------------------------
              // EDIT BUTTON
              // -----------------------------
              if (isOwn)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  EditProfileScreen(userData: data)),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                            color: Color(0xFFF45104), width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Edit Profile',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF45104),
                            fontFamily: 'Inter',
                            fontSize: 16),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // -----------------------------
              // TABS
              // -----------------------------
              TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.black,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on), text: "Posts"),
                  Tab(icon: Icon(Icons.bookmark), text: "Saved"),
                ],
              ),

              // -----------------------------
              // TAB CONTENT
              // -----------------------------
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPostsGrid(),
                    _buildSavedGrid(),
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }

  // -----------------------------
  // POSTS GRID
  // -----------------------------
  Widget _buildPostsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: postsStream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No posts yet"));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(6),
          itemCount: docs.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data =
                Map<String, dynamic>.from(d.data() as Map);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => RecipeDetailScreen(
                              recipeId: d.id,
                            )));
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _buildRecipeImage(data),
              ),
            );
          },
        );
      },
    );
  }

  // -----------------------------
  // SAVED GRID
  // -----------------------------
  Widget _buildSavedGrid() {
    if (currentUid == null) {
      return const Center(child: Text("Login to see saved posts"));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: getSavedPostsStream(currentUid!),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No saved posts"));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(6),
          itemCount: docs.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4),
          itemBuilder: (context, i) {
            final data =
                Map<String, dynamic>.from(docs[i].data() as Map);

            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _buildRecipeImage(data),
            );
          },
        );
      },
    );
  }
}

// SMALL FAKE SNAPSHOT CLASS FOR EMPTY STREAMS

class QuerySnapshotFake implements QuerySnapshot {
  final List<QueryDocumentSnapshot> _docs;

  QuerySnapshotFake(this._docs);

  @override
  List<QueryDocumentSnapshot> get docs => _docs;

  /* EVERYTHING ELSE UNUSED */
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
