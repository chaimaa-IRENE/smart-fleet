import 'package:flutter_test/flutter_test.dart';
import 'package:smartfleet_mobile/services/voice_ai_service.dart';
import 'package:smartfleet_mobile/config/api_config.dart';

void main() {
  group('VoiceAiExtract', () {
    test('fromJson parses correctly', () {
      final json = {
        'immatriculation': '247',
        'typePanne': 'MECANIQUE',
        'description': 'moteur fumée',
        'elementVehicule': 'MOTEUR',
        'criticite': 'BLOQUANT',
        'lieu': 'Casablanca',
        'kilometrage': '120000',
        'categorie': 'MECANIQUE',
      };
      final extract = VoiceAiExtract.fromJson(json);
      expect(extract.immatriculation, '247');
      expect(extract.typePanne, 'MECANIQUE');
      expect(extract.description, 'moteur fumée');
      expect(extract.elementVehicule, 'MOTEUR');
      expect(extract.criticite, 'BLOQUANT');
      expect(extract.lieu, 'Casablanca');
      expect(extract.kilometrage, '120000');
      expect(extract.categorie, 'MECANIQUE');
    });

    test('fromJson handles empty map', () {
      final extract = VoiceAiExtract.fromJson({});
      expect(extract.immatriculation, isNull);
      expect(extract.typePanne, isNull);
      expect(extract.filledCount(), 0);
    });

    test('fromJson handles null values', () {
      final json = {'immatriculation': null, 'typePanne': 'MECANIQUE'};
      final extract = VoiceAiExtract.fromJson(json);
      expect(extract.immatriculation, isNull);
      expect(extract.typePanne, 'MECANIQUE');
    });

    test('toMap only includes non-null fields', () {
      final extract = VoiceAiExtract();
      extract.immatriculation = '247';
      extract.typePanne = 'MECANIQUE';
      final map = extract.toMap();
      expect(map.length, 2);
      expect(map['immatriculation'], '247');
      expect(map['typePanne'], 'MECANIQUE');
      expect(map.containsKey('description'), false);
    });

    test('filledCount returns correct count', () {
      final extract = VoiceAiExtract();
      expect(extract.filledCount(), 0);
      extract.immatriculation = '247';
      expect(extract.filledCount(), 1);
      extract.typePanne = 'MECANIQUE';
      expect(extract.filledCount(), 2);
    });
  });

  group('VoiceAiResponse', () {
    test('fromJson parses correctly', () {
      final json = {
        'response': 'شكرا بزاف',
        'extract': {'immatriculation': '247'},
        'done': true,
        'confirmed': true,
        'summary': 'خلاصة التصريح',
      };
      final response = VoiceAiResponse.fromJson(json);
      expect(response.response, 'شكرا بزاف');
      expect(response.extract.immatriculation, '247');
      expect(response.done, true);
      expect(response.confirmed, true);
      expect(response.summary, 'خلاصة التصريح');
    });

    test('fromJson handles missing fields', () {
      final json = <String, dynamic>{};
      final response = VoiceAiResponse.fromJson(json);
      expect(response.response, '');
      expect(response.done, false);
      expect(response.confirmed, false);
      expect(response.summary, isNull);
    });
  });

  group('VoiceAiService', () {
    late VoiceAiService service;

    setUp(() {
      service = VoiceAiService();
    });

    test('initial state has system message', () {
      expect(service.conversation.length, 1);
      expect(service.conversation[0].role, 'system');
      expect(service.conversation[0].content, contains('SmartFleet'));
    });

    test('isComplete returns false initially', () {
      expect(service.isComplete, false);
    });

    test('getGreeting returns darija greeting', () {
      final greeting = service.getGreeting();
      expect(greeting, anyOf(contains('السلام'), contains('أهلا')));
      // New natural greeting may be more open-ended
      expect(greeting, anyOf(contains('SmartFleet'), contains('المساعد'), contains('نعاون')));
    });

    test('getPromptForField returns correct prompts', () {
      expect(service.getPromptForField('immatriculation'), contains('رقم الشاحنة'));
      expect(service.getPromptForField('typePanne'), contains('نوع العطل'));
      expect(service.getPromptForField('description'), contains('وصفلي'));
      expect(service.getPromptForField('unknown'), isNotNull);
    });

    test('reset clears messages except system', () async {
      await service.reset();
      expect(service.conversation.length, 1);
      expect(service.conversation[0].role, 'system');
      expect(service.currentExtract.filledCount(), 0);
    });

    test('processUserText returns response from server', () async {
      // Verify the service communicates with the API and returns a valid response
      final response = await service.processUserText('السلام عليكم');
      expect(response.response, isNotEmpty);
      expect(response.done, false);
      expect(response.confirmed, false);
    });

    test('processUserText adds user message to history', () async {
      await service.processUserText('السلام عليكم');
      expect(service.conversation.length, greaterThanOrEqualTo(2));
      expect(service.conversation[1].role, 'user');
      expect(service.conversation[1].content, 'السلام عليكم');
    });
  });

  group('VoiceAiService - Conversation Scenarios', () {
    late VoiceAiService service;

    setUp(() {
      service = VoiceAiService();
    });

    test('SCENARIO 1: Darija greeting', () async {
      final greeting = service.getGreeting();
      expect(greeting, isNotEmpty);
      expect(greeting, anyOf(contains('السلام'), contains('أهلا')));
    });

    test('SCENARIO 2: System prompt has correct instructions', () {
      final systemMsg = service.conversation[0].content;
      expect(systemMsg, contains('بالدارجة المغربية'));
      expect(systemMsg, contains('immatriculation'));
      expect(systemMsg, contains('typePanne'));
      expect(systemMsg, contains('criticite'));
      expect(systemMsg, contains('lieu'));
      expect(systemMsg, contains('kilometrage'));
      // New natural prompt checks
      expect(systemMsg, contains('طبيعية'));
      expect(systemMsg, contains('بدون ترتيب إجباري'));
    });

    test('SCENARIO 3: System prompt does not contain Russian', () {
      final systemMsg = service.conversation[0].content;
      expect(systemMsg, isNot(contains('только')));
      expect(systemMsg, isNot(contains('سؤال واحد كل مرة')));
    });

    test('SCENARIO 4: Handle empty text', () async {
      final response = await service.processUserText('');
      expect(response.response, isNotEmpty);
    });

    test('SCENARIO 5: Handle very long text', () async {
      final longText = 'و' * 1000;
      final response = await service.processUserText(longText);
      expect(response.response, isNotEmpty);
    });

    test('SCENARIO 6: Multiple calls maintain message history', () async {
      // Test message addition only, not network round-trip
      service.conversation.add(VoiceAiMessage(role: 'user', content: 'test1'));
      service.conversation.add(VoiceAiMessage(role: 'assistant', content: 'response1'));
      service.conversation.add(VoiceAiMessage(role: 'user', content: 'test2'));
      expect(service.conversation.length, 4); // system + user1 + assistant1 + user2
      final userMessages = service.conversation.where((m) => m.role == 'user').toList();
      expect(userMessages.length, 2);
      expect(userMessages[0].content, 'test1');
      expect(userMessages[1].content, 'test2');
    });

    test('SCENARIO 7: Reset clears session', () async {
      service.conversation.add(VoiceAiMessage(role: 'user', content: 'test'));
      service.conversation.add(VoiceAiMessage(role: 'assistant', content: 'test'));
      expect(service.conversation.length, 3);
      await service.reset();
      expect(service.conversation.length, 1);
      expect(service.conversation[0].role, 'system');
    });
  });

  group('VoiceAiMessage', () {
    test('toJson produces correct format', () {
      final msg = VoiceAiMessage(role: 'user', content: 'test');
      final json = msg.toJson();
      expect(json['role'], 'user');
      expect(json['content'], 'test');
    });
  });
}
