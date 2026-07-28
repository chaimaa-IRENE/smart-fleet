import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:record/record.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/voice_agent_backend_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/declaration_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/danone_app_bar.dart';


enum _State { start, session, done }

class DarijaChoice {
  final int id;
  final String labelFr;
  final String labelDarija;
  final String labelArabic;
  DarijaChoice({required this.id, required this.labelFr, required this.labelDarija, required this.labelArabic});
}

const _STEP_ORDER = [
  'greeting', 'vehicule', 'immatriculation', 'typePanne',
  'elementVehicule', 'detailElement', 'criticite', 'kilometrage',
  'lieu', 'dateHeure', 'source', 'categorie', 'confirmation',
];

const _STEP_ICONS = {
  'greeting': Icons.waving_hand,
  'vehicule': Icons.local_shipping,
  'immatriculation': Icons.confirmation_number,
  'typePanne': Icons.build,
  'elementVehicule': Icons.build,
  'detailElement': Icons.description,
  'criticite': Icons.shield,
  'kilometrage': Icons.speed,
  'lieu': Icons.location_on,
  'dateHeure': Icons.calendar_today,
  'description': Icons.article,
  'source': Icons.search,
  'categorie': Icons.category,
  'confirmation': Icons.check_circle,
};

const _FIELDS_TO_COLLECT = [
  'vehicule', 'immatriculation', 'typePanne', 'elementVehicule',
  'detailElement', 'criticite', 'kilometrage', 'lieu',
  'dateHeure', 'source', 'categorie',
];

class VoiceAgent extends StatefulWidget {
  const VoiceAgent({super.key});
  @override
  State<VoiceAgent> createState() => _VoiceAgentState();
}

class _VoiceAgentState extends State<VoiceAgent> {
  final _backend = VoiceAgentBackendService();
  final _speech = stt.SpeechToText();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  _State _state = _State.start;
  bool _isOnline = true;
  bool _muted = false;
  bool _loading = false;
  bool _listening = false;
  bool _speaking = false;
  bool _sttAvailable = false;

  String? _sessionId;
  String _questionDarija = '';
  String _questionFrancais = '';
  Map<String, String> _extract = {};
  List<_ChatMsg> _messages = [];
  List<DarijaChoice> _choices = [];
  String _field = 'greeting';
  String _summary = '';
  bool _done = false;
  String? _errorMsg;
  String? _pendingConfirmValue;
  bool _kilometrageConfirmed = false;
  String _accumulatedText = '';
  String _sttLiveText = '';
  String? _recordingPath;
  int _sttLocaleIdx = 0;
  int _ttsRetryCount = 0;

  Timer? _vadTimer;
  Timer? _silenceTimer;
  DateTime _lastResult = DateTime.now();
  String _lastSpoken = '';

  List<Map<String, dynamic>> _assignedVehicles = [];

  static const _typePanne = [
    ['ميكانيكي', 'Mécanique', 'عطل ميكانيكي'],
    ['كهربائي', 'Électrique', 'عطل كهربائي'],
    ['هيكل', 'Caisse', 'عطل في الهيكل'],
    ['سلامة', 'Sécurité', 'عطل أمان'],
    ['آخر', 'Autres', 'أخرى'],
  ];
  static const _elements = [
    ['هيكل', 'Caisse', 'هيكل'],
    ['إضاءة', 'Éclairage', 'إضاءة'],
    ['تبريد', 'Froid', 'تبريد'],
    ['ميكانيكي', 'Mécanique', 'ميكانيكي'],
    ['ورق ولوازم', 'Papier/Accessoire', 'ورق ولوازم'],
  ];
  static const _detailElements = [
    ['بوق', 'Klaxon', 'بوق'],
    ['أرضية', 'Plancher', 'أرضية'],
    ['ألواح', 'Panneaux', 'ألواح'],
    ['سقف', 'Plafond', 'سقف'],
    ['وجه أمامي', 'Face avant', 'وجه أمامي'],
    ['جسور', 'Ponts', 'جسور'],
    ['عزل', 'Étanchéité', 'عزل'],
    ['حزام خلفي', 'Lanière arrière', 'حزام خلفي'],
    ['حزام جانبي', 'Lanière latérale', 'حزام جانبي'],
    ['درجة', 'Marchpied', 'درجة'],
    ['باب خلفي', 'Hayon', 'باب خلفي'],
    ['مقبض', 'Poignée inox', 'مقبض'],
    ['قضبان حماية', 'Barres pare-cycliste', 'قضبان حماية'],
    ['أشرطة عاكسة', 'Bandos réfléchissantes', 'أشرطة عاكسة'],
    ['نقاط ارتكاز', "Trois points d'appui", 'نقاط ارتكاز'],
  ];
  static const _criticites = [
    ['عادي', 'Non bloquant', 'عادي'],
    ['معطل', 'Bloquant', 'معطل'],
    ['عاجل', 'Urgent', 'عاجل'],
    ['أمان', 'Sécurité', 'سلامة'],
  ];
  static const _sources = [
    ['يدوي', 'Manuel', 'يدوي'],
    ['بطاقة تنبيه', "Fiche d'alerte", 'بطاقة تنبيه'],
    ['صيانة علاجية', 'Maintenance curative', 'صيانة علاجية'],
    ['صيانة شهرية', 'Maint. prév. mensuelle', 'صيانة شهرية'],
    ['صيانة أسبوعية', 'Maint. prév. hebdomadaire', 'صيانة أسبوعية'],
    ['صيانة ربع سنوية', 'Maint. prév. trimestrielle', 'صيانة ربع سنوية'],
    ['عطل في الطريق', 'Panne en marche', 'عطل في الطريق'],
    ['حادث في الطريق', 'Incident en marche', 'حادث في الطريق'],
  ];
  static const _categories = [
    ['ميكانيكي', 'Mécanique', 'ميكانيكي'],
    ['سلامة', 'Sécurité', 'سلامة'],
    ['جودة', 'Qualité', 'جودة'],
    ['رؤية', 'Visibilité', 'رؤية'],
    ['وثائق قانونية', 'Doc. légale', 'وثائق قانونية'],
    ['خارجي', 'Extérieur', 'خارجي'],
  ];


  List<DarijaChoice> _makeChoices(List<List<String>> items) {
    return items.asMap().entries.map((e) => DarijaChoice(
      id: e.key + 1, labelFr: e.value[1], labelDarija: e.value[0], labelArabic: e.value[2],
    )).toList();
  }

  String? _nextField() {
    if (_done) return null;
    Set<String> collected = {};
    for (final e in _extract.entries) collected.add(e.key);
    // detailElement only if elementVehicule is ميكانيك or كرسو
      final ev = _extract['elementVehicule'];
    final skipDetail = ev != null && ev != 'ميكانيكي' && ev != 'هيكل';
    for (final f in _FIELDS_TO_COLLECT) {
      if (f == 'detailElement' && skipDetail) continue;
      if (!collected.contains(f)) return f;
    }
    return null;
  }

