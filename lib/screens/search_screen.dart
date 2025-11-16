import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _results = []; // placeholder for search results

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
          decoration: const InputDecoration(
            hintText: 'Search recipes...',
            hintStyle: TextStyle(color: Colors.black38),
            border: InputBorder.none,
          ),
          style: const TextStyle(color: Colors.black, fontFamily: 'Inter'),
          onChanged: (val) {
            // TODO: implement search logic (API / Firestore)
            setState(() {
              _results = val.isEmpty ? [] : ['Recipe 1', 'Recipe 2', 'Recipe 3'];
            });
          },
        ),
      ),
      body: _results.isEmpty
          ? const Center(
              child: Text(
                "Search for recipes",
                style: TextStyle(color: Colors.black54, fontFamily: 'Inter'),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final recipe = _results[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    title: Text(recipe,
                        style: const TextStyle(
                            fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // TODO: navigate to RecipeDetails
                    },
                  ),
                );
              },
            ),
    );
  }
}
