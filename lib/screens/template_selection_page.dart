import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';

class TemplateSelectionPage extends StatelessWidget {
  final Function(File) onTemplateSelected;

  const TemplateSelectionPage({
    Key? key,
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
              // Asset'i geçici bir dosyaya kopyala
              final tempDir = await getTemporaryDirectory();
              final tempFile = File('${tempDir.path}/template_$index.png');
              
              // Asset'i oku ve dosyaya yaz
              final byteData = await rootBundle.load(imagePaths[index]);
              await tempFile.writeAsBytes(
                byteData.buffer.asUint8List(
                  byteData.offsetInBytes,
                  byteData.lengthInBytes,
                ),
              );
              
              onTemplateSelected(tempFile);
              Navigator.pop(context);
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