import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';
import 'add_recipe_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? uid;
  const ProfileScreen({super.key, this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String get viewedUid => widget.uid ?? FirebaseAuth.instance.currentUser!.uid;
  String? currentUid;
  Stream<DocumentSnapshot>? userStream;
  Stream<QuerySnapshot>? postsStream;
  Stream<QuerySnapshot>? savedStream;
  int totalLikes = 0;

  @override
  void initState() {
    super.initState();
    currentUid = FirebaseAuth.instance.currentUser?.uid;
    _tabController = TabController(length: 2, vsync: this);
    userStream = FirebaseFirestore.instance.collection('users').doc(viewedUid).snapshots();
    postsStream = FirebaseFirestore.instance.collection('recipes').where('userId', isEqualTo: viewedUid).snapshots();
    savedStream = currentUid == null
        ? null
        : FirebaseFirestore.instance.collection('recipes').where('savers', arrayContains: currentUid).snapshots();

    // aggregate likes
    FirebaseFirestore.instance
        .collection('recipes')
        .where('userId', isEqualTo: viewedUid)
        .snapshots()
        .listen((snap) {
      int sum = 0;
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        sum += (data['likesCount'] ?? 0) as int;
      }
      setState(() => totalLikes = sum);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _avatarWidget(String? photoBase64) {
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      return CircleAvatar(radius: 56, backgroundImage: MemoryImage(base64Decode(photoBase64)));
    }
    return const CircleAvatar(radius: 56, child: Icon(Icons.person, size: 40));
  }

  Widget _statItem(String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwn = currentUid != null && viewedUid == currentUid;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: Navigator.canPop(context) ? BackButton(color: Colors.black) : null,
        centerTitle: true,
        title: const Text('Profile', style: TextStyle(color: Colors.black, fontFamily: 'Inter')),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: userStream,
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFF45104)));
          }
          if (!userSnap.hasData || !userSnap.data!.exists) {
            return const Center(child: Text('User not found'));
          }

          final userData = Map<String, dynamic>.from(userSnap.data!.data() as Map);
          final username = userData['username'] ?? 'user';
          final bio = userData['bio'] ?? '';
          final followers = (userData['followers'] as List?) ?? [];
          final following = (userData['following'] as List?) ?? [];
          final photoBase64 = userData['photoBase64'] as String?;

          final followersCount = followers.length;
          final followingCount = following.length;
          final isFollowing = currentUid != null && followers.contains(currentUid);

          return Column(
            children: [
              const SizedBox(height: 20),
              Center(child: _avatarWidget(photoBase64)),
              const SizedBox(height: 12),
              Text('@$username', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statItem('Likes', totalLikes),
                  const SizedBox(width: 36),
                  _statItem('Followers', followersCount),
                  const SizedBox(width: 36),
                  _statItem('Following', followingCount),
                ],
              ),
              const SizedBox(height: 12),
              if (bio.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87)),
                ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: SizedBox(
                  width: double.infinity,
                  child: isOwn
                      ? OutlinedButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EditProfileScreen(userData: userData)),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFF45104), width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'Edit profile',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF45104), // match theme color
                            fontFamily: 'Inter',
                            fontSize: 16,
                          ),
                        ),
                      )

                      : ElevatedButton(
                          onPressed: () async {
                            // implement follow toggle if needed
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFollowing ? Colors.grey[300] : Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(isFollowing ? 'Following' : 'Follow',
                              style: TextStyle(color: isFollowing ? Colors.black : Colors.white, fontWeight: FontWeight.w600)),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.black,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on), text: 'Posts'),
                  Tab(icon: Icon(Icons.bookmark), text: 'Saved'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Posts grid
                    StreamBuilder<QuerySnapshot>(
                      stream: postsStream,
                      builder: (context, snap) {
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                        final docs = snap.data!.docs;
                        if (docs.isEmpty) return const Center(child: Text('No posts yet'));
                        return GridView.builder(
                          padding: const EdgeInsets.all(6),
                          itemCount: docs.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
                          itemBuilder: (context, i) {
                            final d = docs[i];
                            final data = Map<String, dynamic>.from(d.data() as Map);
                            return GestureDetector(
                              onTap: () {
                                if (currentUid == viewedUid) {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => AddRecipeScreen(recipe: {...data, 'id': d.id})));
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: data['images'] != null && (data['images'] as List).isNotEmpty
                                    ? Image.memory(base64Decode(data['images'][0]), fit: BoxFit.cover)
                                    : Container(color: Colors.grey[200]),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    // Saved tab
                    (currentUid == null)
                        ? const Center(child: Text('Login to see saved posts'))
                        : StreamBuilder<QuerySnapshot>(
                            stream: savedStream,
                            builder: (context, snap) {
                              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                              final docs = snap.data!.docs;
                              if (docs.isEmpty) return const Center(child: Text('No saved posts'));
                              return GridView.builder(
                                padding: const EdgeInsets.all(6),
                                itemCount: docs.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
                                itemBuilder: (context, i) {
                                  final d = docs[i];
                                  final data = Map<String, dynamic>.from(d.data() as Map);
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: data['images'] != null && (data['images'] as List).isNotEmpty
                                        ? Image.memory(base64Decode(data['images'][0]), fit: BoxFit.cover)
                                        : Container(color: Colors.grey[200]),
                                  );
                                },
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
