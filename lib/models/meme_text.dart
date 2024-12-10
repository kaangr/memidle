import 'package:flutter/material.dart';

class MemeText {
    final String text;
    final Offset position;
    final double fontSize;
    final Color color;
    final double strokeWidth;
    final Color strokeColor;

    MemeText(this.text, this.position, this.fontSize, this.color, {this.strokeWidth = 0.0, this.strokeColor = Colors.black});
}