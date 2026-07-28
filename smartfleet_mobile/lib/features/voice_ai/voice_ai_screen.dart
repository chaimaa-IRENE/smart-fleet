import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../config/theme.dart';
import '../../../config/api_config.dart';
import '../../../services/voice_ai_service.dart';
import '../../../services/voice_ai_queue_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/premium/aurora_background.dart';
import '../../../widgets/danone_app_bar.dart';
import 'widgets/ai_avatar_widget.dart';
import 'widgets/animated_mic_button.dart';
import 'widgets/sound_wave_animation.dart';
import 'widgets/conversation_bubble.dart';

class VoiceAiScreen extends StatefulWidget {
  const VoiceAiScreen({super.key});

  @override
  State<VoiceAiScreen> createState() => _VoiceAiScreenState();
}

class _VoiceAiScreenState extends State<VoiceAiScreen>
    with WidgetsBindingObserver {
  final VoiceAiService _aiService = VoiceAiService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollCtrl = ScrollController();
  final Connectivity _connectivity = Connectivity();

  WebSocketChannel? _wsChannel;
  bool _wsConnected = false;
  int _wsReconnectAttempts = 0;
  Timer? _wsReconnectTimer;
  StreamSubscription? _connectivitySub;
  bool _isOnline = true;

  bool _initialized = false;
  bool _sessionStarted = false;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  bool _sttAvailable = false;
  bool _autoListening = false;
  bool _whisperAvailable = false;

  String _statusText = '';
  String _recognizedText = '';
  String _streamingText = '';
  final List<_ChatMessage> _messages = [];
  VoiceAiExtract? _lastExtract;
  String? _gpsLocation;

  bool _ttsInterrupted = false;
  String? _sessionId;

  // Noise gate: ignore audio below threshold (cabin noise filter)
  static const double _noiseThreshold = 0.08;
  static const double _speechThreshold = 0.15;
  static const int _vadWindowSize = 5;
  final List<double> _vadWindow = [];
  bool _speechDetected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initStt();
    _initAudioListener();
    _initConnectivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disconnectWs();
    _wsReconnectTimer?.cancel();
    _connectivitySub?.cancel();
    _speech.stop();
    _audioPlayer.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _speech.stop();
      if (mounted) setState(() {
        _isListening = false;
        _autoListening = false;
      });
    }
  }

  // ── Connectivity ─────────────────────────────────────────────────

  void _initConnectivity() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) {
      final online = result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet;
      if (online != _isOnline) {
        _isOnline = online;
        if (online && _sessionStarted) {
          _reconnectWs();
          VoiceAiQueueService.processQueue();
        }
        if (mounted) setState(() {});
      }
    });
  }

  Future<bool> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet;
    return _isOnline;
  }

  // ── WebSocket ────────────────────────────────────────────────────

  void _connectWs() {
    _disconnectWs();
    _wsReconnectAttempts = 0;
    _doConnectWs();
  }

  void _doConnectWs() {
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(ApiConfig.wsUrl));
      _wsConnected = true;
      _wsReconnectAttempts = 0;

      _wsChannel!.stream.listen(
        (data) => _handleWsMessage(data as String),
        onError: (_) => _onWsDisconnected(),
        onDone: () => _onWsDisconnected(),
      );
    } catch (_) {
      _onWsDisconnected();
    }
  }

  void _disconnectWs() {
    _wsChannel?.sink.close();
    _wsChannel = null;
    _wsConnected = false;
  }

  void _reconnectWs() {
    _wsReconnectTimer?.cancel();
    if (_wsReconnectAttempts < ApiConfig.wsMaxReconnectAttempts) {
      _wsReconnectAttempts++;
      _wsReconnectTimer = Timer(ApiConfig.wsReconnectDelay, _doConnectWs);
    }
  }

  void _onWsDisconnected() {
    _wsConnected = false;
    if (_sessionStarted && _isOnline) {
      _reconnectWs();
    }
  }

  void _handleWsMessage(String data) {
    try {
      final msg = jsonDecode(data) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      switch (type) {
        case 'greeting':
          _sessionId = msg['sessionId'] as String?;
          final text = msg['text'] as String? ?? '';
          _addMessage('assistant', text);
          _speakAndListen(text);
          break;

        case 'token':
          setState(() => _streamingText = msg['text'] as String? ?? '');
          break;

        case 'response':
          final text = msg['text'] as String? ?? '';
          final done = msg['done'] as bool? ?? false;
          final confirmed = msg['confirmed'] as bool? ?? false;

          if (text.isNotEmpty) {
            _addMessage('assistant', text);
          }

          final extractJson = msg['extract'] as Map<String, dynamic>?;
          if (extractJson != null) {
            _lastExtract = VoiceAiExtract.fromJson(extractJson);
          }

          if (confirmed) {
            if (_lastExtract != null) {
              final body = _buildDeclarationBody(_lastExtract!);
              _saveViaWs(body);
            }
          } else if (done) {
            _addMessage('assistant', msg['summary'] as String? ?? text);
            _speakAndListen(msg['summary'] as String? ?? text);
          } else {
            _speakAndListen(text);
          }
          setState(() => _streamingText = '');
          break;

        case 'pong':
          break;

        case 'error':
          _addMessage('assistant', msg['text'] as String? ?? 'عذرا، حدث خطأ.');
          break;
      }
    } catch (_) {}
  }

  void _sendWsMessage(Map<String, dynamic> msg) {
    if (_wsConnected && _wsChannel != null) {
      _wsChannel!.sink.add(jsonEncode(msg));
    }
  }

  // ── VAD (Voice Activity Detection) ───────────────────────────────

  bool _detectSpeech(double amplitude) {
    _vadWindow.add(amplitude);
    if (_vadWindow.length > _vadWindowSize) {
      _vadWindow.removeAt(0);
    }

    if (_vadWindow.length < 3) return false;

    double avg = _vadWindow.reduce((a, b) => a + b) / _vadWindow.length;
    double variance = _vadWindow
        .map((v) => (v - avg) * (v - avg))
        .reduce((a, b) => a + b) / _vadWindow.length;

    // Speech detection: high energy + variance (not constant noise)
    return avg > _speechThreshold || (avg > _noiseThreshold && variance > 0.001);
  }

  // ── Whisper STT ──────────────────────────────────────────────────

  Future<String> _transcribeWithWhisper(String localText) async {
    if (!_whisperAvailable) return localText;

    try {
      // For now, send the recognized text to backend for correction
      // In production, this would send raw audio to Whisper API
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/voice-ai/correct'),
        headers: ApiConfig.headers,
        body: jsonEncode({'text': localText, 'language': 'ar'}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['corrected'] as String? ?? localText;
      }
    } catch (_) {}
    return localText;
  }

  FutureBuilder<int> _pendingCountBadge() {
    return FutureBuilder<int>(
      future: VoiceAiQueueService.getPendingCount(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data == 0) return const SizedBox();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${snap.data} déclaration(s) en attente',
            style: const TextStyle(fontSize: 12, color: Colors.orange),
          ),
        );
      },
    );
  }

  void _initAudioListener() {
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted && _isSpeaking && !_ttsInterrupted) {
        setState(() => _isSpeaking = false);
        _startListening();
      }
    });
  }

  Future<void> _initStt() async {
    _sttAvailable = await _speech.initialize(
      onError: (e) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _autoListening = false;
            _statusText = 'Erreur de reconnaissance vocale';
          });
        }
      },
      onStatus: (s) {
        if (mounted) {
          if (s == 'notListening' && _autoListening && !_isSpeaking) {
            setState(() => _isListening = false);
          }
          if (s == 'listening') {
            setState(() => _isListening = true);
          }
        }
      },
    );
    if (mounted) {
      setState(() {
        _initialized = true;
        _whisperAvailable = _sttAvailable;
      });
    }
  }

  Future<String?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return null;
      }
      if (perm == LocationPermission.deniedForever) return null;
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 5));
      return '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
    } catch (_) {
      return null;
    }
  }

  // ── Session ──────────────────────────────────────────────────────

  Future<void> _startSession() async {
    await _aiService.reset();
    _gpsLocation = await _getCurrentLocation();
    await _checkConnectivity();

    setState(() {
      _sessionStarted = true;
      _isProcessing = true;
      _statusText = 'Je réfléchis...';
      _messages.clear();
      _lastExtract = null;
    });

    // Try WebSocket first, fall back to HTTP
    if (_isOnline) {
      _connectWs();
      _sendWsMessage({
        'type': 'start',
        'chauffeurId': context.read<AuthProvider>().userId,
        'chauffeurNom': context.read<AuthProvider>().user?['nom'] ?? 'Chauffeur',
      });
      // Fallback timer: if WS doesn't respond, use HTTP
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _messages.isEmpty) {
          _startHttpSession();
        }
      });
    } else {
      _startOfflineSession();
    }
  }

  void _startHttpSession() {
    final greeting = _aiService.getGreeting();
    _addMessage('assistant', greeting);
    _speakAndListen(greeting);
  }

  void _startOfflineSession() {
    setState(() => _statusText = 'Mode hors ligne');
    _addMessage('assistant', 'السلام عليكم. أنا هنا ولكن ماعنديش اتصال بالنت. غادي نخدم بشكل محدود.');
    _startListening();
  }

  void _addMessage(String role, String text) {
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(
        role: role,
        text: text,
        time: DateTime.now(),
      ));
    });
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Speak + Barge-in ─────────────────────────────────────────────

  Future<void> _speakAndListen(String text) async {
    if (text.isEmpty) return;
    _ttsInterrupted = false;

    setState(() {
      _isSpeaking = true;
      _isProcessing = false;
      _statusText = 'Je parle...';
    });

    try {
      final uri = Uri.parse('${ApiConfig.ttsUrl}/api/tts/speak').replace(
        queryParameters: {
          'text': text,
          'voice': 'ar-MA-JamalNeural',
          'rate': '-5%',
        },
      );
      final response = await http.get(uri).timeout(ApiConfig.ttsTimeout);

      if (response.statusCode == 200 && mounted && !_ttsInterrupted) {
        final dir = await getTemporaryDirectory();
        final file = File(
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await file.writeAsBytes(response.bodyBytes);

        unawaited(_audioPlayer.play(DeviceFileSource(file.path)));

        // IMMEDIATELY start listening with VAD for barge-in
        _startListeningForBargeIn();
      } else {
        if (mounted && !_ttsInterrupted) {
          setState(() => _isSpeaking = false);
          _startListening();
        }
      }
    } catch (_) {
      if (mounted && !_ttsInterrupted) {
        setState(() {
          _isSpeaking = false;
          _statusText = 'Erreur TTS';
        });
        _startListening();
      }
    }
  }

  void _startListeningForBargeIn() {
    if (!_sttAvailable) return;
    _autoListening = true;

    _speech.listen(
      onResult: (result) {
        if (result.recognizedWords.isNotEmpty) {
          setState(() => _recognizedText = result.recognizedWords);

          // VAD + Barge-in: detect speech while AI speaks
          if (_isSpeaking &&
              result.recognizedWords.length > 3 &&
              !_ttsInterrupted) {
            _interruptTts();
            _addMessage('user', result.recognizedWords);
            _handleUserText(result.recognizedWords);
            return;
          }
        }

        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _autoListening = false;
          _speech.stop();
          if (mounted) {
            setState(() => _isListening = false);
            _handleUserText(result.recognizedWords);
          }
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 2),
        localeId: 'ar',
        cancelOnError: true,
        partialResults: true,
      ),
    );
    if (mounted) setState(() => _isListening = true);
  }

  void _interruptTts() {
    _ttsInterrupted = true;
    _audioPlayer.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _startListening() async {
    if (!_sttAvailable) {
      await _initStt();
      if (!_sttAvailable && mounted) {
        setState(() => _statusText = 'Micro non disponible');
        _addMessage('assistant', 'عذرا، الميكرو غير متوفر.');
        return;
      }
    }

    _autoListening = true;
    setState(() {
      _isListening = true;
      _isProcessing = false;
      _isSpeaking = false;
      _statusText = 'Je vous écoute...';
      _recognizedText = '';
    });

    await _speech.listen(
      onResult: (result) {
        if (result.recognizedWords.isNotEmpty) {
          setState(() => _recognizedText = result.recognizedWords);
        }
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _autoListening = false;
          _speech.stop();
          if (mounted) {
            setState(() => _isListening = false);
            _handleUserText(result.recognizedWords);
          }
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 2),
        localeId: 'ar',
        cancelOnError: true,
        partialResults: true,
      ),
    );
    if (_autoListening && mounted) {
      _speech.stop();
      setState(() {
        _isListening = false;
        _autoListening = false;
      });
    }
  }

  // ── Process ──────────────────────────────────────────────────────

  Future<void> _handleUserText(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusText = 'Je réfléchis...';
      _recognizedText = '';
    });

    // Send to Websocket if connected
    if (_wsConnected && _sessionId != null) {
      _sendWsMessage({
        'type': 'message',
        'sessionId': _sessionId,
        'text': text,
      });
      return;
    }

    // Fallback: HTTP
    final response = await _aiService.processUserText(text);
    if (!mounted) return;

    _lastExtract = response.extract;
    if (_gpsLocation != null && response.extract.lieu == null) {
      _lastExtract!.lieu = _gpsLocation;
    }

    if (response.done || response.confirmed) {
      _addMessage('assistant', response.response);
      if (response.confirmed) {
        await _saveDeclaration(response.extract);
      } else {
        _speakAndListen(response.response);
      }
    } else {
      _addMessage('assistant', response.response);
      _speakAndListen(response.response);
    }
  }

  // ── Save ─────────────────────────────────────────────────────────

  Map<String, dynamic> _buildDeclarationBody(VoiceAiExtract extract) {
    final user = context.read<AuthProvider>().user;
    return {
      'typePanne': extract.typePanne ?? 'AUTRE',
      'description': extract.description ?? '',
      'immatriculation': extract.immatriculation ?? '',
      'chauffeurNom': user?['nom'] as String? ?? 'Chauffeur',
      'lieu': extract.lieu ?? '',
      'kilometrage': extract.kilometrage ?? '',
      'criticite': extract.criticite ?? '',
      'elementVehicule': extract.elementVehicule ?? '',
      'dateCreation': DateTime.now().toIso8601String(),
      'statut': 'EN_ATTENTE',
      'priorite': extract.priorite ?? 'NORMALE',
      'categorie': extract.categorie ?? '',
      'source': 'VOICE_AI',
      'gpsLocation': _gpsLocation ?? '',
    };
  }

  void _saveViaWs(Map<String, dynamic> body) {
    if (_wsConnected && _sessionId != null) {
      _sendWsMessage({
        'type': 'save',
        'sessionId': _sessionId,
        'declaration': body,
      });
      if (mounted) {
        setState(() => _statusText = 'Déclaration enregistrée ✓');
        _addMessage('assistant', 'تم التصريح بنجاح! شكرا بزاف. بسلامة.');
      }
    } else {
      _saveViaHttp(body);
    }
  }

  Future<void> _saveDeclaration(VoiceAiExtract extract) async {
    if (extract.immatriculation == null || extract.immatriculation!.isEmpty) {
      _addMessage('assistant', 'عذرا، ما كاينش رقم الشاحنة.');
      if (mounted) setState(() => _statusText = 'رقم الشاحنة ناقص');
      return;
    }

    final body = _buildDeclarationBody(extract);

    if (!_isOnline) {
      await VoiceAiQueueService.enqueue(body);
      if (mounted) {
        setState(() => _statusText = 'Déclaration mise en file d\'attente');
        _addMessage('assistant', 'ماعنديش اتصال بالنت. غادي نحفظ التصريح ونرسله منين ترجع الخدمة.');
      }
      return;
    }

    _saveViaHttp(body);
  }

  Future<void> _saveViaHttp(Map<String, dynamic> body) async {
    setState(() => _statusText = 'Enregistrement...');

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/declarations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() => _statusText = 'Déclaration enregistrée ✓');
        _addMessage('assistant', 'تم التصريح بنجاح! شكرا بزاف. بسلامة.');
      } else {
        setState(() => _statusText = "Erreur d'enregistrement");
        _addMessage('assistant', 'عذرا، حدث خطأ في الحفظ. الرجاء المحاولة مرة أخرى.');
      }
    } catch (_) {
      if (mounted) {
        // Queue for retry
        await VoiceAiQueueService.enqueue(body);
        setState(() => _statusText = 'Mise en file d\'attente');
        _addMessage('assistant', 'تم حفظ التصريح فالصاك. غادي نرسله منين ترجع الخدمة.');
      }
    }
  }

  void _toggleListening() {
    if (_isListening) {
      _autoListening = false;
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      if (_isSpeaking) _interruptTts();
      if (!_isProcessing) _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DanoneAppBar(
        title: 'Assistant Vocal IA',
        actions: [
          if (_sessionStarted)
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: _startSession,
            ),
        ],
      ),
      body: AuroraBackground(
        child: Column(
          children: [
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_sessionStarted) return _buildWelcome();
    return Column(
      children: [
        _buildStatusHeader(),
        Expanded(child: _buildChatArea()),
        _buildRecognizedText(),
        _buildControlBar(),
      ],
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AiAvatarWidget(),
            const SizedBox(height: 24),
            Text(
              'Assistant Vocal IA',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Déclarez un incident en parlant naturellement.\nL\'IA vous guide en darija marocain.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            if (!_isOnline)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Mode hors ligne — Les déclarations seront mises en file d\'attente',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            _pendingCountBadge(),
            const SizedBox(height: 32),
            _buildPremiumButton('Commencez la déclaration', Icons.mic, () {
              if (!_initialized) return;
              _startSession();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumButton(String label, IconData icon, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label,
            style: const TextStyle(fontSize: 16, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AiAvatarWidget(
                isListening: _isListening,
                isThinking: _isProcessing,
                isSpeaking: _isSpeaking,
              ),
              if (!_isOnline)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _statusText,
            style: TextStyle(
              fontSize: 13,
              color: _isListening
                  ? AppTheme.accent
                  : _isProcessing
                      ? AppTheme.warning
                      : _isSpeaking
                          ? AppTheme.success
                          : AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_isListening) ...[
            const SizedBox(height: 8),
            SoundWaveAnimation(
              active: _isListening,
              color: AppTheme.accent,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'Appuyez sur le micro et parlez naturellement',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        return ConversationBubble(
          text: msg.text,
          isUser: msg.role == 'user',
          time: '${msg.time.hour}:${msg.time.minute.toString().padLeft(2, '0')}',
        );
      },
    );
  }

  Widget _buildRecognizedText() {
    if (_recognizedText.isEmpty && _streamingText.isEmpty) return const SizedBox();
    final displayText = _streamingText.isNotEmpty ? _streamingText : _recognizedText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 13,
          color: _streamingText.isNotEmpty ? AppTheme.success : AppTheme.primary,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
        border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_lastExtract != null && _lastExtract!.filledCount() > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildExtractChips(),
            ),
          AnimatedMicButton(
            isListening: _isListening,
            isProcessing: _isProcessing || _isSpeaking,
            onTap: _toggleListening,
          ),
        ],
      ),
    );
  }

  Widget _buildExtractChips() {
    final map = _lastExtract!.toMap();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: map.entries.map((e) {
        return Chip(
          avatar: Icon(Icons.check_circle, size: 16, color: AppTheme.success),
          label: Text('${e.key}: ${e.value}',
              style: const TextStyle(fontSize: 11)),
          backgroundColor: AppTheme.success.withValues(alpha: 0.08),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

class _ChatMessage {
  final String role;
  final String text;
  final DateTime time;
  _ChatMessage({
    required this.role,
    required this.text,
    required this.time,
  });
}
