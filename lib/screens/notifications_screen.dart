import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Notifications',
          style: TextStyle(
              color: Colors.black, fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
      ),
      body: const Center(
        child: Text(
          "No notifications yet",
          style: TextStyle(fontSize: 16, color: Colors.black54, fontFamily: 'Inter'),
        ),
      ),
    );
  }
}
