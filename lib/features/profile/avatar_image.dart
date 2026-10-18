import 'dart:typed_data';

import 'package:flutter/material.dart';

class AvatarImage extends StatelessWidget {
  const AvatarImage({super.key, required this.radius, this.bytes});
  final double radius;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundImage: bytes == null
        ? const AssetImage('assets/images/default_avatar.png')
        : MemoryImage(bytes!),
  );
}
