import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class OllamaResponse {
  final String question;
  final List<OllamaChoice> choices;
  final String field;
  final bool done;
  final Map<String, String>? summary;
  final String? error;

  OllamaResponse({
    required this.question,
    this.choices = const [],
    required this.field,
    this.done = false,
    this.summary,
    this.error,
  });
}

class OllamaChoice {
  final int id;
  final String label;
  final String labelFr;

  OllamaChoice({required this.id, required this.label, required this.labelFr});
}

class OllamaService {
  final String baseUrl;

  OllamaService({this.baseUrl = ApiConfig.ollamaUrl});

  static const _systemPrompt = '''
أنت مساعد ذكي لشركة "سمارت فليت" لإدارة أساطيل الشاحنات.
تتحدث بالفصحى فقط.
مهمتك: مساعدة سائق الشاحنة في إنشاء تصريح عطل (déclaration de panne).

عليك جمع المعلومات التالية بالترتيب:
1. رقم تسجيل الشاحنة (immatriculation) مثل "AA-123-BC" أو رقم الشاحنة
2. نوع العطل (محرك، فرامل، إطارات، كهرباء، هيكل، ناقل حركة، تكييف، غير ذلك)
3. وصف المشكلة بالتفصيل
4. الموقع الحالي

قواعد مهمة:
- اسأل سؤالاً واحداً فقط في كل مرة
- قدم خيارات مناسبة للإجابة كأزرار
- إذا لم تفهم الإجابة، اطلب إعادة الصياغة
- بعد جمع كل المعلومات، قدم ملخصاً واطلب التأكيد
- ردودك تكون بصيغة JSON فقط

صيغة الرد:
{"question": "نص السؤال بالفصحى", "choices": [{"id": 1, "label": "خيار", "labelFr": "Option"}], "field": "immatriculation", "done": false, "summary": null}

عند التأكيد:
{"question": "تم إنشاء التصريح بنجاح", "choices": [], "field": "done", "done": true, "summary": {"immatriculation": "...", "typePanne": "...", "description": "...", "location": "..."}}
''';

  Future<OllamaResponse> sendMessage({
    required String message,
    required String currentField,
    required Map<String, String> collectedData,
  }) async {
    final fields = <String, String>{
      'immatriculation': 'رقم الشاحنة',
      'typePanne': 'نوع العطل',
      'description': 'وصف المشكلة',
      'location': 'الموقع',
    };

    final buffer = StringBuffer();
    buffer.writeln('المستخدم قال: "$message"');
    buffer.writeln('الحقل الحالي: $currentField');
    if (collectedData.isNotEmpty) {
      buffer.writeln('البيانات المجمعة:');
      for (final e in collectedData.entries) {
        final label = fields[e.key] ?? e.key;
        buffer.writeln('- $label: ${e.value}');
      }
    }
    buffer.writeln();
    if (currentField == 'immatriculation') {
      buffer.writeln(
          'اسأل عن رقم تسجيل الشاحنة. قدم أمثلة: AA-123-BC، 12345، إلخ.');
    } else if (currentField == 'typePanne') {
      buffer.writeln(
          'اسأل عن نوع العطل. اختر من: محرك، فرامل، إطارات، كهرباء، هيكل، ناقل حركة، تكييف، غير ذلك');
    } else if (currentField == 'description') {
      buffer.writeln('اطلب وصف المشكلة بالتفصيل');
    } else if (currentField == 'location') {
      buffer.writeln('اسأل عن الموقع الحالي للشاحنة');
    } else if (currentField == 'confirmation') {
      buffer.writeln('قدم ملخصاً واطلب التأكيد');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'llama3.2',
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {'role': 'user', 'content': buffer.toString()},
          ],
          'stream': false,
          'format': 'json',
        }),
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final content = body['message']?['content'] as String? ?? '';
        return _parseResponse(content);
      }
      return OllamaResponse(
        question: 'عذراً، حدث خطأ في الاتصال. حاول مرة أخرى.',
        field: currentField,
        error: 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      return OllamaResponse(
        question: 'عذراً، لا يمكن الاتصال بالخادم. تأكد من تشغيل Ollama.',
        field: currentField,
        error: e.toString(),
      );
    }
  }

  OllamaResponse _parseResponse(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final choices = (json['choices'] as List? ?? [])
          .map((c) => OllamaChoice(
                id: c['id'] as int? ?? 0,
                label: c['label'] as String? ?? '',
                labelFr: c['labelFr'] as String? ?? '',
              ))
          .toList();
      final summaryRaw = json['summary'] as Map<String, dynamic>?;
      final summary = summaryRaw?.map((k, v) => MapEntry(k, v.toString()));
      return OllamaResponse(
        question: json['question'] as String? ?? '',
        choices: choices,
        field: json['field'] as String? ?? 'immatriculation',
        done: json['done'] as bool? ?? false,
        summary: summary,
      );
    } catch (_) {
      return OllamaResponse(
        question: content,
        field: 'immatriculation',
      );
    }
  }
}
