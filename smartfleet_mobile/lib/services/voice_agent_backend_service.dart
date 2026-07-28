import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class DarijaChoice {
  final int id;
  final String labelFr;
  final String labelDarija;
  final String labelArabic;

  DarijaChoice({
    required this.id,
    required this.labelFr,
    required this.labelDarija,
    required this.labelArabic,
  });

  factory DarijaChoice.fromJson(Map<String, dynamic> json) {
    return DarijaChoice(
      id: json['id'] as int? ?? 0,
      labelFr: json['label_fr'] as String? ?? json['labelFr'] as String? ?? '',
      labelDarija: json['label_darija'] as String? ?? json['labelDarija'] as String? ?? '',
      labelArabic: json['label_arabic'] as String? ?? json['labelArabic'] as String? ?? '',
    );
  }
}

class VoiceAgentResponse {
  final String? sessionId;
  final int step;
  final String field;
  final String? questionDarija;
  final String? questionFrancais;
  final String? questionArabic;
  final bool done;
  final bool cancelled;
  final bool declarationCreated;
  final int? declarationId;
  final Map<String, String> formData;
  final List<DarijaChoice> choices;
  final String? error;

  VoiceAgentResponse({
    this.sessionId,
    this.step = 1,
    this.field = '',
    this.questionDarija,
    this.questionFrancais,
    this.questionArabic,
    this.done = false,
    this.cancelled = false,
    this.declarationCreated = false,
    this.declarationId,
    this.formData = const {},
    this.choices = const [],
    this.error,
  });

  factory VoiceAgentResponse.fromJson(Map<String, dynamic> json) {
    return VoiceAgentResponse(
      sessionId: json['sessionId'] as String?,
      step: json['step'] as int? ?? 1,
      field: json['field'] as String? ?? '',
      questionDarija: json['questionDarija'] as String? ?? json['response'] as String? ?? json['greeting'] as String?,
      questionFrancais: json['questionFrancais'] as String?,
      questionArabic: json['questionArabic'] as String?,
      done: json['done'] as bool? ?? false,
      cancelled: json['cancelled'] as bool? ?? false,
      declarationCreated: json['declarationCreated'] as bool? ?? false,
      declarationId: json['declarationId'] as int?,
      formData: (json['formData'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          (json['extract'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          {},
      choices: (json['choices'] as List? ?? [])
          .map((c) => DarijaChoice.fromJson(c as Map<String, dynamic>))
          .toList(),
      error: json['error'] as String?,
    );
  }
}

class VoiceAgentBackendService {
  final String baseUrl;

  VoiceAgentBackendService({this.baseUrl = ApiConfig.baseUrl});

  Future<VoiceAgentResponse> startSession({
    int? chauffeurId,
    String chauffeurNom = 'Chauffeur',
    String? immatriculation,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/voice-ai/start'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          if (chauffeurId != null) 'chauffeurId': chauffeurId,
          'chauffeurNom': chauffeurNom,
          if (immatriculation != null) 'immatriculation': immatriculation,
        }),
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        return VoiceAgentResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      return VoiceAgentResponse(error: 'HTTP ${response.statusCode}');
    } catch (e) {
      return VoiceAgentResponse(error: e.toString());
    }
  }

  Future<VoiceAgentResponse> sendResponse({
    required String sessionId,
    required String response,
  }) async {
    try {
      final httpResponse = await http.post(
        Uri.parse('$baseUrl/voice-ai/respond'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'sessionId': sessionId,
          'response': response,
        }),
      ).timeout(ApiConfig.timeout);

      if (httpResponse.statusCode == 200) {
        return VoiceAgentResponse.fromJson(jsonDecode(httpResponse.body) as Map<String, dynamic>);
      }
      return VoiceAgentResponse(error: 'HTTP ${httpResponse.statusCode}');
    } catch (e) {
      return VoiceAgentResponse(error: e.toString());
    }
  }
}
