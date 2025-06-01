import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendStopClicked(String studentId) async {
  final url = Uri.parse('https://studentclickedstop-gnxzq4evda-uc.a.run.app');

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'studentId': studentId}),
  );

  if (response.statusCode == 200) {
    print("✅ STOP clicked sent successfully");
  } else {
    print("❌ Failed to send STOP clicked");
  }
}
