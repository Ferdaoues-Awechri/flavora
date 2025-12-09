// lib/screens/add_recipe_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'home_screen.dart';

class AddRecipeScreen extends StatefulWidget {
  final Map<String, dynamic>? recipe;
  const AddRecipeScreen({super.key, this.recipe});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  List<XFile> _pickedFiles = [];
  List<Uint8List> _webImages = [];
  List<String> _existingImages = [];
  bool _isLoading = false;

  String? _userPhotoBase64; // 🔥 Will store Firestore user photo

  @override
  void initState() {
    super.initState();

    _loadUserPhotoBase64(); // 🔥 load correct photo

    if (widget.recipe != null) {
      final r = widget.recipe!;
      _titleController.text = r['title'] ?? '';
      _descriptionController.text = r['description'] ?? '';
      final tags = r['tags'] is List ? (r['tags'] as List).join(', ') : '';
      _tagsController.text = tags;
      _existingImages =
          r['images'] != null ? List<String>.from(r['images']) : [];
    }
  }

  Future<void> _loadUserPhotoBase64() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (doc.exists && doc.data()!.containsKey('photoBase64')) {
      setState(() {
        _userPhotoBase64 = doc['photoBase64'];
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  // PICK IMAGES
  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(imageQuality: 80);
      if (picked == null || picked.isEmpty) return;

      if (kIsWeb) {
        for (var file in picked) {
          final bytes = await file.readAsBytes();
          _webImages.add(bytes);
        }
      } else {
        _pickedFiles.addAll(picked);
      }
      setState(() {});
    } catch (e) {
      _showToast('Error picking images: $e');
    }
  }

  // SUBMIT RECIPE
  Future<void> _submitRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedFiles.isEmpty &&
        _webImages.isEmpty &&
        _existingImages.isEmpty) {
      _showToast('Please pick at least one image.');
      return;
    }

    if (_userPhotoBase64 == null || _userPhotoBase64!.isEmpty) {
      _showToast("Error: Your profile photo is missing.");
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showToast('You must be logged in.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Select first image
      String mediaUrl;

      if (_existingImages.isNotEmpty) {
        mediaUrl = _existingImages.first;
      } else if (kIsWeb) {
        mediaUrl = base64Encode(_webImages.first);
      } else {
        final bytes = await _pickedFiles.first.readAsBytes();
        mediaUrl = base64Encode(bytes);
      }

      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'mediaUrl': mediaUrl,
        'tags': _tagsController.text
            .split(',')
            .map((t) => t.trim().toLowerCase())
            .where((t) => t.isNotEmpty)
            .toList(),
        'userId': user.uid,
        'username': user.displayName ?? 'User',

        // 🔥 FIXED — correct profile photo
        'authorPhoto': _userPhotoBase64,

        'createdAt': FieldValue.serverTimestamp(),
      };

      if (widget.recipe != null && widget.recipe!.containsKey('id')) {
        await FirebaseFirestore.instance
            .collection('recipes')
            .doc(widget.recipe!['id'])
            .update(data);
        _showToast('Recipe updated!');
      } else {
        await FirebaseFirestore.instance.collection('recipes').add(data);
        _showToast('Recipe added!');
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      _showToast('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFF45104),
      ),
    );
  }

  // IMAGE PREVIEW
  Widget _buildImagesPreview() {
    List<Widget> widgets = [];

    // existing base64 images
    for (int i = 0; i < _existingImages.length; i++) {
      widgets.add(
        Stack(
          children: [
            Image.memory(
              base64Decode(_existingImages[i]),
              height: 100,
              width: 100,
              fit: BoxFit.cover,
            ),
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                onTap: () => setState(() => _existingImages.removeAt(i)),
                child: const Icon(Icons.cancel, color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }

    // web images
    for (int i = 0; i < _webImages.length; i++) {
      widgets.add(
        Stack(
          children: [
            Image.memory(
              _webImages[i],
              height: 100,
              width: 100,
              fit: BoxFit.cover,
            ),
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                onTap: () => setState(() => _webImages.removeAt(i)),
                child: const Icon(Icons.cancel, color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: widgets
            .map((w) => Padding(padding: const EdgeInsets.all(4), child: w))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          widget.recipe != null ? 'Edit Recipe' : 'Add Recipe',
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter title' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _descriptionController,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                    maxLines: 4,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter description'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags (comma separated)',
                      hintText: 'e.g. vegan, pasta, easy',
                    ),
                  ),
                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.image),
                      label: const Text('Pick Images'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF45104),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  _buildImagesPreview(),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRecipe,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: const Color(0xFFF45104),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                            widget.recipe != null ? 'Save' : 'Add Recipe',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
}
