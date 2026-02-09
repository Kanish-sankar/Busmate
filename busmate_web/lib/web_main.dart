import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _WebSmokeApp());
}

class _WebSmokeApp extends StatelessWidget {
  const _WebSmokeApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'Busmate Web Smoke Test',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}