  List<DarijaChoice> _choicesForField(String field) {
    switch (field) {
      case 'vehicule':
        if (_assignedVehicles.isNotEmpty) {
          return _assignedVehicles.asMap().entries.map((e) {
            final v = e.value;
            final immat = v['immatriculation'] as String? ?? '';
            final typeFr = v['type'] as String? ?? '';
            final label = '$immat - $typeFr';
            return DarijaChoice(
              id: e.key + 1,
              labelFr: label,
              labelDarija: label,
              labelArabic: immat,
            );
          }).toList();
        }
        // fallback to hardcoded
        return _makeChoices([
          ['ميني باص', 'Mini-Bus', 'ميني باص'],
          ['كاميون متوسط', 'Camion moyen', 'كاميون متوسط'],
          ['كاميون كبير', 'Camion lourd', 'كاميون كبير'],
          ['ريمارك', 'Remorque', 'ريمارك'],
          ['كاميون مقلعة', 'Camion benne', 'كاميون مقلعة'],
        ]);
      case 'typePanne': return _makeChoices(_typePanne);
      case 'elementVehicule': return _makeChoices(_elements);
      case 'detailElement': return _makeChoices(_detailElements);
      case 'criticite': return _makeChoices(_criticites);
      case 'source': return _makeChoices(_sources);
      case 'categorie': return _makeChoices(_categories);
      default: return [];
    }
  }

  String _questionForField(String field) {
    switch (field) {
      case 'vehicule': return 'شنو الطوموبيل ديالك؟ اختار من اللائحة';
      case 'immatriculation': return 'شنو رقم الطوموبيل؟ قل الأرقام والحروف ديال لوحة';
      case 'typePanne': return 'ما نوع العطل؟ اختر: Cliquer 1 ميكانيكي - Cliquer 2 كهربائي - Cliquer 3 هيكل - Cliquer 4 سلامة - Cliquer 5 آخر';
      case 'elementVehicule': return 'أين المشكل؟ اختر: Cliquer 1 هيكل - Cliquer 2 إضاءة - Cliquer 3 تبريد - Cliquer 4 ميكانيكي - Cliquer 5 ورق ولوازم';
      case 'detailElement': return 'ما تفصيل القطعة؟ اختر: Cliquer 1 بوق - Cliquer 2 أرضية - Cliquer 3 ألواح - Cliquer 4 سقف - Cliquer 5 وجه أمامي - Cliquer 6 جسور - Cliquer 7 عزل - Cliquer 8 حزام خلفي - Cliquer 9 حزام جانبي - Cliquer 10 درجة - Cliquer 11 باب خلفي - Cliquer 12 مقبض - Cliquer 13 قضبان حماية - Cliquer 14 أشرطة عاكسة - Cliquer 15 نقاط ارتكاز';
      case 'criticite': return 'ما مستوى الخطورة؟ اختر: Cliquer 1 عادي - Cliquer 2 معطل - Cliquer 3 عاجل - Cliquer 4 أمان';
      case 'kilometrage': return 'كم الكيلومتر الآن؟ قل الرقم الموجود في العداد';
      case 'lieu': return 'أين وقع المشكل؟ قل المكان بالضبط';
      case 'dateHeure': return 'متى وقع المشكل؟ قل التاريخ والوقت';
      case 'source': return 'من أين علمت بهذا المشكل؟ اختر: Cliquer 1 يدوي - Cliquer 2 بطاقة تنبيه - Cliquer 3 صيانة علاجية - Cliquer 4 صيانة شهرية - Cliquer 5 صيانة أسبوعية - Cliquer 6 صيانة ربع سنوية - Cliquer 7 عطل في الطريق - Cliquer 8 حادث في الطريق';
      case 'categorie': return 'ما نوع هذا المشكل؟ اختر: Cliquer 1 ميكانيكي - Cliquer 2 سلامة - Cliquer 3 جودة - Cliquer 4 رؤية - Cliquer 5 وثائق قانونية - Cliquer 6 خارجي';
      default: return '';
    }
  }

  String _questionFrForField(String field) {
    switch (field) {
      case 'vehicule': return 'Quel est votre véhicule? Choisissez dans la liste';
      case 'immatriculation': return 'Quelle est la plaque d\'immatriculation? Dites les chiffres et lettres.';
      case 'typePanne': return 'Quel type de panne? Cliquer 1 Mécanique - Cliquer 2 Électrique - Cliquer 3 Caisse - Cliquer 4 Sécurité - Cliquer 5 Autres';
      case 'elementVehicule': return 'Quel élément du véhicule? Cliquer 1 Caisse - Cliquer 2 Éclairage - Cliquer 3 Froid - Cliquer 4 Mécanique - Cliquer 5 Papier/Accessoire';
      case 'detailElement': return 'Quel détail de l\'élément? Cliquer 1 Klaxon - Cliquer 2 Plancher - Cliquer 3 Panneaux - Cliquer 4 Plafond - Cliquer 5 Face avant - Cliquer 6 Ponts - Cliquer 7 Étanchéité - Cliquer 8 Lanière arrière - Cliquer 9 Lanière latérale - Cliquer 10 Marchpied - Cliquer 11 Hayon - Cliquer 12 Poignée inox - Cliquer 13 Barres pare-cycliste - Cliquer 14 Bandos réfléchissantes - Cliquer 15 Trois points d\'appui';
      case 'criticite': return 'Quelle est la criticité? Cliquer 1 Non bloquant - Cliquer 2 Bloquant - Cliquer 3 Urgent - Cliquer 4 Sécurité';
      case 'kilometrage': return 'Quel est le kilométrage? Dites le nombre du compteur.';
      case 'lieu': return 'Où s\'est produit le problème? Dites le lieu exact.';
      case 'dateHeure': return 'Quand s\'est produit le problème? Dites la date et l\'heure.';
      case 'description': return 'Donnez une description complète du problème.';
      case 'source': return 'Quelle est la source? Cliquer 1 Manuel - Cliquer 2 Fiche d\'alerte - Cliquer 3 Maintenance curative - Cliquer 4 Maint. prév. mensuelle - Cliquer 5 Maint. prév. hebdomadaire - Cliquer 6 Maint. prév. trimestrielle - Cliquer 7 Panne en marche - Cliquer 8 Incident en marche';
      case 'categorie': return 'Quelle est la catégorie? Cliquer 1 Mécanique - Cliquer 2 Sécurité - Cliquer 3 Qualité - Cliquer 4 Visibilité - Cliquer 5 Doc. légale - Cliquer 6 Extérieur';
      default: return '';
    }
  }

  int get _currentStepIdx {
    final idx = _STEP_ORDER.indexOf(_field);
    return idx >= 0 ? idx : 0;
  }

  int get _progressPercent {
    if (_done) return 100;
    final total = _STEP_ORDER.length - 2; // exclude greeting, confirmation
    return min(((_currentStepIdx - 1).clamp(0, total) / total * 100).round(), 99);
  }

