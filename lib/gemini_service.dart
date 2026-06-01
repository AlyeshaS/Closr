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
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/$_model:generateContent?key=$_apiKey',
    );

    const targetCount = 8;
    final collected = <Map<String, dynamic>>[];
    final seenTitles = <String>{};

    for (
      var attempt = 0;
      attempt < 3 && collected.length < targetCount;
      attempt++
    ) {
      final remaining = targetCount - collected.length;
      final prompt = attempt == 0
          ? _buildPrompt(interests, exclusions: exclusions)
          : _buildContinuationPrompt(
              interests,
              collected,
              remaining,
              exclusions,
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
          // increase token budget for continuation attempts
          'generationConfig': {'temperature': 0.65, 'maxOutputTokens': 1024},
        }),
      );

      if (response.statusCode != 200) {
        print(
          'GeminiService: Error response (suggestions attempt $attempt): \nStatus: \\${response.statusCode}\nBody: \\${response.body}',
        );
        continue;
      }

      final data = jsonDecode(response.body);
      final text = _extractResponseText(data);
      print(
        'GeminiService: Raw AI response (suggestions, attempt $attempt):\n$text',
      );

      var parsed = _parseSuggestions(text);

      // If parsing yielded fewer than expected, log full data for diagnosis
      if (parsed.length < remaining) {
        print(
          'GeminiService: Partial parse (got \\${parsed.length} of \\${remaining}). Full response JSON:\n\\${jsonEncode(data)}',
        );
      }

      for (final s in parsed) {
        final title = (s['title'] ?? '').toString().trim();
        final low = title.toLowerCase();
        if (title.isEmpty) continue;
        if (seenTitles.contains(low)) continue;
        seenTitles.add(low);
        collected.add(s);
        if (collected.length == targetCount) break;
      }
    }

    // If still short, pad with simple fallback suggestions
    var padIdx = 0;
    while (collected.length < targetCount) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      collected.add({
        'id': 'suggestion_${ts}_pad_$padIdx',
        'title': 'Cozy Night In',
        'desc':
            'Cook a new recipe together, set the mood with music, and share highlights of your week.',
      });
      padIdx++;
    }

    print('GeminiService: Final suggestions count: \\${collected.length}');
    return collected;
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

  String _buildContinuationPrompt(
    List<String> interests,
    List<Map<String, dynamic>> alreadyReturned,
    int remaining,
    List<Map<String, String>> exclusions,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('You are an expert date planner for couples.');
    buffer.writeln();
    buffer.writeln('Based on these interests: ${interests.join(", ")}');
    if (exclusions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Do NOT repeat any of these previous ideas:');
      for (final ex in exclusions) {
        buffer.writeln('- "${ex['title']}": ${ex['desc']}');
      }
    }

    if (alreadyReturned.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Previously returned ideas:');
      for (var i = 0; i < alreadyReturned.length; i++) {
        final s = alreadyReturned[i];
        buffer.writeln('${i + 1}. ${s['title']}: ${s['desc']}');
      }
    }

    buffer.writeln();
    buffer.writeln(
      'Now, please generate exactly $remaining MORE creative and couple-friendly date ideas.',
    );
    buffer.writeln(
      'Continue the numbered list starting at ${alreadyReturned.length + 1}.',
    );
    buffer.writeln();
    buffer.writeln('For EACH idea, use this exact format:');
    buffer.writeln('1. Title: Description');
    buffer.writeln();
    buffer.writeln('Rules:');
    buffer.writeln(
      '- Title must be short and describe a realistic, doable date activity',
    );
    buffer.writeln('- Description must be 1–2 sentences');
    buffer.writeln('- Do not repeat any previously returned ideas');
    buffer.writeln(
      '- If the response is long, continue the list in a follow-up response',
    );
    buffer.writeln('- Do not include any extra text before or after the list');

    return buffer.toString();
  }

  Future<List<Map<String, dynamic>>> generateDeepTalkTopics() async {
    final topics = <Map<String, dynamic>>[];
    final seenTopics = <String>{};

    for (var attempt = 0; attempt < 3 && topics.length < 10; attempt++) {
      final prompt = _buildDeepTalkPrompt(
        remainingCount: 10 - topics.length,
        existingTopics: topics
            .map((topic) => (topic['topic'] ?? '').toString())
            .where((topic) => topic.isNotEmpty)
            .toList(),
      );
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
          'generationConfig': {'temperature': 0.65, 'maxOutputTokens': 768},
        }),
      );

      if (response.statusCode != 200) {
        print(
          'GeminiService: Error response (deep talk): \nStatus: \\${response.statusCode}\nBody: \\${response.body}',
        );
        continue;
      }

      final data = jsonDecode(response.body);
      final text = _extractResponseText(data);
      print(
        'GeminiService: Raw AI response (deep talk, attempt $attempt):\n$text',
      );
      final parsedTopics = _parseDeepTalkTopics(text);
      print(
        'GeminiService: Parsed deep talk topics count (attempt $attempt): \\${parsedTopics.length}',
      );

      for (final topic in parsedTopics) {
        final value = (topic['topic'] ?? '').toString().trim();
        final normalized = value.toLowerCase();
        if (value.isNotEmpty && seenTopics.add(normalized)) {
          topics.add({'id': 'deeptalk_${topics.length}', 'topic': value});
          if (topics.length == 10) break;
        }
      }
    }

    while (topics.length < 10) {
      topics.add(_fallbackDeepTalkTopic(topics.length));
    }

    return topics;
  }

  String _buildDeepTalkPrompt({
    required int remainingCount,
    required List<String> existingTopics,
  }) {
    final previousTopics = existingTopics.isEmpty
        ? ''
        : '\nAlready returned topics:\n${existingTopics.map((topic) => '- $topic').join('\n')}\n';

    return '''
You are an expert at creating conversation starters for couples.

Generate exactly $remainingCount NEW conversation topics that move from light to deeply personal.
$previousTopics
Return only a numbered list, one topic per line, using this format:
1. Complete question or prompt here?

Rules:
- Every line must be a complete sentence or question, not just a label
- Each topic should be open-ended and invite thoughtful discussion
- Keep each topic natural, emotionally thoughtful, and about 12–18 words long
- Avoid yes/no questions, duplicates, vague filler, and standalone words
- Make the list feel balanced: a few lighter starters, then deeper ones
- Every topic must end with a question mark
- Do not include any extra text before or after the list
''';
  }

  String _extractResponseText(dynamic data) {
    final buffer = StringBuffer();
    final candidates = data is Map<String, dynamic> ? data['candidates'] : null;
    if (candidates is List && candidates.isNotEmpty) {
      for (final cand in candidates) {
        if (cand is Map<String, dynamic>) {
          final content = cand['content'];
          final parts = content is Map<String, dynamic>
              ? content['parts']
              : null;
          if (parts is List) {
            for (final part in parts) {
              if (part is Map<String, dynamic> && part['text'] is String) {
                if (buffer.isNotEmpty) buffer.writeln();
                buffer.write((part['text'] as String).trim());
              }
            }
          }
        }
      }
    }
    return buffer.toString().trim();
  }

  List<Map<String, dynamic>> _parseDeepTalkTopics(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final topics = <Map<String, dynamic>>[];
    int idx = 0;
    for (var line in lines) {
      final match = RegExp(
        r'^(?:\d+[\.)]|[-*])\s*(.+)$',
      ).firstMatch(line.trim());
      if (match != null) {
        final topic = match.group(1)?.trim();
        if (_isCompleteDeepTalkTopic(topic)) {
          topics.add({'id': 'deeptalk_$idx', 'topic': topic});
          idx++;
        }
      }
    }
    return topics;
  }

  bool _isCompleteDeepTalkTopic(String? topic) {
    if (topic == null) return false;
    final trimmed = topic.trim();
    if (trimmed.length < 20 || !trimmed.endsWith('?')) return false;
    final wordCount = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    return wordCount >= 6;
  }

  Map<String, dynamic> _fallbackDeepTalkTopic(int index) {
    const fallbackTopics = [
      'What is a small habit that makes us feel closer to each other?',
      'When do you feel most appreciated in a relationship?',
      'What kind of memory do you want us to create together next?',
      'What helps you feel safe enough to be fully honest with someone?',
      'How do you like to be supported when life feels overwhelming?',
      'What is something you are still learning about yourself right now?',
      'What does a really meaningful date night look like to you?',
      'How do you know when a connection is becoming truly deep?',
      'What is one dream you would love to build a life around?',
      'What is a simple way we can keep growing together over time?',
    ];

    final topic = fallbackTopics[index % fallbackTopics.length];
    return {'id': 'deeptalk_$index', 'topic': topic};
  }

  /// Fetches a motivational or relationship quote from Gemini for the tip of the day.
  Future<String> fetchQuoteOfTheDay() async {
    final prompt = '''
You are an expert at providing short, inspiring, and thoughtful quotes for couples or personal growth.

Generate ONE unique, motivational or relationship-focused quote.
Keep it to 2 short sentences, around 45-70 words total, and do not include any extra text.
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
        'generationConfig': {'temperature': 0.7},
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return _extractResponseText(data);
    } else {
      print(
        'GeminiService: Error response (quote): \nStatus: \\${response.statusCode}\\nBody: \\${response.body}',
      );
      throw Exception('Failed to get quote from Gemini AI');
    }
  }

  List<Map<String, dynamic>> _parseSuggestions(String text) {
    final suggestions = <Map<String, dynamic>>[];
    // Match numbered entries like "1. Title: Description..." where description
    // may span multiple lines until the next numbered item.
    final entryRe = RegExp(
      r'''\d+\.\s*(.+?):\s*([\s\S]*?)(?=(?:\n\d+\.|\n\Z))''',
      dotAll: true,
      multiLine: true,
    );
    final matches = entryRe.allMatches(text);
    var idx = 0;
    final ts = DateTime.now().millisecondsSinceEpoch;
    for (final m in matches) {
      final title = m.group(1)?.trim();
      var desc = m.group(2)?.trim() ?? '';
      // Normalize line breaks inside the description to single spaces
      desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();
      suggestions.add({
        'id': 'suggestion_${ts}_$idx',
        'title': title ?? 'Untitled',
        'desc': desc.isNotEmpty ? desc : 'No description available',
      });
      idx++;
    }
    return suggestions;
  }
}
