import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  /// Lists available Gemini models for the current API key and prints them.
  Future<void> listAvailableModels() async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models?key=$_apiKey',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Available Gemini models:');
      for (var model in data['models'] ?? []) {
        print('- ' + (model['name'] ?? 'unknown'));
      }
    } else {
      print(
        'Failed to list models. Status: \\${response.statusCode} Body: \\${response.body}',
      );
    }
  }

  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  final String _model = 'models/gemini-2.5-flash';

  Future<List<Map<String, dynamic>>> generateDateSuggestions(
    List<String> interests, {
    List<Map<String, String>> exclusions = const [],
  }) async {
    final prompt = _buildPrompt(interests, exclusions: exclusions);
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/$_model:generateContent?key=$_apiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {'temperature': 0.8, 'maxOutputTokens': 300},
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text =
          data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      print('GeminiService: Raw AI response:\n$text');
      final suggestions = _parseSuggestions(text);
      print('GeminiService: Parsed suggestions count: \\${suggestions.length}');
      return suggestions;
    } else {
      print(
        'GeminiService: Error response: \nStatus: \\${response.statusCode}\nBody: \\${response.body}',
      );
      throw Exception('Failed to get suggestions from Gemini AI');
    }
  }

  String _buildPrompt(
    List<String> interests, {
    List<Map<String, String>> exclusions = const [],
  }) {
    String exclusionText = '';
    if (exclusions.isNotEmpty) {
      exclusionText = '\n\nDo NOT repeat any of these previous ideas:';
      for (final ex in exclusions) {
        exclusionText += '\n- \'${ex['title']}\': ${ex['desc']}';
      }
    }
    return '''
You are an expert date planner for couples.

Based on these interests: ${interests.join(", ")}
$exclusionText

Generate exactly 8 creative and couple-friendly date ideas.

For EACH idea, use this exact format:
1. Title: Description

Rules:
- Title must be short and describe a realistic, doable date activity
- Description must be 1–2 sentences
- Make the ideas fun, thoughtful, and suitable for couples
- Do not include any extra text before or after the list
''';
  }

  Future<List<Map<String, dynamic>>> generateDeepTalkTopics() async {
    final prompt = '''
You are an expert at creating deep, meaningful conversation starters for couples.

Generate exactly 10 unique, thought-provoking questions or topics that encourage deep discussion and emotional connection.

For EACH topic, use this exact format:
1. Topic text

Rules:
- Each topic should be a single, open-ended question or statement
- Avoid yes/no questions
- Do not include any extra text before or after the list
''';
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/$_model:generateContent?key=$_apiKey',
    );
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {'temperature': 0.8, 'maxOutputTokens': 300},
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text =
          data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      print('GeminiService: Raw AI response (deep talk):\n$text');
      final topics = _parseDeepTalkTopics(text);
      print('GeminiService: Parsed deep talk topics count: \\${topics.length}');
      return topics;
    } else {
      print(
        'GeminiService: Error response (deep talk): \nStatus: \\${response.statusCode}\nBody: \\${response.body}',
      );
      throw Exception('Failed to get deep talk topics from Gemini AI');
    }
  }

  List<Map<String, dynamic>> _parseDeepTalkTopics(String text) {
    final lines = text.split(RegExp(r'\n|\r\n'));
    final topics = <Map<String, dynamic>>[];
    int idx = 0;
    for (var line in lines) {
      final match = RegExp(r'\d+\.\s*(.+)').firstMatch(line);
      if (match != null) {
        final topic = match.group(1)?.trim();
        topics.add({'id': 'deeptalk_$idx', 'topic': topic ?? 'Untitled'});
        idx++;
      }
    }
    return topics;
  }

  /// Fetches a motivational or relationship quote from Gemini for the tip of the day.
  Future<String> fetchQuoteOfTheDay() async {
    final prompt = '''
You are an expert at providing short, inspiring, and thoughtful quotes for couples or personal growth.

Generate ONE unique, motivational or relationship-focused quote (1–2 sentences). Do not include any extra text, just the quote itself.
''';
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/$_model:generateContent?key=$_apiKey',
    );
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 60},
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text =
          data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      return text.trim();
    } else {
      print(
        'GeminiService: Error response (quote): \nStatus: \\${response.statusCode}\\nBody: \\${response.body}',
      );
      throw Exception('Failed to get quote from Gemini AI');
    }
  }

  List<Map<String, dynamic>> _parseSuggestions(String text) {
    final lines = text.split(RegExp(r'\n|\r\n'));
    final suggestions = <Map<String, dynamic>>[];
    int idx = 0;
    for (var line in lines) {
      final match = RegExp(r'\d+\.\s*(.+?):\s*(.+)').firstMatch(line);
      if (match != null) {
        final title = match.group(1)?.trim();
        final desc = match.group(2)?.trim();
        suggestions.add({
          'id': 'suggestion_$idx',
          'title': title ?? 'Untitled',
          'desc': desc ?? 'No description available',
        });
        idx++;
      }
    }
    return suggestions;
  }
}