  // ─── Normalisation plaque marocaine ───────────────────────────
  String _normalizeImmatriculation(String raw) {
    String s = raw.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[àâäæ]'), 'a');
    s = s.replaceAll(RegExp(r'[éèêë]'), 'e');
    s = s.replaceAll(RegExp(r'[ïî]'), 'i');
    s = s.replaceAll(RegExp(r'[ôœ]'), 'o');
    s = s.replaceAll(RegExp(r'[ùûü]'), 'u');

    final frWords = {
      'un':'1','deux':'2','trois':'3','quatre':'4','cinq':'5','six':'6',
      'sept':'7','huit':'8','neuf':'9','zéro':'0','zero':'0','dix':'10',
      'onze':'11','douze':'12','treize':'13','quatorze':'14','quinze':'15',
      'seize':'16','vingt':'20','trente':'30','cent':'00','cents':'00',
      'mille':'000','million':'000000','millions':'000000',
    };
    for (final e in frWords.entries) {
      s = s.replaceAll(RegExp('\\b${e.key}\\b'), e.value);
    }

    final arNames = {
      'alif':'A','alef':'A','ba':'B','be':'B','ta':'T','te':'T',
      'dal':'D','dhal':'D','ra':'R','re':'R',
      'sin':'S','sine':'S','seen':'S','fa':'F','fe':'F','kaf':'K','kef':'K',
      'qaf':'Q','lam':'L','lem':'L','mim':'M','mem':'M',
      'nun':'N','noun':'N','waw':'W','ouaou':'W','ha':'H','he':'H',
      'ya':'Y','ye':'Y','zay':'Z','ze':'Z','jeem':'J','jim':'J',
      'ain':'A','gh':'GH','ghayn':'GH','kha':'KH','tha':'TH','ch':'CH',
    };
    for (final e in arNames.entries) {
      s = s.replaceAll(RegExp('\\b${e.key}\\b'), e.value);
    }

    final frLettres = {
      'a':'A','be':'B','bé':'B','ce':'C','cé':'C','de':'D','dé':'D',
      'effe':'F','ge':'G','gé':'G','hache':'H','ache':'H','ji':'J','ka':'K','ke':'K',
      'elle':'L','emme':'M','enne':'N','pe':'P','pé':'P','ku':'Q',
      'erre':'R','esse':'S','te':'T','té':'T','ve':'V','vé':'V',
      'zed':'Z','zède':'Z','ze':'Z',
    };
    for (final e in frLettres.entries) {
      s = s.replaceAll(RegExp('\\b${e.key}\\b'), e.value);
    }

    // Arabic digits
    final arDigits = {
      '\u0660':'0','\u0661':'1','\u0662':'2','\u0663':'3',
      '\u0664':'4','\u0665':'5','\u0666':'6','\u0667':'7','\u0668':'8','\u0669':'9',
    };
    s = s.replaceAllMapped(RegExp(r'[\u0600-\u06FF]'), (m) {
      final c = m.group(0)!;
      return arDigits[c] ?? '';
    });

    s = s.replaceAll(RegExp(r'[|\-/\s]+'), '').toUpperCase();
    final m1 = RegExp(r'^(\d+)([A-Z]+)(\d*)$').firstMatch(s);
    if (m1 != null && m1.group(1)!.length >= 3) {
      final d1 = m1.group(1)!;
      final letters = m1.group(2)!;
      final d2 = m1.group(3)!;
      return d2.isNotEmpty ? '$d1-$letters-$d2' : '$d1-$letters';
    }
    final m2 = RegExp(r'^([A-Z]+)(\d+)([A-Z]+)$').firstMatch(s);
    if (m2 != null) {
      return '${m2.group(1)}-${m2.group(2)}-${m2.group(3)}';
    }
    return s.isEmpty ? raw.toUpperCase() : s;
  }

  // ─── Translitération Darija → Arabe ──────────────────────────
  static const _d2a = {
    'sm7 lia': '\u0633\u0645\u062D \u0644\u064A\u0627',
    'kifach': '\u0643\u064A\u0641\u0627\u0634',
    'kifash': '\u0643\u064A\u0641\u0627\u0634',
    '3lach': '\u0639\u0644\u0627\u0634',
    'wakha': '\u0648\u0627\u062E\u0627',
    'walou': '\u0648\u0627\u0644\u0648',
    'mashi': '\u0645\u0627\u0634\u064A',
    'mach': '\u0645\u0627\u0634\u064A',
    'mochkil': '\u0645\u0634\u0643\u0644',
    'safi': '\u0635\u0627\u0641\u064A',
    'daba': '\u062F\u0627\u0628\u0627',
    'hadi': '\u0647\u0627\u062F\u064A',
    'hna': '\u0647\u0646\u0627',
    'nta': '\u0646\u062A\u0627',
    'ntaya': '\u0646\u062A\u0627\u064A\u0627',
    'ana': '\u0623\u0646\u0627',
    'salam': '\u0633\u0644\u0627\u0645',
    'bghit': '\u0628\u063A\u064A\u062A',
    'ghadi': '\u063A\u0627\u062F\u064A',
    'kayn': '\u0643\u0627\u064A\u0646',
    'makaynch': '\u0645\u0627\u0643\u0627\u064A\u0646\u0634',
    'bass': '\u0628\u0627\u0633',
    'bzzaf': '\u0628\u0632\u0627\u0641',
    'chwiya': '\u0634\u0648\u064A\u0629',
    'chwya': '\u0634\u0648\u064A\u0629',
    'baraka': '\u0628\u0631\u0643\u0629',
    'fin': '\u0641\u064A\u0646',
    'imta': '\u064A\u0645\u062A\u0627',
    'dima': '\u062F\u064A\u0645\u0627',
    'b7al': '\u0628\u062D\u0627\u0644',
    'mzyan': '\u0645\u0632\u064A\u0627\u0646',
    'khoya': '\u062E\u0648\u064A\u0627',
    'khweya': '\u062E\u0648\u064A\u0627',
    '7aja': '\u062D\u0627\u062C\u0629',
    '7ad': '\u062D\u062F',
    'chhal': '\u0634\u062D\u0627\u0644',
    'ch?hal': '\u0634\u062D\u0627\u0644',
    '9bl': '\u0642\u0628\u0644',
    'ba3d': '\u0628\u0639\u062F',
    't3awed': '\u062A\u0639\u0627\u0648\u062F',
    '3awed': '\u0639\u0627\u0648\u062F',
    'm3ak': '\u0645\u0639\u0627\u0643',
    'm3akom': '\u0645\u0639\u0627\u0643\u0645',
    '3awnek': '\u0639\u0627\u0648\u0646\u0643',
    'sma3ni': '\u0633\u0645\u0639\u0646\u064A',
    'tfaddel': '\u062A\u0641\u0636\u0644',
    'goul': '\u0642\u0648\u0644',
    'dir': '\u062F\u064A\u0631',
    'sir': '\u0633\u064A\u0631',
    'chof': '\u0634\u0648\u0641',
    'kolchi': '\u0643\u0644\u0634\u064A',
    'b9it': '\u0628\u0642\u064A\u062A',
    'b9a': '\u0628\u0642\u0649',
    'bqa': '\u0628\u0642\u0649',
    's7i7': '\u0635\u062D',
    'sahih': '\u0635\u062D',
    'wach': '\u0648\u0627\u0634',
    'lah': '\u0627\u0644\u0644\u0647',
    'allah': '\u0627\u0644\u0644\u0647',
    '3ti': '\u0639\u0637\u064A',
    'hadchi': '\u0647\u0627\u062F\u0634\u064A',
    'naw3': '\u0646\u0648\u0639',
    'no3': '\u0646\u0648\u0639',
    'dial': '\u062F\u064A\u0627\u0644',
    'dyal': '\u062F\u064A\u0627\u0644',
    '3andek': '\u0639\u0646\u062F\u0643',
    '3andna': '\u0639\u0646\u062F\u0646\u0627',
    'wa9ef': '\u0648\u0627\u0642\u0641',
    'blasa': '\u0628\u0644\u0627\u0635\u0629',
    'btabt': '\u0628\u062F\u0642\u0629',
    'bdabt': '\u0628\u062F\u0642\u0629',
    'lya': '\u0644\u064A\u0627',
    'li': '\u0644\u064A',
    'chno': '\u0634\u0646\u0648',
    'bda': '\u0628\u062F\u0649',
    'nbdaou': '\u0646\u0628\u062F\u0627\u0648',
    'nbdew': '\u0646\u0628\u062F\u0627\u0648',
    'la': '\u0644\u0627',
    'wah': '\u0648\u0627\u0647',
    'ah': '\u0622\u0647',
    'oui': '\u0646\u0639\u0645',
    'na3am': '\u0646\u0639\u0645',
    'darouri': '\u0636\u0631\u0648\u0631\u064A',
    "l'makina": '\u0627\u0644\u0645\u0627\u0643\u064A\u0646\u0629',
    'casa': '\u0627\u0644\u062F\u0627\u0631 \u0627\u0644\u0628\u064A\u0636\u0627\u0621',
    'rbat': '\u0627\u0644\u0631\u0628\u0627\u0637',
    'tanja': '\u0637\u0646\u062C\u0629',
    'fes': '\u0641\u0627\u0633',
    'marra': '\u0645\u0631\u0627\u0643\u0634',
  };

