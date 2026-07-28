import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  bool _available = false;
  bool _listening = false;
  String _lastWords = '';

  bool get isAvailable => _available;
  bool get isListening => _listening;
  String get lastWords => _lastWords;

  Future<bool> init() async {
    _available = await _speech.initialize(
      onError: (error) => debugPrint('Speech error: $error'),
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          _listening = false;
        }
      },
    );
    return _available;
  }

  Future<String> listen({Duration? timeout}) async {
    if (!_available) {
      await init();
    }
    if (!_available) return '';

    _listening = true;
    _lastWords = '';

    final completer = Completer<String>();

    await _speech.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords;
        if (result.finalResult) {
          completer.complete(result.recognizedWords);
        }
      },
      listenFor: timeout ?? const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(partialResults: true),
      localeId: 'fr_FR',
    );

    return completer.future;
  }

  Future<void> stop() async {
    if (_listening) {
      await _speech.stop();
      _listening = false;
    }
  }

  void dispose() {
    _speech.stop();
  }

  Map<String, dynamic> parseDeclaration(String text) {
    final lower = text.toLowerCase();
    final result = <String, dynamic>{};

    if (lower.contains('moteur')) {
      result['typePanne'] = 'MOTEUR';
    } else if (lower.contains('frein')) {
      result['typePanne'] = 'FREIN';
    } else if (lower.contains('pneu')) {
      result['typePanne'] = 'PNEU';
    } else if (lower.contains('électrique') || lower.contains('electrique')) {
      result['typePanne'] = 'ELECTRIQUE';
    } else if (lower.contains('carrosserie')) {
      result['typePanne'] = 'CARROSSERIE';
    } else if (lower.contains('transmission')) {
      result['typePanne'] = 'TRANSMISSION';
    } else if (lower.contains('clim')) {
      result['typePanne'] = 'CLIMATISATION';
    } else {
      result['typePanne'] = 'AUTRE';
    }

    final immatRegex = RegExp(r'[A-Z]{2,3}[\s-]?\d{3}[\s-]?[A-Z]{2}');
    final match = immatRegex.firstMatch(text.toUpperCase());
    if (match != null) {
      result['immatriculation'] =
          match.group(0)?.replaceAll(RegExp(r'\s+'), '-') ?? '';
    }

    result['description'] = text;

    if (lower.contains('urgent') || lower.contains('critique')) {
      result['priorite'] = 'URGENTE';
    }

    return result;
  }
}
