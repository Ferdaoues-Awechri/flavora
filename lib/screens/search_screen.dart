import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'recipe_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  // ---------------------- RECENT SEARCHES ----------------------
  Future<void> _loadRecentSearches() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList("recent_searches") ?? [];
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (_recentSearches.contains(query)) {
      _recentSearches.remove(query);
    }
    _recentSearches.insert(0, query);

    if (_recentSearches.length > 10) {
      _recentSearches.removeLast();
    }

    await prefs.setStringList("recent_searches", _recentSearches);
  }

  // ---------------------- SEARCH FIRESTORE ----------------------
  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);

    final q = query.toLowerCase();

    try {
      // 🔥 TITLE
      final titleSnap = await FirebaseFirestore.instance
          .collection('recipes')
          .where('titleLower', isGreaterThanOrEqualTo: q)
          .where('titleLower', isLessThanOrEqualTo: '$q\uf8ff')
          .get();

      // 🔥 USERNAME
      final usernameSnap = await FirebaseFirestore.instance
          .collection('recipes')
          .where('usernameLower', isGreaterThanOrEqualTo: q)
          .where('usernameLower', isLessThanOrEqualTo: '$q\uf8ff')
          .get();

      // 🔥 TAGS
      final tagSnap = await FirebaseFirestore.instance
          .collection('recipes')
          .where('tagsLower', arrayContains: q)
          .get();

      final combined = [
        ...titleSnap.docs,
        ...usernameSnap.docs,
        ...tagSnap.docs
      ];

      final unique = {
        for (var d in combined) d.id: d
      }.values.toList();

      setState(() {
        _results = unique
            .map((d) => {"id": d.id, ...d.data() as Map<String, dynamic>})
            .toList();
        _isSearching = false;
      });

      await _saveRecentSearch(query);

    } catch (e) {
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Search error: $e")),
      );
    }
  }

  // ---------------------- IMAGE HANDLER ----------------------
  Widget _buildImage(String? media) {
    if (media == null || media.isEmpty) {
      return Container(height: 120, color: Colors.grey[200]);
    }

    final isBase64 = RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(media);
    if (isBase64) {
      try {
        final bytes = base64Decode(media);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }

    return Image.network(
      media,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Container(color: Colors.grey[300], child: const Icon(Icons.image)),
    );
  }

  // ---------------------- HIGHLIGHT MATCHED WORDS ----------------------
  Text _highlight(String text, String query) {
    if (query.isEmpty) return Text(text);

    final lower = text.toLowerCase();
    final q = query.toLowerCase();

    if (!lower.contains(q)) return Text(text);

    final start = lower.indexOf(q);
    final end = start + q.length;

    return Text.rich(
      TextSpan(children: [
        TextSpan(text: text.substring(0, start)),
        TextSpan(
          text: text.substring(start, end),
          style: const TextStyle(
            backgroundColor: Colors.yellow,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(text: text.substring(end)),
      ]),
      style: const TextStyle(fontSize: 16, fontFamily: 'Inter'),
    );
  }

  // ---------------------- UI ----------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search recipes...',
            hintStyle: TextStyle(color: Colors.black45),
            border: InputBorder.none,
          ),
          style: const TextStyle(fontFamily: 'Inter', color: Colors.black),
          onChanged: _search,
        ),
      ),

      body: _isSearching
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF45104)))

          // ------------------- Recent Searches -------------------
          : _searchController.text.isEmpty && _recentSearches.isNotEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: _recentSearches
                      .map((e) => ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(e),
                            onTap: () {
                              _searchController.text = e;
                              _search(e);
                            },
                          ))
                      .toList(),
                )

          // ------------------- No Results -------------------
          : _results.isEmpty
              ? const Center(
                  child: Text(
                    "No recipes found",
                    style: TextStyle(fontFamily: 'Inter', color: Colors.black54),
                  ),
                )

          // ------------------- RESULTS -------------------
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final r = _results[index];
                    final query = _searchController.text;

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RecipeDetailScreen(recipeId: r['id']),
                        ),
                      ),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12)),
                              child: SizedBox(
                                height: 150,
                                width: double.infinity,
                                child: _buildImage(r['mediaUrl']),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _highlight(r['title'] ?? "Untitled", query),

                                  const SizedBox(height: 4),

                                  _highlight(r['username'] ?? "", query),

                                  const SizedBox(height: 6),

                                  if (r['tags'] != null)
                                    Text(
                                      "#${(r['tags'] as List).join(" #")}",
                                      style: const TextStyle(
                                          fontFamily: 'Inter',
                                          color: Colors.black54),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
