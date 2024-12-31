import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'drawing_page.dart';

final List<String> imagePaths = [
  'data/assets/images/memes/meme_1.jpeg',
  'data/assets/images/memes/meme_2.png',
  'data/assets/images/memes/meme_3.png',
  'data/assets/images/memes/meme_4.png',
  'data/assets/images/memes/meme_5.png',
  'data/assets/images/memes/meme_6.png',
  'data/assets/images/memes/meme_7.png',
  'data/assets/images/memes/meme_8.jpeg',
  'data/assets/images/memes/meme_9.jpg',
];

class TemplateSelectionPage extends StatelessWidget {
  final String userId;
  final Function(File) onTemplateSelected;

  const TemplateSelectionPage({
    Key? key,
    required this.userId,
    required this.onTemplateSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Template'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: imagePaths.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () async {
              final tempDir = await getTemporaryDirectory();
              final tempFile = File('${tempDir.path}/template_$index.png');
              
              final byteData = await rootBundle.load(imagePaths[index]);
              await tempFile.writeAsBytes(
                byteData.buffer.asUint8List(
                  byteData.offsetInBytes,
                  byteData.lengthInBytes,
                ),
              );
              
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DrawingPage(
                    userId: userId,
                    selectedImage: tempFile,
                  ),
                ),
              );
            },
            child: Card(
              child: Image.asset(
                imagePaths[index],
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }
} 