  String _transliterateDarija(String text) {
    String r = text;
    final sortedKeys = _d2a.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final k in sortedKeys) {
      r = r.replaceAll(RegExp(RegExp.escape(k), caseSensitive: false), _d2a[k]!);
    }
    r = r.replaceAll('3', '\u0639');
    r = r.replaceAll('7', '\u062D');
    r = r.replaceAll('9', '\u0642');
    r = r.replaceAll('5', '\u062E');
    r = r.replaceAll('6', '\u0637');
    final buf = StringBuffer();
    for (int i = 0; i < r.length; i++) {
      final c = r[i];
      final code = c.codeUnitAt(0);
      if ((code >= 0x0600 && code <= 0x06FF) || (code >= 0xFE70 && code <= 0xFEFF)) {
        buf.write(c);
      } else if (RegExp(r'[a-zA-Z]').hasMatch(c)) {
        final lc = c.toLowerCase();
        const charMap = {
          'a': '\u0627', 'b': '\u0628', 'c': '\u0643', 'd': '\u062F',
          'e': '\u064A', 'f': '\u0641', 'g': '\u06AF', 'h': '\u0647',
          'i': '\u064A', 'j': '\u062C', 'k': '\u0643', 'l': '\u0644',
          'm': '\u0645', 'n': '\u0646', 'o': '\u0648', 'p': '\u067E',
          'q': '\u0642', 'r': '\u0631', 's': '\u0633', 't': '\u062A',
          'u': '\u0648', 'v': '\u06A4', 'w': '\u0648', 'x': '\u0643\u0633',
          'y': '\u064A', 'z': '\u0632',
        };
        // check for multi-char first
        if (i + 1 < r.length) {
          final next = r[i + 1].toLowerCase();
          final pair = lc + next;
          final multiMap = {
            'ch': '\u0634', 'kh': '\u062E', 'gh': '\u063A',
            'sh': '\u0634', 'th': '\u062B', 'dh': '\u0630',
          };
          if (multiMap.containsKey(pair)) {
            buf.write(multiMap[pair]);
            i++;
            continue;
          }
        }
        buf.write(charMap[lc] ?? c);
      } else {
        buf.write(c);
      }
    }
    return buf.toString();
  }

  // ─── Match véhicule par voix ──────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _vadTimer?.cancel();
    _silenceTimer?.cancel();
    _speech.stop();
    _audioPlayer.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      _isOnline = connectivity != ConnectivityResult.none;
    } catch (_) {}
    try {
      _sttAvailable = await _speech.initialize(
        onError: (e) => debugPrint('STT: $e'),
        onStatus: (s) => debugPrint('STT: $s'),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      _sttAvailable = false;
    }
    if (mounted) setState(() {});
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addMsg(bool isUser, {required String text, String? textFr}) {
    _messages.add(_ChatMsg(isUser: isUser, text: text, textFr: textFr));
    if (mounted) setState(() {});
    _scrollDown();
  }

  void _speak(String text) {
    if (text.isEmpty || _muted) return;
    setState(() => _speaking = true);
    _speakAsync(text);
  }

  Future<void> _speakAsync(String text) async {
    try {
      final uri = Uri.parse('${ApiConfig.ttsUrl}/api/tts/speak').replace(queryParameters: {
        'text': text, 'voice': 'ar-MA-JamalNeural', 'rate': '-5%',
      });
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final f = File('${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await f.writeAsBytes(resp.bodyBytes);
        await _audioPlayer.play(DeviceFileSource(f.path));
        await _audioPlayer.onPlayerComplete.first;
        f.delete();
      }
    } catch (_) {
      _ttsRetryCount++;
      if (_ttsRetryCount <= 1) {
        await Future.delayed(const Duration(seconds: 1));
        try {
          final uri = Uri.parse('${ApiConfig.ttsUrl}/api/tts/speak').replace(queryParameters: {
            'text': text, 'voice': 'ar-MA-JamalNeural', 'rate': '-5%',
          });
          final resp = await http.get(uri).timeout(const Duration(seconds: 5));
          if (resp.statusCode == 200) {
            final dir = await getTemporaryDirectory();
            final f = File('${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
            await f.writeAsBytes(resp.bodyBytes);
            await _audioPlayer.play(DeviceFileSource(f.path));
            await _audioPlayer.onPlayerComplete.first;
            f.delete();
          }
        } catch (_) {}
      }
    }
    _ttsRetryCount = 0;
    if (mounted) setState(() => _speaking = false);
  }

  void _stopTts() {
    _audioPlayer.stop();
    setState(() => _speaking = false);
  }

  Future<void> _startSession() async {
    setState(() { _loading = true; _errorMsg = null; });
    _done = false;
    _lastSpoken = '';
    _messages = [];
    _assignedVehicles = [];
    _kilometrageConfirmed = false;
    try {
      final user = context.read<AuthProvider>().user;
      final chauffeurId = context.read<AuthProvider>().userId;

      if (chauffeurId != null) {
        final vehSvc = VehicleService();
        _assignedVehicles = await vehSvc.getMyVehicles(chauffeurId);
      }

      final resp = await _backend.startSession(
        chauffeurId: chauffeurId ?? 0,
        chauffeurNom: user?['nom'] as String? ?? 'Chauffeur',
      );
      if (resp.error != null) throw Exception(resp.error);
      _sessionId = resp.sessionId;
      _field = 'greeting';
      _addMsg(false, text: 'السلام عليكم! أنا المساعد الصوتي لSmartFleet. سأساعدك في التصريح عن العطل.');
      _speak('السلام عليكم! أنا المساعد الصوتي لSmartFleet. سأساعدك في التصريح عن العطل.');
      await _showNextStep();
      if (mounted) setState(() => _state = _State.session);
    } catch (e) {
      _addMsg(false, text: 'خطأ فالاتصال: $e');
      if (mounted) setState(() => _errorMsg = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showNextStep() async {
    final next = _nextField();
    if (next == null) return _finish();
    _field = next;
    _kilometrageConfirmed = false;
    _questionDarija = _questionForField(next);
    _questionFrancais = _questionFrForField(next);
    _choices = _choicesForField(next);
    _addMsg(false, text: _questionDarija, textFr: _questionFrancais);
    _playQuestionTts();
  }

  Future<void> _finish() async {
    _done = true;
    _summary = _buildSummary();
    final advice = _buildAdvice();
    final jsonStr = _buildJson();
    _addMsg(false, text: '$_summary\n\nنصيحة: $advice\n\n$jsonStr');
    if (!_muted) _speak('$_summary. نصيحة: $advice');
    // Save declaration to local database
    try {
      final chauffeurId = context.read<AuthProvider>().userId;
      if (chauffeurId != null) {
        await DeclarationService().create({
          'chauffeurId': chauffeurId,
          'typePanne': _extract['typePanne'] ?? '',
          'immatriculation': _extract['immatriculation'] ?? '',
          'elementVehicule': _extract['elementVehicule'] ?? '',
          'detailElement': _extract['detailElement'] ?? '',
          'criticite': _extract['criticite'] ?? '',
          'kilometrage': _extract['kilometrage'] ?? '',
          'lieu': _extract['lieu'] ?? '',
          'dateHeure': _extract['dateHeure'] ?? '',
          'source': _extract['source'] ?? '',
          'categorie': _extract['categorie'] ?? '',
          'statut': 'NOUVEAU',
          'dateCreation': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Save declaration error: $e');
    }
    if (mounted) setState(() => _state = _State.done);
  }

  void _playQuestionTts() {
    final qText = _questionDarija.isNotEmpty ? _transliterateDarija(_questionDarija) : _questionFrancais;
    if (qText.isEmpty) return;
    final choicesText = _choices.isNotEmpty
        ? '. ' + _choices.map((c) => 'Cliquer ${c.id} ${c.labelArabic.isNotEmpty ? c.labelArabic : c.labelDarija}').join(' - ')
        : '';
    final fullText = qText + choicesText;
    if (fullText.isNotEmpty && fullText != _lastSpoken) {
      _lastSpoken = fullText;
      if (!_muted && !_done) _speak(fullText);
    }
  }

  String? _resolveCliquerResponse(String text) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return null;
    final choices = _choices;
    if (choices.isEmpty) return null;

    const darijaNums = {
      'wahed': 1, 'wah': 1, 'واحد': 1, 'أحد': 1, 'jouj': 2, 'joj': 2, 'جوج': 2, 'اثنان': 2, 'اثنين': 2,
      'tlata': 3, 'تلاتة': 3, 'tlat': 3, 'ثلاثة': 3, 'ثلاث': 3,
      'arba': 4, 'اربعة': 4, 'arb3a': 4, 'أربعة': 4, 'أربع': 4,
      'khamsa': 5, 'خمسة': 5, 'خمس': 5, '5': 5,
      'sta': 6, 'ستة': 6, 'ست': 6, '6': 6,
      'seb3a': 7, 'سبعة': 7, 'سبع': 7,
      'tmanya': 8, 'تمنيا': 8, 'ثمانية': 8, 'ثمان': 8,
      'ts3oud': 9, 'tsa3oud': 9, 'تسعود': 9, 'تسعة': 9, 'تسع': 9, '9': 9,
      'achra': 10, 'عشرة': 10, '10': 10,
    };

    for (final prefix in ['cliquer ', 'numero ', 'numéro ', 'رقم ', '']) {
      var candidate = t;
      if (t.startsWith(prefix)) {
        candidate = t.substring(prefix.length).trim();
      }
      if (candidate.isEmpty) continue;
      final parsed = int.tryParse(candidate);
      if (parsed != null && parsed >= 1 && parsed <= choices.length) {
        return choices[parsed - 1].labelDarija;
      }
      if (darijaNums.containsKey(candidate)) {
        final idx = darijaNums[candidate]!;
        if (idx >= 1 && idx <= choices.length) {
          return choices[idx - 1].labelDarija;
        }
      }
    }
    return null;
  }

  String? _extractSpokenNumber(String text) {
    // First try direct digit sequence (e.g., "45000" or "45 000")
    final allDigits = RegExp(r'\d+').allMatches(text).map((m) => m.group(0)!).join();
    if (allDigits.length >= 3 && allDigits.length <= 7) {
      return allDigits;
    }

    const digitWords = <String, String>{
      // Arabic (Fosha)
      'صفر': '0',
      'واحد': '1', 'أحد': '1', 'إحدى': '1',
      'اثنان': '2', 'اثنين': '2', 'اثنتان': '2', 'اثنتين': '2', 'اثنا': '2', 'اثني': '2',
      'ثلاثة': '3', 'ثلاث': '3',
      'أربعة': '4', 'أربع': '4',
      'خمسة': '5', 'خمس': '5',
      'ستة': '6', 'ست': '6',
      'سبعة': '7', 'سبع': '7',
      'ثمانية': '8', 'ثمان': '8',
      'تسعة': '9', 'تسع': '9',
      'عشرة': '10', 'عشر': '10',
      // Tens
      'عشرون': '20', 'عشرين': '20',
      'ثلاثون': '30', 'ثلاثين': '30',
      'أربعون': '40', 'أربعين': '40',
      'خمسون': '50', 'خمسين': '50',
      'ستون': '60', 'ستين': '60',
      'سبعون': '70', 'سبعين': '70',
      'ثمانون': '80', 'ثمانين': '80',
      'تسعون': '90', 'تسعين': '90',
      // Hundreds
      'مئة': '100', 'مائة': '100',
      'مائتان': '200', 'مائتين': '200', 'مائتا': '200',
      'ثلاثمئة': '300', 'ثلاثمائة': '300',
      'أربعمئة': '400', 'أربعمائة': '400',
      'خمسمئة': '500', 'خمسمائة': '500',
      'ستمئة': '600', 'ستمائة': '600',
      'سبعمئة': '700', 'سبعمائة': '700',
      'ثمانمئة': '800', 'ثمانمائة': '800',
      'تسعمئة': '900', 'تسعمائة': '900',
      // Thousands
      'ألف': '1000', 'ألفان': '2000', 'ألفين': '2000',
      'آلاف': '1000', 'الاف': '1000',
      // Arabic Darija
      'wa7ed': '1', 'wah': '1', 'jouj': '2', 'joj': '2', 'tleta': '3',
      'tlat': '3', 'tlet': '3', 'arba': '4', 'arb3a': '4',
      'khamsa': '5', '5': '5', 'sta': '6', '6': '6',
      'seb3a': '7', 'tmanya': '8', 'ts3oud': '9', 'tsa3oud': '9',
      '9': '9', 'achra': '10',
      'rb3in': '40', 'rb3ine': '40', 'rb3een': '40',
      'khamsin': '50', 'khamsine': '50', 'khamseen': '50',
      'settin': '60', 'settine': '60', 'setteen': '60', 'setin': '60',
      'tletin': '30', 'tletine': '30', 'tleteen': '30',
      'sb3in': '70', 'sb3ine': '70', 'sb3een': '70',
      'tmanyin': '80', 'tmanyine': '80', 'tmanyeen': '80',
      'ts3in': '90', 'ts3ine': '90', 'ts3een': '90',
      'miya': '100', 'miyat': '100', 'meyya': '100', 'mitya': '100', 'mityat': '100',
      'alf': '1000', 'alfayn': '2000', 'alaf': '1000',
      // French
      'zéro': '0', 'zero': '0',
      'un': '1', 'deux': '2', 'trois': '3', 'quatre': '4',
      'cinq': '5', 'six': '6', 'sept': '7', 'huit': '8', 'neuf': '9',
      'dix': '10', 'onze': '11', 'douze': '12', 'treize': '13',
      'quatorze': '14', 'quinze': '15', 'seize': '16',
      'vingt': '20', 'trente': '30', 'quarante': '40',
      'cinquante': '50', 'soixante': '60',
      'cent': '100', 'mille': '1000',
    };

    // Pre-process French compound numbers (quatre-vingt → 80, etc.)
    const frCompounds = <String, String>{
      'dix-sept': '17', 'dix-huit': '18', 'dix-neuf': '19',
      'vingt-et-un': '21', 'vingt-deux': '22', 'vingt-trois': '23',
      'vingt-quatre': '24', 'vingt-cinq': '25', 'vingt-six': '26',
      'vingt-sept': '27', 'vingt-huit': '28', 'vingt-neuf': '29',
      'trente-et-un': '31', 'trente-deux': '32', 'trente-trois': '33',
      'trente-quatre': '34', 'trente-cinq': '35', 'trente-six': '36',
      'trente-sept': '37', 'trente-huit': '38', 'trente-neuf': '39',
      'quarante-et-un': '41', 'quarante-deux': '42', 'quarante-trois': '43',
      'quarante-quatre': '44', 'quarante-cinq': '45', 'quarante-six': '46',
      'quarante-sept': '47', 'quarante-huit': '48', 'quarante-neuf': '49',
      'cinquante-et-un': '51', 'cinquante-deux': '52', 'cinquante-trois': '53',
      'cinquante-quatre': '54', 'cinquante-cinq': '55', 'cinquante-six': '56',
      'cinquante-sept': '57', 'cinquante-huit': '58', 'cinquante-neuf': '59',
      'soixante-et-un': '61', 'soixante-deux': '62', 'soixante-trois': '63',
      'soixante-quatre': '64', 'soixante-cinq': '65', 'soixante-six': '66',
      'soixante-sept': '67', 'soixante-huit': '68', 'soixante-neuf': '69',
      'soixante-dix': '70', 'soixante-et-onze': '71',
      'soixante-douze': '72', 'soixante-treize': '73',
      'soixante-quatorze': '74', 'soixante-quinze': '75', 'soixante-seize': '76',
      'soixante-dix-sept': '77', 'soixante-dix-huit': '78', 'soixante-dix-neuf': '79',
      'quatre-vingt': '80',
      'quatre-vingt-un': '81', 'quatre-vingt-deux': '82', 'quatre-vingt-trois': '83',
      'quatre-vingt-quatre': '84', 'quatre-vingt-cinq': '85', 'quatre-vingt-six': '86',
      'quatre-vingt-sept': '87', 'quatre-vingt-huit': '88', 'quatre-vingt-neuf': '89',
      'quatre-vingt-dix': '90',
      'quatre-vingt-onze': '91', 'quatre-vingt-douze': '92', 'quatre-vingt-treize': '93',
      'quatre-vingt-quatorze': '94', 'quatre-vingt-quinze': '95', 'quatre-vingt-seize': '96',
      'quatre-vingt-dix-sept': '97', 'quatre-vingt-dix-huit': '98', 'quatre-vingt-dix-neuf': '99',
    };
    var processed = text;
    final sorted = frCompounds.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in sorted) {
      processed = processed.replaceAll(entry.key, entry.value);
    }
    processed = processed.replaceAll('-', ' ');

    // Parse words: try as-is first, then without و prefix, then strip tanween
    final words = processed.trim().split(RegExp(r'[\s,،]+'));
    final values = <int>[];
    for (final w in words) {
      final wc = w.toLowerCase();
      // Try original, then with و stripped, then with tanween stripped
      String? key;
      if (digitWords.containsKey(wc)) {
        key = wc;
      } else {
        final noWaw = wc.replaceFirst(RegExp(r'^و'), '');
        if (digitWords.containsKey(noWaw)) {
          key = noWaw;
        } else {
          final noTanween = noWaw.replaceFirst(RegExp(r'ًا$'), '');
          if (digitWords.containsKey(noTanween)) {
            key = noTanween;
          }
        }
      }
      if (key != null) {
        values.add(int.parse(digitWords[key]!));
      }
    }
    if (values.isEmpty) return null;

    // Compose number:
    // - All single digits (0-9): concatenate digit-by-digit
    // - "خمسة أربعة صفر صفر صفر" → [5,4,0,0,0] → 54000
    // - Larger values: additive with proper hundreds/thousands
    // - "أربعون ألف وخمسمائة" → [40,1000,500] → 40*1000+500 = 40500
    // - "أربعون ألف" → [40,1000] → 40*1000 = 40000
    // - "تسعة وأربعون ألفًا وثمانمائة" → [49,1000,800] → 49*1000+800 = 49800
    bool hasLarge = values.any((v) => v >= 10);
    if (!hasLarge) {
      final result = values.join();
      if (result.length >= 3 && result.length <= 7) return result;
      return null;
    }

    int total = 0;
    int acc = 0;     // tens+units accumulator
    int hacc = 0;    // hundreds accumulator

    for (final v in values) {
      if (v == 1000 || v == 1000000) {
        final block = hacc + acc;
        total += (block == 0 ? 1 : block) * v;
        acc = 0;
        hacc = 0;
      } else if (v == 100) {
        if (acc > 0) {
          hacc += acc * 100;
          acc = 0;
        } else if (hacc > 0) {
          hacc *= 100;
        } else {
          hacc = 100;
        }
      } else {
        acc += v;
      }
    }
    total += hacc + acc;

    final result = total.toString();
    if (result.length >= 3 && result.length <= 7) return result;
    return null;
  }

  Future<void> _sendResponse(String text) async {
    if (text.trim().isEmpty || _sessionId == null || _loading) return;
    _addMsg(true, text: text.trim());
    setState(() => _loading = true);

    String processedText = text.trim();

    // Resolve "cliquer 1", "cliquer wahed", etc. to actual choice value
    final cliquerMatch = _resolveCliquerResponse(processedText);
    if (cliquerMatch != null) {
      processedText = cliquerMatch;
    }

    // If we have a pending confirmation (kilometrage), check for confirm/reject first
    if (_pendingConfirmValue != null) {
      final lower = processedText.toLowerCase();
      if (lower.contains('واخا') || lower.contains('oui') || lower.contains('wah') || lower.contains('na3am') || lower.contains('yes') || lower.contains('shi7') || lower.contains('sah') || lower.contains('صح') || lower.contains('نعم')) {
        processedText = _pendingConfirmValue!;
        _pendingConfirmValue = null;
        _kilometrageConfirmed = true;
      } else {
        _pendingConfirmValue = null;
        _addMsg(false, text: 'حسنا، أعد قول الكيلومتر من فضلك');
        if (!_muted) _speak('حسنا، أعد قول الكيلومتر من فضلك');
        if (mounted) setState(() => _loading = false);
        return;
      }
    }

    // Auto-detect numbers for kilométrage (only when no pending confirm and not already confirmed)
    if (_field == 'kilometrage' && _pendingConfirmValue == null && !_kilometrageConfirmed) {
      String? numberStr = RegExp(r'(\d{3,7})').firstMatch(processedText)?.group(1);
      if (numberStr == null) {
        numberStr = _extractSpokenNumber(processedText);
      }
      if (numberStr != null) {
        _pendingConfirmValue = numberStr;
        _addMsg(false, text: 'قلت: $_pendingConfirmValue. هل هذا صحيح؟');
        if (!_muted) _speak('قلت: $_pendingConfirmValue. هل هذا صحيح؟ قل واخا للتأكيد');
        if (mounted) setState(() => _loading = false);
        return;
      }
      // No number detected — stay on this step and ask again
      _addMsg(false, text: 'لم أفهم الرقم. قل الكيلومتر مرة أخرى (مثلاً: خمسون ألفًا أو 50000)');
      if (!_muted) _speak('لم أفهم الرقم. قل الكيلومتر مرة أخرى');
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final resp = await _backend.sendResponse(
        sessionId: _sessionId!,
        response: processedText,
      );
      if (resp.error != null) throw Exception(resp.error);

      // Auto-fill immatriculation when vehicle selected from assigned list
      if (_field == 'vehicule' && _assignedVehicles.isNotEmpty && !_extract.containsKey('immatriculation')) {
        final choice = _choices.firstWhere(
          (c) => c.labelDarija == processedText,
          orElse: () => DarijaChoice(id: 0, labelFr: '', labelDarija: '', labelArabic: ''),
        );
        if (choice.labelArabic.isNotEmpty) {
          _extract['immatriculation'] = choice.labelArabic;
        }
      }

      if (_field == 'immatriculation') {
        processedText = _normalizeImmatriculation(processedText);
      }
      // Only accept the extract field for our current step
      if (_field.isNotEmpty) {
        _extract[_field] = processedText;
      }

      // Show auto-filled immatriculation message
      if (_field == 'vehicule' && _assignedVehicles.isNotEmpty && _extract['immatriculation']?.isNotEmpty == true) {
        _addMsg(false, text: 'الطوموبيل: ${_extract['immatriculation']}');
      }

      await _showNextStep();
    } catch (e) {
      _addMsg(false, text: 'خطأ: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  String _buildSummary() {
    final buf = StringBuffer('خلاصة التصريح:\n');
    for (final e in _extract.entries) {
      buf.writeln('• ${e.key}: ${e.value}');
    }
    buf.writeln('\nشكرا بزاف! التصريح تم بنجاح.');
    return buf.toString();
  }

  String _buildAdvice() {
    final tp = _extract['typePanne']?.toLowerCase() ?? '';
    if (tp.contains('أمان') || tp.contains('sécurité') || tp.contains('securite')
        || tp.contains('عطل مانع') || tp.contains('bloquant')) {
      return 'وقف الشاحنة ف الحال واتصل بالمساعدة التقنية.';
    }
    if (tp.contains('ميكانيك') || tp.contains('mecanique') || tp.contains('mécanique')) {
      return 'خاصك تمشي للغاراج. لا تمشي ب الطرون.';
    }
    if (tp.contains('كهرباء') || tp.contains('électrique') || tp.contains('electrique')) {
      return 'جرب تفحص الكهرباء. إذا ما خدمتش، اتصل ب الخدمة التقنية.';
    }
    if (tp.contains('كرسو') || tp.contains('caisse')) {
      return 'تقدر تمشي ب الطرون ولكن زور الغاراج ف القريب.';
    }
    return 'اتصل بالخدمة التقنية باش تشوف المشكل.';
  }

  String _buildJson() {
    return '{\n'
        '  "vehicule": "${_extract['vehicule'] ?? ""}",\n'
        '  "immatriculation": "${_extract['immatriculation'] ?? ""}",\n'
        '  "typePanne": "${_extract['typePanne'] ?? ""}",\n'
        '  "elementVehicule": "${_extract['elementVehicule'] ?? ""}",\n'
        '  "detailElement": "${_extract['detailElement'] ?? ""}",\n'
        '  "criticite": "${_extract['criticite'] ?? ""}",\n'
        '  "kilometrage": "${_extract['kilometrage'] ?? ""}",\n'
        '  "lieu": "${_extract['lieu'] ?? ""}",\n'
        '  "dateHeure": "${_extract['dateHeure'] ?? ""}",\n'
        '  "source": "${_extract['source'] ?? ""}",\n'
        '  "categorie": "${_extract['categorie'] ?? ""}"\n'
        '}';
  }

  void _selectChoice(DarijaChoice choice) {
    if (_field == 'vehicule' && _assignedVehicles.isNotEmpty) {
      _extract['immatriculation'] = choice.labelArabic;
    }
    _sendResponse(choice.labelDarija);
  }

  void _onTextSubmit(String text) {
    if (text.trim().isEmpty) return;
    _textCtrl.clear();
    _sendResponse(text.trim());
  }

  Future<void> _startListening() async {
    if (_loading || _listening) return;
    setState(() { _listening = true; _sttLiveText = 'جارٍ التسجيل...'; });
    _accumulatedText = '';

    bool hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) setState(() => _listening = false);
      _addMsg(false, text: 'تعذر الوصول إلى الميكروفون. تحقق من الإذن');
      if (!_muted) _speak('تعذر الوصول إلى الميكروفون');
      return;
    }

    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: _recordingPath!);
      if (mounted) setState(() => _sttLiveText = 'تسجيل... اضغط للإيقاف');
    } catch (e) {
      debugPrint('Record start error: $e');
      if (mounted) setState(() => _listening = false);
      _addMsg(false, text: 'خطأ في التسجيل. استعمل الكتابة');
      if (!_muted) _speak('خطأ في التسجيل');
    }
  }

  Future<void> _stopListening() async {
    final path = _recordingPath;
    _recordingPath = null;
    if (path != null) {
      try { await _audioRecorder.stop(); } catch (_) {}
      if (mounted) setState(() => _sttLiveText = 'Transcription...');
      if (File(path).existsSync()) {
        // Try backend Whisper first
        bool transcribed = await _uploadAndTranscribe(path);
        if (!transcribed) {
          _addMsg(false, text: 'خدمة التعرف على الصوت غير متوفرة. استعمل الكتابة من فضلك');
          if (!_muted) _speak('خدمة التعرف غير متوفرة. استعمل الكتابة');
        }
      }
      // Cleanup
      try { File(path).deleteSync(); } catch (_) {}
    }
    if (mounted) setState(() => _listening = false);
  }

  /// Uploads audio to backend Whisper. Returns true if transcription was successful.
  Future<bool> _uploadAndTranscribe(String path) async {
    try {
      final uri = Uri.parse('${ApiConfig.ttsUrl}/api/stt/transcribe');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('audio', path));
      request.fields['language'] = 'ar';
      final streamedResp = await request.send().timeout(const Duration(seconds: 30));
      final resp = await http.Response.fromStream(streamedResp);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final text = data['text'] as String?;
        final available = data['available'] as bool? ?? false;
        if (text != null && text.isNotEmpty) {
          _sendResponse(text);
          return true;
        }
        if (!available) return false; // Whisper not configured
        // Empty transcription
        return false;
      }
      return false;
    } catch (e) {
      debugPrint('Whisper error: $e');
      return false;
    }
  }

  void _replayAudio() {
    _lastSpoken = '';
    _playQuestionTts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DanoneAppBar(
        title: _state == _State.done ? 'Déclaration terminée'
            : _state == _State.start ? 'Agent IA Vocal'
            : 'Agent IA Vocal',
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _State.start: return _buildStartScreen();
      case _State.session: return _buildSessionScreen();
      case _State.done: return _buildDoneScreen();
    }
  }

  Widget _buildStartScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (!_isOnline)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('Mode hors ligne', style: TextStyle(color: Colors.orange.shade900, fontSize: 13)),
                ],
              ),
            ),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.mic, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 24),
          const Text('Agent IA Vocal',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('التصريح بالدارجة المغربية — 3ammar la déclaration ب صوتك',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _stepRow(Icons.local_shipping, 'Identifier le véhicule'),
                const SizedBox(height: 8),
                _stepRow(Icons.build, 'Décrire le type de panne'),
                const SizedBox(height: 8),
                _stepRow(Icons.shield, 'Indiquer la criticité'),
                const SizedBox(height: 8),
                _stepRow(Icons.location_on, 'Donner le lieu'),
                const SizedBox(height: 8),
                _stepRow(Icons.calendar_today, 'Préciser la date/heure'),
                const SizedBox(height: 8),
                _stepRow(Icons.speed, 'Fournir le kilométrage'),
                const SizedBox(height: 8),
                _stepRow(Icons.check_circle, 'Confirmer et valider'),
              ],
            ),
          ),
          if (_errorMsg != null)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$_errorMsg', style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
            ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : () => _startSession(),
              icon: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.mic),
              label: const Text('بدا التصريح / Commencer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildSessionScreen() {
    return Column(
      children: [
        _buildHeader(),
        if (_pendingConfirmValue != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.speed, size: 20, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('$_pendingConfirmValue كم',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _sendResponse('واخا'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('إرسال / Confirmer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _sendResponse('لا'),
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('كرر / Répéter'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (_extract.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: AppTheme.primary.withOpacity(0.05),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _extract.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 10)),
                    backgroundColor: AppTheme.success.withOpacity(0.1),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                )).toList(),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final m = _messages[i];
              final isUser = m.isUser;
              final isLastAi = !isUser && i == _messages.length - 1;
              final showChoices = isLastAi && _choices.isNotEmpty && _pendingConfirmValue == null;

              return Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.smart_toy, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text('المساعد', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  if (isUser)
                    Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('أنت', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          const SizedBox(width: 4),
                          const Icon(Icons.person, size: 14, color: Colors.green),
                        ],
                      ),
                    ),
                  Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78),
                      decoration: BoxDecoration(
                        color: isUser ? AppTheme.primary : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16).copyWith(
                          bottomRight: isUser ? const Radius.circular(4) : null,
                          bottomLeft: !isUser ? const Radius.circular(4) : null,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.text,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                color: isUser ? Colors.white : AppTheme.textPrimary,
                                fontSize: 15,
                              )),
                          if (m.textFr != null && m.textFr!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(m.textFr!,
                                  style: TextStyle(
                                    color: isUser ? Colors.white70 : Colors.grey.shade600,
                                    fontSize: 12,
                                  )),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (isLastAi && !isUser)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: InkWell(
                        onTap: _replayAudio,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.volume_up, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Text('Replay', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    ),
                  if (showChoices)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 12, left: 4),
                      child: Wrap(
                        spacing: 8, runSpacing: 6,
                        children: _choices.map((c) {
                          return SizedBox(
                            width: (MediaQuery.of(context).size.width - 56) / 2,
                            child: OutlinedButton.icon(
                              onPressed: () => _selectChoice(c),
                              icon: CircleAvatar(
                                radius: 11,
                                backgroundColor: AppTheme.primary,
                                child: Text('${c.id}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                              label: Text(c.labelDarija.isNotEmpty ? c.labelDarija : c.labelFr,
                                  style: const TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 2),
                ],
              );
            },
          ),
        ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(4), child: LinearProgressIndicator()),
        if (_errorMsg != null)
          Container(
            width: double.infinity,
            color: Colors.red.shade50,
            padding: const EdgeInsets.all(8),
            child: Text('$_errorMsg', style: const TextStyle(color: Colors.red, fontSize: 11)),
          ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildHeader() {
    final stepLabel = _currentStepIdx > 1 ? 'Étape ${_currentStepIdx - 1}/${_FIELDS_TO_COLLECT.length}' : 'Démarrage';
    final stepIcon = _STEP_ICONS[_field] ?? Icons.message;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF003DA5), Color(0xFF002776)]),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(stepIcon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Agent IA Vocal',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('$_progressPercent% complété',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  ],
                ),
              ),
              if (_speaking)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.hearing, color: Colors.white70, size: 16),
                ),
              IconButton(
                icon: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _muted = !_muted;
                    if (_muted) _stopTts();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('$_progressPercent%',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progressPercent / 100,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(stepLabel,
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_listening)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: Colors.red.shade50,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  _sttLiveText.isNotEmpty ? _sttLiveText : 'الاستماع... / écoute en cours...',
                  style: TextStyle(color: Colors.red.shade800, fontSize: 13), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  decoration: InputDecoration(
                    hintText: 'Écrivez en Darija...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  onSubmitted: _onTextSubmit,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: _listening ? Colors.red : AppTheme.accent,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _listening ? _stopListening : _startListening,
                  icon: Icon(_listening ? Icons.stop : Icons.mic, color: Colors.white),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _textCtrl.text.isNotEmpty ? () => _onTextSubmit(_textCtrl.text) : null,
                icon: const Icon(Icons.send, color: AppTheme.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoneScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 72, color: AppTheme.success),
            const SizedBox(height: 16),
            const Text('Déclaration terminée!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_summary.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_summary, textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13, height: 1.5)),
              ),
            if (!_isOnline)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_upload, size: 18, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text('En attente de synchronisation',
                        style: TextStyle(color: Colors.orange.shade700, fontSize: 13)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
              child: const Text('العودة إلى الرئيسية'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMsg {
  final bool isUser;
  final String text;
  final String? textFr;
  _ChatMsg({required this.isUser, required this.text, this.textFr});
}

