
import 'package:flutter/material.dart';
import 'package:watchmen_box/config/themes/font/font_styles.dart';

class CustomTextFormField extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? errorMessage;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final IconData? icon;
  final double? width;
  final InputDecoration? decoration;
  final Color? color;
  final Color? fillColor;
  final TextStyle? textStyle;
  final TextEditingController? controller;
  const CustomTextFormField({
    super.key,
    this.label,
    this.hint,
    this.errorMessage,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.validator,
    this.icon, 
    this.width,
    this.decoration,
    this.color, 
    this.fillColor, 
    this.textStyle,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 4), // Sombra hacia abajo. x=0, y=4
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        validator: validator,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: textStyle ?? subtitleBlackF14,
        decoration: decoration ?? _buildInputDecoration(colors),
      )
    );
  }

  InputDecoration _buildInputDecoration(ColorScheme colors) {
    return InputDecoration(
      filled: true,
      fillColor: fillColor ?? colors.surface, // Mantiene coherencia con el tema
      prefixIcon:// Icono a la izquierda del campo
          icon != null ? Icon(icon, color: color) : null,
      labelText: label, // Texto del label
      labelStyle: TextStyle( // Estilo del texto del label
          color: color, fontWeight: FontWeight.bold),
      hintText: hint, // Texto de ayuda
      hintStyle: TextStyle(color: color),
      errorText: errorMessage,
      border: OutlineInputBorder(
        borderSide: BorderSide.none, // Sin bordes para mejor integración
        borderRadius: BorderRadius.circular(15),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: color ?? Colors.black, width: 2),
        borderRadius: BorderRadius.circular(15),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: color ?? Colors.black),
        borderRadius: BorderRadius.circular(15),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.circular(15),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.transparent, width: 2),
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }

}
