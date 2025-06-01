import 'package:flutter/material.dart';
import 'package:searchable_paginated_dropdown/searchable_paginated_dropdown.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // bottomNavigationBar: CurvedNavigationBar(
      //   backgroundColor: Colors.blueAccent,
      //   items: const <Icon>[
      //     Icon(Icons.add, size: 30),
      //     Icon(Icons.list, size: 30),
      //     Icon(Icons.compare_arrows, size: 30),
      //   ],
      //   onTap: (index) {
      //     //Handle button tap
      //   },
      // ),
      // body: Container(color: Colors.blueAccent),
      body: SafeArea(
        child: Column(
          children: [
            SearchableDropdown<int>(
              hintText: const Text('List of items'),
              margin: const EdgeInsets.all(15),
              items: List.generate(
                  10,
                  (i) => SearchableDropdownMenuItem(
                      value: i, label: 'item $i', child: Text('item $i'))),
              onChanged: (int? value) {
                debugPrint('$value');
              },
            ),
          ],
        ),
      ),
    );
  }
}
