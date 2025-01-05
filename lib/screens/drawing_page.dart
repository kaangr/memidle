import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_service.dart';
import 'dart:ui' as ui;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'saved_memes_page.dart';
import 'package:path_provider/path_provider.dart';
import 'template_selection_page.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MemeTextWidget {
  String text;
  Offset position;
  double fontSize;
  Color color;
  double strokeWidth;
  Color strokeColor;

  MemeTextWidget({
    required this.text,
    required this.position,
    required this.fontSize,
    required this.color,
    this.strokeWidth = 0.0,
    this.strokeColor = Colors.black,
  });
  
  set shadowColor(Color shadowColor) {}
  
  set blurRadius(double blurRadius) {}
}

class DrawingPage extends StatefulWidget {
  final String userId;
  final File? selectedImage;

  const DrawingPage({
    super.key,
    required this.userId,
    this.selectedImage,
  });

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  File? _selectedImage;
  final _textController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();
  List<MemeTextWidget> _memeTexts = [];
  int? _selectedTextIndex;
  
  double _currentFontSize = 24;
  Color _currentColor = Colors.white;
  double _currentStrokeWidth = 0;
  Color _currentStrokeColor = Colors.black;
  double _currentBlurRadius = 3;
 

  @override
  void initState() {
    super.initState();
    if (widget.selectedImage != null) {
      _selectedImage = widget.selectedImage;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Meme'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveMeme,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedImage != null)
            Expanded(
              child: Stack(
                children: [
                  InteractiveViewer(
                    child: Image.file(_selectedImage!),
                  ),
                  ..._memeTexts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final text = entry.value;
                    return Positioned(
                      left: text.position.dx,
                      top: text.position.dy,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTextIndex = index;
                            _textController.text = text.text;
                            _currentFontSize = text.fontSize;
                            _currentColor = text.color;
                            _currentStrokeWidth = text.strokeWidth;
                            _currentStrokeColor = text.strokeColor;
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            text.position += details.delta;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: _selectedTextIndex == index
                                ? Border.all(color: Colors.blue, width: 1)
                                : null,
                          ),
                          child: Text(
                            text.text,
                            style: TextStyle(
                              fontSize: text.fontSize,
                              color: text.color,
                              shadows: [
                                Shadow(
                                  color: text.strokeColor,
                                  blurRadius: _currentBlurRadius,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Text('No image selected'),
              ),
            ),
          if (_selectedTextIndex != null) _buildTextEditingPanel(),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.photo_camera),
              onPressed: () => _pickImage(ImageSource.camera),
            ),
            IconButton(
              icon: const Icon(Icons.photo),
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
            IconButton(
              icon: const Icon(Icons.text_fields),
              onPressed: _addNewText,
            ),
            IconButton(
              icon: const Icon(Icons.grid_view),
              onPressed: _selectTemplate,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMeme() async {
    if (_selectedImage == null || _memeTexts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image and add text first')),
      );
      return;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      final image = await _loadImage(_selectedImage!.path);
      canvas.drawImage(image, Offset.zero, Paint());
      
      // Tüm metinleri çiz
      for (final memeText in _memeTexts) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: memeText.text,
            style: TextStyle(
              fontSize: memeText.fontSize,
              color: memeText.color,
              shadows: [
                Shadow(
                  color: memeText.strokeColor,
                  blurRadius: _currentBlurRadius,
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        
        final screenSize = MediaQuery.of(context).size;
        final scale = image.width / screenSize.width;
        
        final scaledPosition = Offset(
          memeText.position.dx * scale,
          memeText.position.dy * scale,
        );
        
        textPainter.paint(canvas, scaledPosition);
      }

      // Geçici dosya oluştur
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_meme_${DateTime.now().millisecondsSinceEpoch}.png');
      final img = await recorder.endRecording().toImage(image.width, image.height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      await tempFile.writeAsBytes(byteData!.buffer.asUint8List());

      print('Uploading meme for user: ${widget.userId}');
      
      // Firebase Storage'a yükle
      final downloadUrl = await _firebaseService.uploadMeme(tempFile);
      
      if (downloadUrl != null) {
        print('🆔 Current userId: ${widget.userId}');
        await _firebaseService.saveMeme(widget.userId, downloadUrl);
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Failed to get download URL');
      }
      
    } catch (e) {
      print('Error saving meme: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving meme: $e')),
      );
    }
  }

  Future<ui.Image> _loadImage(String path) async {
    final data = await File(path).readAsBytes();
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(data, completer.complete);
    return completer.future;
  }

  Widget _buildTextEditingPanel() {
    final selectedText = _memeTexts[_selectedTextIndex!];
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[200],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    labelText: 'Edit text',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      selectedText.text = value;
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    _memeTexts.removeAt(_selectedTextIndex!);
                    _selectedTextIndex = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('Font Size'),
                    Slider(
                      value: selectedText.fontSize,
                      min: 12,
                      max: 48,
                      onChanged: (value) {
                        setState(() {
                          selectedText.fontSize = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.color_lens),
                onPressed: () => _showColorPicker(
                  title: 'Text Color',
                  color: selectedText.color,
                  onColorChanged: (color) {
                    setState(() {
                      selectedText.color = color;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showColorPicker({
    required String title,
    required Color color,
    required ValueChanged<Color> onColorChanged,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: color,
            onColorChanged: onColorChanged,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _memeTexts = [];
      });
    }
  }

  void _addNewText() {
    setState(() {
      _memeTexts.add(MemeTextWidget(
        text: 'New Text',
        position: const Offset(100, 100),
        fontSize: _currentFontSize,
        color: _currentColor,
        strokeWidth: _currentStrokeWidth,
        strokeColor: _currentStrokeColor,
      ));
      _selectedTextIndex = _memeTexts.length - 1;
      _textController.text = 'New Text';
    });
  }

  Future<void> _selectTemplate() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TemplateSelectionPage(
          userId: widget.userId ?? '',
          onTemplateSelected: (File file) => Navigator.pop(context, file),
        ),
      ),
    );
  }
} 