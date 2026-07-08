import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

class MyPetScreen extends StatefulWidget {
  const MyPetScreen({super.key});

  @override
  State<MyPetScreen> createState() => _MyPetScreenState();
}

class _MyPetScreenState extends State<MyPetScreen> {
  final Flutter3DController _controller = Flutter3DController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("My 3D Pet"), centerTitle: true),
      body: Center(
        child: Container(
          width: 320,
          height: 320,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Flutter3DViewer(
            controller: _controller,
            src:
                'https://firebasestorage.googleapis.com/v0/b/hackhive-2026.firebasestorage.app/o/animals%2Fmodel.glb?alt=media&token=9d287146-8703-4605-b4f0-f59d89d3cf5e',
          ),
        ),
      ),
    );
  }
}
