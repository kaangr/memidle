import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/database_helper.dart';
import 'dart:ui' as ui;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'saved_memes_page.dart';
import 'package:path_provider/path_provider.dart';
import 'template_selection_page.dart';
import 'dart:math';

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

class MemeTextWidget {
  String text;
  Offset position;
  double fontSize;
  Color color;
  double strokeWidth; // Eğer varsa
  Color strokeColor; // Eğer varsa

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

class HomePage extends StatefulWidget {
  final int? userId;
  final File? selectedImage;

  const HomePage({super.key, this.userId, this.selectedImage});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _selectedImage;
  final _textController = TextEditingController();
  final _dbHelper = DatabaseHelper();
  final ImagePicker _picker = ImagePicker();
  MemeTextWidget? _memeText;
  
  double _currentFontSize = 24;
  Color _currentColor = Colors.white;
  double _currentStrokeWidth = 0;
  Color _currentStrokeColor = Colors.black;
  double _currentBlurRadius = 3;
  Color _currentShadowColor = Colors.black;
  //Offset _currentShadowOffset = const Offset(1, 1);

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
        title: const Text('Meme Creator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveMeme,
          ),
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SavedMemesPage(userId: widget.userId ?? 0),
                ),
              );
            },
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
            Expanded(
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
              icon: const Icon(Icons.crop),
              onPressed: _cropImage,
            ),
            IconButton(
              icon: const Icon(Icons.rotate_right),
              onPressed: _rotateImage,
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

  void _selectText(int index) {
    setState(() {
      // Burada mevcut _memeText'i güncelleyebilirsiniz
    });
  }

  void _deleteSelectedText() {
    if (_memeText != null) {
      setState(() {
        _memeText = null;
        _textController.clear();
      });
    }
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
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 100,
    );
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _memeText = null;
      });
    }
  }

  Future<void> _saveMeme() async {
    if (_selectedImage == null || _memeText == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image and add text first')),
      );
      return;
    }

    try {
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
      
      // Kalıcı dizin oluştur ve dosyayı kaydet
      final appDir = await getApplicationDocumentsDirectory();
      final memesDir = Directory('${appDir.path}/memes');
      if (!await memesDir.exists()) {
        await memesDir.create(recursive: true);
      }
      
      final memeFile = File('${memesDir.path}/meme_${DateTime.now().millisecondsSinceEpoch}.png');
      await memeFile.writeAsBytes(buffer);

      // DatabaseMemeText oluştur
      final databaseMemeText = DatabaseMemeText(
        text: _memeText!.text,
        position: _memeText!.position,
        fontSize: _memeText!.fontSize,
        color: _memeText!.color,
        strokeWidth: _memeText!.strokeWidth,
        strokeColor: _memeText!.strokeColor,
      );

      // Veritabanına kaydet
      await _dbHelper.saveMeme(
        widget.userId ?? 0,
        memeFile.path,
        [databaseMemeText],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meme saved successfully')),
      );
    } catch (e) {
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

  Future<void> _cropImage() async {
    if (_selectedImage == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: _selectedImage!.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Theme.of(context).primaryColor,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop Image',
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _selectedImage = File(croppedFile.path);
      });
    }
  }

  Future<void> _rotateImage() async {
    if (_selectedImage == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: _selectedImage!.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Rotate Image',
          toolbarColor: Theme.of(context).primaryColor,
          toolbarWidgetColor: Colors.white,
        ),
        IOSUiSettings(
          title: 'Rotate Image',
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _selectedImage = File(croppedFile.path);
      });
    }
  }

  Future<void> _selectTemplate() {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TemplateSelectionPage(
          onTemplateSelected: (File selectedTemplate) {
            setState(() {
              _selectedImage = selectedTemplate;
              _memeText = null;
            });
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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
          ExpansionTile(
            title: const Text('Advanced Styles'),
            children: [
              ListTile(
                title: const Text('Stroke'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Slider(
                        value: _currentStrokeWidth,
                        min: 0,
                        max: 5,
                        onChanged: (value) {
                          setState(() {
                            _currentStrokeWidth = value;
                            _memeText!.strokeWidth = value;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.color_lens),
                      onPressed: () => _showColorPicker(
                        title: 'Stroke Color',
                        color: _currentStrokeColor,
                        onColorChanged: (color) {
                          setState(() {
                            _currentStrokeColor = color;
                            _memeText!.strokeColor = color;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                title: const Text('Shadow'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Slider(
                        value: _currentBlurRadius,
                        min: 0,
                        max: 10,
                        onChanged: (value) {
                          setState(() {
                            _currentBlurRadius = value;
                            _memeText!.blurRadius = value;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.color_lens),
                      onPressed: () => _showColorPicker(
                        title: 'Shadow Color',
                        color: _currentShadowColor,
                        onColorChanged: (color) {
                          setState(() {
                            _currentShadowColor = color;
                            _memeText!.shadowColor = color;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteSelectedText,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateText() {
    if (_memeText != null) {
      setState(() {
        _memeText!.text = _textController.text;
        _memeText!.fontSize = _currentFontSize;
        _memeText!.color = _currentColor;
        _memeText!.strokeWidth = _currentStrokeWidth;
        _memeText!.strokeColor = _currentStrokeColor;
      });
    }
  }
} 