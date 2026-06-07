import 'dart:io';

import 'package:flutter/material.dart';

Widget buildLocalEntryImage({
  required String source,
  BoxFit? fit,
  double? width,
  double? height,
  required Widget fallback,
}) {
  return Image.file(
    File(source),
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (context, error, stackTrace) => fallback,
  );
}
