import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class VoiceAiMessage {
  final String role;
  final String content;
  VoiceAiMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class VoiceAiExtract {
  String? immatriculation;
  String? typePanne;
  String? description;
  String? elementVehicule;
  String? criticite;
  String? lieu;
  String? kilometrage;
  String? date;
  String? heure;
  String? categorie;
  String? priorite;

  VoiceAiExtract();

  factory VoiceAiExtract.fromJson(Map<String, dynamic> json) {
    final e = VoiceAiExtract();
    e.immatriculation = json['immatriculation'] as String?;
    e.typePanne = json['typePanne'] as String?;
    e.description = json['description'] as String?;
    e.elementVehicule = json['elementVehicule'] as String?;
    e.criticite = json['criticite'] as String?;
    e.lieu = json['lieu'] as String?;
    e.kilometrage = json['kilometrage'] as String?;
    e.date = json['date'] as String?;
    e.heure = json['heure'] as String?;
    e.categorie = json['categorie'] as String?;
    e.priorite = json['priorite'] as String?;
    return e;
  }

  Map<String, dynamic> toMap() => {
    if (immatriculation != null) 'immatriculation': immatriculation,
    if (typePanne != null) 'typePanne': typePanne,
    if (description != null) 'description': description,
    if (elementVehicule != null) 'elementVehicule': elementVehicule,
    if (criticite != null) 'criticite': criticite,
    if (lieu != null) 'lieu': lieu,
    if (kilometrage != null) 'kilometrage': kilometrage,
    if (date != null) 'date': date,
    if (heure != null) 'heure': heure,
    if (categorie != null) 'categorie': categorie,
    if (priorite != null) 'priorite': priorite,
  };

  int filledCount() => toMap().length;
}

class VoiceAiResponse {
  final String response;
  final VoiceAiExtract extract;
  final bool done;
  final bool confirmed;
  final String? summary;

  VoiceAiResponse({
    required this.response,
    required this.extract,
    this.done = false,
    this.confirmed = false,
    this.summary,
  });

  factory VoiceAiResponse.fromJson(Map<String, dynamic> json) {
    return VoiceAiResponse(
      response: json['response'] as String? ?? '',
      extract: VoiceAiExtract.fromJson(
        json['extract'] as Map<String, dynamic>? ?? {},
      ),
      done: json['done'] as bool? ?? false,
      confirmed: json['confirmed'] as bool? ?? false,
      summary: json['summary'] as String?,
    );
  }
}

class VoiceAiService {
  final List<VoiceAiMessage> _messages = [];
  VoiceAiExtract _extract = VoiceAiExtract();

   static const String _systemPrompt = '''أنت مساعد ذكي لشركة SmartFleet - Danone Maroc.
مهمتك: مساعدة السائق في التصريح عن حادث أو عطل في الشاحنة بطريقة طبيعية ومحادثة.
تتكلم فقط بالدارجة المغربية.

المعلومات التي تحتاج جمعها (بدون ترتيب إجباري):
- immatriculation (رقم الشاحنة)
- typePanne (نوع العطل)
- description (وصف المشكل)
- elementVehicule (الجزء المعطوب)
- criticite (الخطورة)
- lieu (المكان)
- kilometrage (الكيلومترات)
- catégorie (تصنيف العطل)

قواعد الحوار الطبيعية:
- تحدث كأنك شخص حقيقي، لا تتبع سكربت صارم
- اترك السائق يوجه المحادثة بشكل طبيعي
- إذا أعطى السائق معلومات متعددة، استخرجها كلها دفعة واحدة
- اسأل أسئلة ذكية حسب السياق، ليس حسب ترتيب محدد
- إذا قال "ما عرفتش"، اقترح عليه خيارات
- صحح بلطف إذا كان هناك تناقض
- لا تكرر أبداً سؤال تمت الإجابة عليه
- قبل الحفظ، اقرأ الخلاصة واسأل "واش هاد المعلومات صحيحة؟"
- إذا قال السائق "لا"، صحح المعلومات المطلوبة فقط
- إذا قال "ايوه" أو "واخا"، أنشئ التصريح
- افهم الدارجة + الفرنسية + المزيج بينهما
- افهم حتى الردود الغير كاملة

ملاحظة مهمة: عند ذكر رقم الشاحنة (immatriculation)، لا تقل "شرطة" بين الأحرف والأرقام. مثلا "AA-123-BC" تنطقها "اي اي 123 بي سي" وليس "اي اي شرطة 123 شرطة بي سي".

أمثلة على الفهم الطبيعي:
- "الموطور كيخرج دخان" → moteur, mécanique, problème fumée
- "الباب ما كيتسدش" → carrosserie, porte
- "العجلة مفرقعة" → pneumatique, pneu crevé
- "الفرانات ما خدامينش" → frein, mécanique/sécurité
- "كاين صوت غريب" → bruit anormal
- "Le camion ma bqach kaydémarrer" → panne démarrage, mécanique
- "سمعت تكتكة فالعجلة" → pneu, bruit
- "كاميرا باي" → batterie, électrique''';

  VoiceAiService() {
    _messages.add(VoiceAiMessage(role: 'system', content: _systemPrompt));
  }

  bool get isComplete => _messages
      .where((m) => m.role != 'system')
      .any((m) => m.content.contains('واش هاد المعلومات'));

  Future<VoiceAiResponse> processUserText(String text) async {
    _messages.add(VoiceAiMessage(role: 'user', content: text));

    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/voice-ai/chat'),
            headers: {
              ...ApiConfig.headers,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'messages':
                  _messages.map((m) => m.toJson()).toList(),
              'extract': _extract.toMap(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final aiMsg = data['response'] as String? ?? '';
        final voiceAiResponse = VoiceAiResponse.fromJson(data);

        _messages.add(VoiceAiMessage(role: 'assistant', content: aiMsg));
        _extract = voiceAiResponse.extract;

        return voiceAiResponse;
      }
      return VoiceAiResponse(
        response: 'عذرا، مشكل في الاتصال. الرجاء المحاولة مرة أخرى.',
        extract: _extract,
      );
    } catch (e) {
      return VoiceAiResponse(
        response: 'عذرا، حدث خطأ في الاتصال. تأكد من اتصالك بالإنترنت.',
        extract: _extract,
      );
    }
  }

  Future<void> reset() async {
    _messages.clear();
    _messages.add(VoiceAiMessage(role: 'system', content: _systemPrompt));
    _extract = VoiceAiExtract();
  }

  VoiceAiExtract get currentExtract => _extract;
  List<VoiceAiMessage> get conversation => _messages;

  String getGreeting() {
    final l = [
      "السلام عليكم! أنا المساعد الذكي ديال SmartFleet. كيف داير؟ شنو المشكل اللي وقع؟",
      "السلام عليكم ورحمة الله. أنا هنا باش نعاونك. حكيني بالدارجة شنو اللي صرات؟",
      "أهلا بيك. أنا المساعد الصوتي. واش كاين شي مشكل فالشاحنة؟ حكيني بلا مناسبة.",
    ];
    return l[DateTime.now().millisecondsSinceEpoch % l.length];
  }

  String getPromptForField(String field) {
    final prompts = <String, String>{
      'immatriculation': 'شنو رقم الشاحنة؟',
      'typePanne': 'شنو نوع العطل؟ (ميكانيك، كهرباء، عجلة، كابينة، أمان)',
      'description': 'وصفلي شنو وقع بالضبط؟ (دخان، صوت، ضو، ولا شنو؟)',
      'elementVehicule': 'شنو الجزء المعطوب؟ (موطور، فرانات، عجلة، باتري، ضو، كرسون، باب، كاميرا)',
      'criticite': 'واش السيارة قادرة تمشي ولا لا؟ واش كاين خطر على السلامة؟',
      'lieu': 'فين راك دابا؟ فاش مدينة؟',
      'kilometrage': 'شنو عدد الكيلومترات ديال الشاحنة؟',
    };
    return prompts[field] ?? 'شنو المعلومات الأخرى اللي عندك؟';
  }
}
