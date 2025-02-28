import 'dart:math';

import 'package:bruig/components/snackbars.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Copyable extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  const Copyable(this.text, this.textStyle, {Key? key}) : super(key: key);

  void copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    var textMsg = text.substring(0, min(text.length, 36));
    if (textMsg.length < text.length) {
      textMsg += "...";
    }
    showSuccessSnackbar(context, "Copied \"$textMsg\" to clipboard");
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: () => copy(context), child: Text(text, style: textStyle));
  }
}
