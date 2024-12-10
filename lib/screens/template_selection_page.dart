import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class TemplateSelectionPage extends StatelessWidget {
  final Function(File) onTemplateSelected;

  const TemplateSelectionPage({super.key, required this.onTemplateSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Template'),
      ),
      body: FutureBuilder<List<File>>(
        future: _loadTemplates(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final templates = snapshot.data ?? [];

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return GestureDetector(
                onTap: () {
                  onTemplateSelected(template);
                  Navigator.pop(context); // Close the selection screen
                },
                child: Image.file(
                  template,
                  fit: BoxFit.cover,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<File>> _loadTemplates() async {
    final directory = await getApplicationDocumentsDirectory();
    final memesDir = Directory('${directory.path}/data/assets/images/memes');
    return memesDir.listSync()
        .where((item) => item is File && (item.path.endsWith('.png') || item.path.endsWith('.jpg')))
        .map((item) => item as File)
        .toList();
  }
} 