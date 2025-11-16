import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LikedByScreen extends StatelessWidget {
  final List<dynamic> likes;
  const LikedByScreen({super.key, required this.likes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Liked by")),
      body: ListView.builder(
        itemCount: likes.length,
        itemBuilder: (context, index) {
          final uid = likes[index];

          return FutureBuilder(
            future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const ListTile(title: Text("Loading..."));

              final user = snapshot.data!;
              return ListTile(
                leading: CircleAvatar(
                    backgroundImage: NetworkImage(user['avatar'] ?? "")),
                title: Text(user['name'] ?? "User"),
                subtitle: Text(user['email'] ?? ""),
              );
            },
          );
        },
      ),
    );
  }
}
