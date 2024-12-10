import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:memidle_test/models/meme_text.dart';
import '../services/database_helper.dart' hide MemeText;
import 'dart:ui' as ui;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'saved_memes_page.dart';
import 'package:path_provider/path_provider.dart';
import 'template_selection_page.dart';

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
  final List<MemeText> _memeTexts = [];
  int? _selectedTextIndex;
  
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
        title: const Text('Meme Gallery'),
      ),
      body: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: imagePaths.length,
        itemBuilder: (context, index) {
          return Card(
            child: Image.asset(imagePaths[index]), // Resmi göster
          );
        },
      ),
    );
  }

  void _addNewText() {
    setState(() {
      _memeTexts.add(MemeText(
        text: 'New Text',
        position: const Offset(100, 100),
      ));
      _selectedTextIndex = _memeTexts.length - 1;
      _textController.text = 'New Text';
    });
  }

  void _selectText(int index) {
    setState(() {
      _selectedTextIndex = index;
      _textController.text = _memeTexts[index].text;
      _currentFontSize = _memeTexts[index].fontSize;
      _currentColor = _memeTexts[index].color;
    });
  }

  void _deleteSelectedText() {
    if (_selectedTextIndex != null) {
      setState(() {
        _memeTexts.removeAt(_selectedTextIndex!);
        _selectedTextIndex = null;
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
        _memeTexts.clear();
        _selectedTextIndex = null;
      });
    }
  }

  Future<void> _saveMeme() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    try {
      // MemeText nesnelerini oluşturun
      List<model.MemeText> memeTexts = _memeTexts; // Mevcut meme metinlerini kullanın

      // saveMeme metodunu çağırın
      await _dbHelper.saveMeme(widget.userId ?? 0, _selectedImage!.path, memeTexts);
      
      // Başarılı bir şekilde kaydedildiğinde kullanıcıya bildirim gösterin
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
              _memeTexts.clear();
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
                _memeTexts[_selectedTextIndex!].text = value;
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
                          _memeTexts[_selectedTextIndex!].fontSize = value;
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
                      _memeTexts[_selectedTextIndex!].color = color;
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
                            _memeTexts[_selectedTextIndex!].strokeWidth = value;
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
                            _memeTexts[_selectedTextIndex!].strokeColor = color;
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
                            _memeTexts[_selectedTextIndex!].blurRadius = value;
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
                            _memeTexts[_selectedTextIndex!].shadowColor = color;
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
} 