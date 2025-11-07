import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _posts = [
    {
      'username': 'Ferdaoues Aouachri',
      'userImage': 'https://i.pravatar.cc/100?img=1',
      'postImage': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836',
      'description': '🍝 Pasta alla carbonara — simple & delicious!',
      'likes': 120,
      'isLiked': false,
      'isFavorite': false,
      'rating': 4.5,
      'comments': [
        {'user': 'Aya', 'text': 'Looks amazing!', 'stars': 5},
        {'user': 'Mouna', 'text': 'Tried it today ❤️', 'stars': 4},
      ]
    },
    {
      'username': 'Ali Ben',
      'userImage': 'https://i.pravatar.cc/100?img=2',
      'postImage': 'https://images.unsplash.com/photo-1617196036556-0c4b7e0b8a58',
      'description': '🍰 My favorite homemade cheesecake 😋',
      'likes': 88,
      'isLiked': false,
      'isFavorite': false,
      'rating': 5,
      'comments': [
        {'user': 'Sara', 'text': 'Looks delicious!', 'stars': 5},
      ]
    },
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 🔝 HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "SmartMeal",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: Colors.black),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // ✍️ ADD POST SECTION
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.black12),
                  bottom: BorderSide(color: Colors.black12),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=5'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Share your recipe idea...",
                        hintStyle: const TextStyle(color: Colors.black54),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onTap: () {
                        // Navigate to "Add Recipe" page later
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.image, color: Color(0xFFF45104)),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam, color: Color(0xFFF45104)),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // 🧾 FEED LIST
            Expanded(
              child: ListView.builder(
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return _buildPostCard(post, index);
                },
              ),
            ),
          ],
        ),
      ),

      // 🔻 BOTTOM NAVIGATION
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFF45104),
        unselectedItemColor: Colors.black,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Favorites"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  // 🧩 SINGLE POST CARD WIDGET
  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 0.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // USER HEADER
          ListTile(
            leading: CircleAvatar(backgroundImage: NetworkImage(post['userImage'])),
            title: Text(
              post['username'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text("2 hrs ago", style: TextStyle(color: Colors.black54)),
            trailing: const Icon(Icons.more_vert),
          ),

          // IMAGE / VIDEO
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(post['postImage'], fit: BoxFit.cover),
          ),

          // DESCRIPTION
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(post['description']),
          ),

          // ACTION BUTTONS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        post['isLiked'] ? Icons.favorite : Icons.favorite_border,
                        color: post['isLiked'] ? const Color(0xFFF45104) : Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          post['isLiked'] = !post['isLiked'];
                          post['likes'] += post['isLiked'] ? 1 : -1;
                        });
                      },
                    ),
                    Text("${post['likes']}"),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () => _showComments(post),
                    ),
                    IconButton(
                      icon: Icon(
                        post['isFavorite'] ? Icons.bookmark : Icons.bookmark_border,
                        color: post['isFavorite']
                            ? const Color(0xFFF45104)
                            : Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          post['isFavorite'] = !post['isFavorite'];
                        });
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFF45104), size: 20),
                    Text("${post['rating']}"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 💬 COMMENTS POPUP
  void _showComments(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Comments & Ratings",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Divider(),
                ...post['comments'].map<Widget>((c) {
                  return ListTile(
                    leading: const Icon(Icons.person, color: Colors.black54),
                    title: Text(c['user']),
                    subtitle: Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < c['stars']
                                ? Icons.star
                                : Icons.star_border_outlined,
                            color: const Color(0xFFF45104),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(c['text']),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    hintText: "Write a comment...",
                    suffixIcon: const Icon(Icons.send, color: Color(0xFFF45104)),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
