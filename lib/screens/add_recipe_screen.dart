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
  final Map<String, dynamic>? recipe; // optional for edit
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
  bool _isLoading = false;

  List<String> _existingImages = [];

  @override
  void initState() {
    super.initState();
    if (widget.recipe != null) {
      final r = widget.recipe!;
      _titleController.text = r['title'] ?? '';
      _descriptionController.text = r['description'] ?? '';
      final tags = r['tags'] is List ? (r['tags'] as List).join(', ') : '';
      _tagsController.text = tags;
      _existingImages = r['images'] != null ? List<String>.from(r['images']) : [];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  // ---------------- PICK MULTIPLE IMAGES ----------------
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

  // ---------------- SUBMIT ----------------
  Future<void> _submitRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFiles.isEmpty && _webImages.isEmpty && _existingImages.isEmpty) {
      _showToast('Please pick at least one image.');
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
      // Convert picked files to base64
      List<String> newImages = [];
      if (kIsWeb) {
        newImages = _webImages.map((b) => base64Encode(b)).toList();
      } else {
        for (var file in _pickedFiles) {
          final bytes = await file.readAsBytes(); // fixed Web/Mobile compatibility
          newImages.add(base64Encode(bytes));
        }
      }

      final allImages = [..._existingImages, ...newImages];

      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'tags': _tagsController.text
            .split(',')
            .map((t) => t.trim().toLowerCase())
            .where((t) => t.isNotEmpty)
            .toList(),
        'images': allImages,
        'userId': user.uid,
        'username': user.displayName ?? 'User',
        'photoUrl': user.photoURL ?? 'https://i.pravatar.cc/150',
        'likes': widget.recipe != null ? widget.recipe!['likes'] ?? [] : [],
        'savers': widget.recipe != null ? widget.recipe!['savers'] ?? [] : [],
        'likesCount': widget.recipe != null ? widget.recipe!['likesCount'] ?? 0 : 0,
        'savesCount': widget.recipe != null ? widget.recipe!['savesCount'] ?? 0 : 0,
        'commentsCount': widget.recipe != null ? widget.recipe!['commentsCount'] ?? 0 : 0,
        'createdAt': widget.recipe != null ? widget.recipe!['createdAt'] ?? FieldValue.serverTimestamp() : FieldValue.serverTimestamp(),
      };

      if (widget.recipe != null && widget.recipe!.containsKey('id')) {
        await FirebaseFirestore.instance.collection('recipes').doc(widget.recipe!['id']).update(data);
        _showToast('Recipe updated!');
      } else {
        await FirebaseFirestore.instance.collection('recipes').add(data);
        _showToast('Recipe added!');
      }

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      _showToast('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFF45104),
    ));
  }

  // ---------------- IMAGE PREVIEW ----------------
  Widget _buildImagesPreview() {
    List<Widget> widgets = [];

    // existing images
    for (int i = 0; i < _existingImages.length; i++) {
      widgets.add(Stack(
        children: [
          Image.memory(base64Decode(_existingImages[i]), height: 100, width: 100, fit: BoxFit.cover),
          Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                  onTap: () => setState(() => _existingImages.removeAt(i)),
                  child: const Icon(Icons.cancel, color: Colors.red))),
        ],
      ));
    }

    // new web images
    for (int i = 0; i < _webImages.length; i++) {
      widgets.add(Stack(
        children: [
          Image.memory(_webImages[i], height: 100, width: 100, fit: BoxFit.cover),
          Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                  onTap: () => setState(() => _webImages.removeAt(i)),
                  child: const Icon(Icons.cancel, color: Colors.red))),
        ],
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: widgets.map((w) => Padding(padding: const EdgeInsets.all(4), child: w)).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(widget.recipe != null ? 'Edit Recipe' : 'Add Recipe', style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 4,
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter description' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                  hintText: 'e.g. vegan, pasta, easy',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD0D5DD)), borderRadius: BorderRadius.circular(8), color: Colors.white),
                      child: const Center(
                        child: Icon(Icons.image, color: Color(0xFFF45104), size: 40),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildImagesPreview()),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRecipe,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: const Color(0xFFF45104)),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(widget.recipe != null ? 'Save' : 'Add Recipe'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
