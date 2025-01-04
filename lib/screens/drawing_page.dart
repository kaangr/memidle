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
  MemeTextWidget? _memeText;
  
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
                  if (_memeText != null)
                    Positioned(
                      left: _memeText!.position.dx,
                      top: _memeText!.position.dy,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            _memeText!.position += details.delta;
                          });
                        },
                        child: Text(
                          _memeText!.text,
                          style: TextStyle(
                            fontSize: _memeText!.fontSize,
                            color: _memeText!.color,
                            shadows: [
                              Shadow(
                                color: _memeText!.strokeColor,
                                blurRadius: _currentBlurRadius,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Text('No image selected'),
              ),
            ),
          if (_memeText != null) _buildTextEditingPanel(),
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
    if (_selectedImage == null || _memeText == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image and add text first')),
      );
      return;
    }

    try {
      // Kullanıcı kontrolü
      if (widget.userId.isEmpty) {
        print('❌ User ID is empty');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first')),
        );
        return;
      }

      print('🔄 Starting meme save process for user: ${widget.userId}');

      // Resmi ve text'i bir araya getir
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Resmi yükle ve çiz
      final image = await _loadImage(_selectedImage!.path);
      canvas.drawImage(image, Offset.zero, Paint());
      
      // Text'i çiz
      final textPainter = TextPainter(
        text: TextSpan(
          text: _memeText!.text,
          style: TextStyle(
            fontSize: _memeText!.fontSize,
            color: _memeText!.color,
            shadows: [
              Shadow(
                color: _memeText!.strokeColor,
                blurRadius: _currentBlurRadius,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      // Ekran ve resim boyutları arasındaki oranı hesapla
      final screenSize = MediaQuery.of(context).size;
      final scale = image.width / screenSize.width;
      
      // Pozisyonu ölçekle
      final scaledPosition = Offset(
        _memeText!.position.dx * scale,
        _memeText!.position.dy * scale,
      );
      
      textPainter.paint(canvas, scaledPosition);
      
      // Resmi kaydet
      final picture = recorder.endRecording();
      final img = await picture.toImage(image.width, image.height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();
      
      // Geçici dosya oluştur
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_meme_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(buffer);

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
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[200],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Edit text',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _memeText!.text = value;
              });
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('Font Size'),
                    Slider(
                      value: _currentFontSize,
                      min: 12,
                      max: 48,
                      onChanged: (value) {
                        setState(() {
                          _currentFontSize = value;
                          _memeText!.fontSize = value;
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
                  color: _currentColor,
                  onColorChanged: (color) {
                    setState(() {
                      _currentColor = color;
                      _memeText!.color = color;
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
        _memeText = null;
      });
    }
  }

  void _addNewText() {
    setState(() {
      _memeText = MemeTextWidget(
        text: 'New Text',
        position: const Offset(100, 100),
        fontSize: _currentFontSize,
        color: _currentColor,
        strokeWidth: _currentStrokeWidth,
        strokeColor: _currentStrokeColor,
      );
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