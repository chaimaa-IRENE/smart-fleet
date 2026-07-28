class ApiConfig {
  static const String host = '127.0.0.1';
  static const String baseUrl = 'http://$host:8082/api';
  static const String wsUrl = 'ws://$host:8082/ws/voice-ai';
  static const String ollamaUrl = 'http://$host:11434';
  static const String ttsUrl = 'http://$host:5000';
  static const String whisperUrl = 'http://$host:8082/api/stt/transcribe';

  static const Duration timeout = Duration(seconds: 30);
  static const Duration sttTimeout = Duration(seconds: 15);
  static const Duration ttsTimeout = Duration(seconds: 15);
  static const Duration wsReconnectDelay = Duration(seconds: 2);
  static const int wsMaxReconnectAttempts = 10;

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
