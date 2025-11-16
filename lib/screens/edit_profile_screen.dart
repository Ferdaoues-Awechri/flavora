import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  Uint8List? _avatarBytes; // new avatar bytes
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.userData['username'] ?? '');
    _bioController = TextEditingController(text: widget.userData['bio'] ?? '');
    // load avatar from base64 if exists
    final photoB64 = widget.userData['photoBase64'] as String?;
    if (photoB64 != null && photoB64.isNotEmpty) {
      _avatarBytes = base64Decode(photoB64);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _avatarBytes = bytes);
    } catch (e) {
      _showToast('⚠️ Error picking image: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final data = {
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'photoBase64': _avatarBytes != null ? base64Encode(_avatarBytes!) : null,
        'lastLogin': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(data);

      _showToast('✅ Profile updated!');
      Navigator.pop(context); // back to profile
    } catch (e) {
      _showToast('❌ Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFFAC0033),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _avatarWidget() {
    if (_avatarBytes != null) {
      return CircleAvatar(radius: 56, backgroundImage: MemoryImage(_avatarBytes!));
    }
    return const CircleAvatar(radius: 56, child: Icon(Icons.person, size: 40));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile', style: TextStyle(color: Color(0xFF344054), fontFamily: 'Inter')),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF344054)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _avatarWidget(),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickAvatar,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Change avatar'),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _usernameController,
                    decoration: _inputDecoration('Username'),
                    validator: (v) => v == null || v.trim().length < 3 ? 'Enter 3+ characters' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bioController,
                    decoration: _inputDecoration('Bio'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF45104),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600,color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF667085), fontFamily: 'Inter'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)), borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFF45104)), borderRadius: BorderRadius.circular(8)),
    );
  }
}
