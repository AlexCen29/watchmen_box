import 'package:flutter/material.dart';

class CustomFilledButtomn extends StatelessWidget {
  final String text;
  final Color? buttonColor;
  final Function()? onPressed;

  const CustomFilledButtomn(
      {this.onPressed, required this.text, this.buttonColor, super.key});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
          backgroundColor: buttonColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
      onPressed: onPressed,
      child: Text(text, ),
    );
  }
}
