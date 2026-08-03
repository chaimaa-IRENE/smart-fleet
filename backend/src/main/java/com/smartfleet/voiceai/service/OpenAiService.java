package com.smartfleet.voiceai.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@Service
public class OpenAiService {

    private final WebClient webClient;
    private final ObjectMapper objectMapper;
    private final String apiKey;
    private final String model;
    private final String endpoint;

    // Premium voice agent: Edge TTS Jamal Neural
    public static final String VOICE_NAME = "Jamal Neural (Edge TTS)";
    public static final String VOICE_LANG = "ar-MA";

    // ── INTENT PATTERNS (darija enrichi) ──────────────────────────
    private static final Map<String, List<String>> INTENT_PATTERNS = new LinkedHashMap<>();
    static {
        INTENT_PATTERNS.put("GREETING", List.of(
            "سلام", "السلام", "صباح", "مساء", "bonjour", "hello", "hi", "salam", "salut"
        ));
        INTENT_PATTERNS.put("THANKS", List.of(
            "شكرا", "merci", "thanks", "thank", "بارك الله", "جزاك", "عاشت"
        ));
        INTENT_PATTERNS.put("CONFIRM", List.of(
            "ايوه", "أيوه", "واخا", "wa5a", "wah", "nah", "aywa", "wi5a", "wiya",
            "oui", "yes", "yep", "iyyeh", "ieh", "iye", "sawa", "s7i7", "sahih",
            "صحيح", "صحة", "good", "ok", "d'accord", "daccord", "تم", "بصح",
            "met2akida", "متأكدة", "متيقن", "sah", "صح", "mzyan", "مزيان", "tam"
        ));
        INTENT_PATTERNS.put("REJECT", List.of(
            "لا", "non", "no", "ماشي", "غلط", "خطأ", "erreur", "faux", "pas ça",
            "machi", "not", "wrong", "haka", "هاد", "ماشي هكا", "hada",
            "ma9adch", "ma9adarch", "ma9darch", "ma9adarch"
        ));
        INTENT_PATTERNS.put("UNSURE", List.of(
            "ما فكرتش", "ما عرفت", "ma fhemtch", "je sais pas", "je ne sais pas",
            "معرفش", "والله ما", "ما نعرف", "mani fahm", "mani fhemt",
            "ma9darch", "مقدرتش", "ماني عارف", "ما عندي فكرة", "واش"
        ));
        INTENT_PATTERNS.put("REPEAT", List.of(
            "عاود", "répète", "répéter", "3awed", "again", "شكون", "شنو",
            "واش", "كيفاش", "أعد", "autre fois", "مليح", "سمعتش",
            "ma fhemtch", "ma fhemt"
        ));
        INTENT_PATTERNS.put("STOP", List.of(
            "بسلامة", "باي", "stop", "سير", "fin", "خلصنا", "هادشي",
            "au revoir", "bye", "نهينا", "سكت", "مبعد"
        ));
        INTENT_PATTERNS.put("PLATE_INFO", List.of(
            "رقم", "immatriculation", "plaque", "matricule", "شاحنة", "camion",
            "تمتة", "tamta"
        ));
        INTENT_PATTERNS.put("LOCATION", List.of(
            "فين", "فاش", "مدينة", "ville", "مكان", "lieu", "منطقة",
            "casa", "الدار", "الرباط", "طنجة", "مراكش", "فاس", "أكادير",
            "هنا", "مغرب"
        ));
    }

    // ── PROBLEM ELEMENTS ──────────────────────────────────────────
    private static final Map<String, List<String>> ELEMENT_PATTERNS = new LinkedHashMap<>();
    static {
        ELEMENT_PATTERNS.put("MOTEUR", List.of(
            "موطور", "ماطور", "moteur", "محرك", "motor", "machine", "tourne",
            "démarre", "kaydémarrer", "kaydar", "dokhan", "دخان", "fumée", "smoke",
            "tapping", "boulon", "رادياتير", "radiateur", "refroidissement",
            "kaytsen", "كاتسن", "t9atta", "تقطع"
        ));
        ELEMENT_PATTERNS.put("FREIN", List.of(
            "فران", "frein", "فرملة", "frain", "brake", "arrêt", "وقف",
            "ما كايد", "kay7bes", "ma kay7besch", "tomatik", "ma9adch yb9a"
        ));
        ELEMENT_PATTERNS.put("PNEU", List.of(
            "عجلة", "pneu", "اطار", "roue", "jante", "tire", "pneus",
            "مفرقعة", "crévé", "percé", "gapé", "نفخ", "karda", "كردة"
        ));
        ELEMENT_PATTERNS.put("BATTERIE", List.of(
            "باتري", "batterie", "battery", "بطارية", "démarre pas", "ma tb9ach",
            "تيار", "courant", "plomb", "alternateur", "kayfrghi"
        ));
        ELEMENT_PATTERNS.put("CAMERA", List.of(
            "كاميرا", "camera", "kamera", "webcam", "cam"
        ));
        ELEMENT_PATTERNS.put("PHARE", List.of(
            "ضو", "phare", "lumière", "light", "éclairage", "lamp",
            "clignotant", "ضوية", "kaytfo", "katfo"
        ));
        ELEMENT_PATTERNS.put("PORTE", List.of(
            "باب", "porte", "door", "bab", "قفل"
        ));
        ELEMENT_PATTERNS.put("CARROSSERIE", List.of(
            "كرسو", "carrosserie", "body", "كابينة", "cabine", "tôle",
            "صدام", "pare-choc", "parechoc", "vitre", "زجاج", "zjaj",
            "mkssr", "مكسور", "مراية", "mraya", "retroviseur"
        ));
        ELEMENT_PATTERNS.put("SIEGE", List.of(
            "كرسي", "siège", "seat", "مقعد"
        ));
        ELEMENT_PATTERNS.put("GPS", List.of(
            "gps", "نافي", "navigation", "maps"
        ));
        ELEMENT_PATTERNS.put("CLIM", List.of(
            "clim", "climatisation", "تكييف", "fraîcheur", "سخان", "chauffage"
        ));
        ELEMENT_PATTERNS.put("SUSPENSION", List.of(
            "تعليق", "suspension", "amorti", "tremble", "نهاز"
        ));
        ELEMENT_PATTERNS.put("ACCIDENT", List.of(
            "accident", "حادس", "ضرب", "choc", "صدم", "jari7", "جريح",
            "blessé", "khatarn"
        ));
    }

    // ── PROBLEM TYPES ─────────────────────────────────────────────
    private static final Map<String, List<String>> PANNE_PATTERNS = new LinkedHashMap<>();
    static {
        PANNE_PATTERNS.put("MECANIQUE", List.of(
            "موطور", "ماطور", "moteur", "محرك", "frein", "فران", "boite", "vitesse",
            "علبة", "embrayage", "clutch", "débrayage", "suspension", "amorti",
            "courroie", "distribution", "joint", "culasse", "t9atta",
            "رادياتير", "radiateur", "maye", "ماء", "zayt", "زيت"
        ));
        PANNE_PATTERNS.put("ELECTRIQUE", List.of(
            "كاميرا", "camera", "باتري", "batterie", "بطارية", "ضو", "phare",
            "lumière", "électricité", "electrique", "تيار", "plomb", "fusible",
            "tableau", "compteur", "démarreur", "alternateur", "kaytfo",
            "lamp", "clignotant"
        ));
        PANNE_PATTERNS.put("PNEUMATIQUE", List.of(
            "عجلة", "pneu", "اطار", "roue", "jante", "tire", "crevé", "نفخ",
            "pression", "gapé", "karda"
        ));
        PANNE_PATTERNS.put("CARROSSERIE", List.of(
            "باب", "porte", "كرسي", "siège", "vitre", "carrosserie", "كرسو",
            "كابينة", "cabine", "tôle", "صدام", "pare-choc", "زجاج", "zjaj",
            "mkssr", "mraya", "retroviseur"
        ));
        PANNE_PATTERNS.put("SECURITE", List.of(
            "أمان", "sécurité", "ceinture", "airbag", "abs",
            "فرملة", "accident", "حادس", "خطر", "khatarn", "jari7"
        ));
        PANNE_PATTERNS.put("CABINE", List.of(
            "cabine", "كابينة", "climatisation", "clim", "تكييف", "siège",
            "كرسي", "تلفون", "tableau"
        ));
    }

    // ── PREMIUM VOICE RESPONSES ───────────────────────────────────
    private static final List<String> GREETINGS = List.of(
        "السلام عليكم! أنا المساعد الصوتي ديال SmartFleet. كيف داير؟ واش كاين شي مشكل؟",
        "وعليكم السلام! أنا هنا باش نعاونك. كي داير؟",
        "أهلا بيك فSmartFleet! أنا المساعد الصوتي ديالك. حكيني بالدارجة شنو وقع."
    );

    private static final List<String> OPENING_QUESTIONS = List.of(
        "شنو رقم الشاحنة؟ وشنو المشكل اللي وقع؟",
        "أعطيني رقم الشاحنة واللي وقع بالضبط؟",
        "شنو رقم السيارة وشنو هاد المشكل؟"
    );

    private static final List<String> ACKNOWLEDGMENTS = List.of(
        "واخا، فهمت عليك.",
        "OK، فاهمك.",
        "واضح. شكرا على التوضيح.",
        "فهمت المشكل. شكرا.",
        "مزيان، وصلات الفكرة."
    );

    private static final List<String> ENCOURAGEMENTS = List.of(
        "غادي نكملو.",
        "مزيان. عندك شي حاجة أخرى تحكيني عليها؟",
        "واخا، هادشي كافي. دابا نشوفو شي حاجة أخرى.",
        "OK، هاد المعلومات مهمة بزاف. شكرا بزاف."
    );

    private static final List<String> PREMIUM_CLOSING = List.of(
        "شكرا بزاف! التصريح ديالك تم بنجاح.",
        "تم التسجيل! شكرا على صبرك.",
        "واخا، كلشي تم بحسن. سلام!"
    );

    // ── FRENCH TRANSLATIONS ───────────────────────────────────────
    private static final Map<String, String> TYPE_FR = new HashMap<>();
    private static final Map<String, String> ELEMENT_FR = new HashMap<>();
    private static final Map<String, String> CRITICITE_FR = new HashMap<>();
    private static final Map<String, String> TYPE_AR = new HashMap<>();
    private static final Map<String, String> CRITICITE_AR = new HashMap<>();
    static {
        TYPE_FR.put("MECANIQUE", "Panne mécanique");
        TYPE_FR.put("ELECTRIQUE", "Panne électrique");
        TYPE_FR.put("PNEUMATIQUE", "Problème pneumatique");
        TYPE_FR.put("CARROSSERIE", "Problème carrosserie");
        TYPE_FR.put("SECURITE", "Problème sécurité");
        TYPE_FR.put("CABINE", "Problème cabine");
        TYPE_FR.put("AUTRE", "Autre");

        ELEMENT_FR.put("MOTEUR", "Moteur");
        ELEMENT_FR.put("FREIN", "Frein");
        ELEMENT_FR.put("PNEU", "Pneu");
        ELEMENT_FR.put("BATTERIE", "Batterie");
        ELEMENT_FR.put("CAMERA", "Caméra");
        ELEMENT_FR.put("PHARE", "Phare");
        ELEMENT_FR.put("PORTE", "Porte");
        ELEMENT_FR.put("CARROSSERIE", "Carrosserie");
        ELEMENT_FR.put("SIEGE", "Siège");
        ELEMENT_FR.put("GPS", "GPS");
        ELEMENT_FR.put("CLIM", "Climatisation");
        ELEMENT_FR.put("SUSPENSION", "Suspension");
        ELEMENT_FR.put("ACCIDENT", "Accident");

        CRITICITE_FR.put("BLOQUANT", "Véhicule bloqué");
        CRITICITE_FR.put("NON_BLOQUANT", "Non bloquant");
        CRITICITE_FR.put("URGENT", "Urgent");
        CRITICITE_FR.put("SECURITE", "Danger sécurité");

        TYPE_AR.put("MECANIQUE", "ميكانيك");
        TYPE_AR.put("ELECTRIQUE", "كهرباء");
        TYPE_AR.put("PNEUMATIQUE", "عجلة");
        TYPE_AR.put("CARROSSERIE", "كرسو");
        TYPE_AR.put("SECURITE", "أمان");
        TYPE_AR.put("CABINE", "كابينة");
        TYPE_AR.put("AUTRE", "آخر");

        CRITICITE_AR.put("BLOQUANT", "خطر على الحركة");
        CRITICITE_AR.put("NON_BLOQUANT", "عادي");
        CRITICITE_AR.put("URGENT", "عاجل");
        CRITICITE_AR.put("SECURITE", "خطير");
    }

    public OpenAiService(
            @Value("${openai.api.key:}") String apiKey,
            @Value("${openai.model:gpt-4}") String model,
            @Value("${openai.endpoint:https://api.openai.com/v1/chat/completions}") String endpoint) {
        this.apiKey = apiKey;
        this.model = model;
        this.endpoint = endpoint;
        this.objectMapper = new ObjectMapper();

        if (apiKey != null && !apiKey.isEmpty()) {
            String baseUrl = endpoint;
            if (endpoint.contains("/chat/completions")) {
                baseUrl = endpoint.substring(0, endpoint.indexOf("/chat/completions"));
            }
            this.webClient = WebClient.builder()
                    .baseUrl(baseUrl)
                    .defaultHeader("Authorization", "Bearer " + apiKey)
                    .defaultHeader("Content-Type", "application/json")
                    .build();
        } else {
            this.webClient = null;
        }
    }

    public Mono<String> chat(List<Map<String, String>> messages) {
        if (webClient != null && apiKey != null && !apiKey.isEmpty()) {
            try {
                Map<String, Object> request = Map.of(
                        "model", model,
                        "messages", messages.stream()
                                .map(m -> Map.of("role", m.get("role"), "content", m.get("content")))
                                .toList(),
                        "temperature", 0.3,
                        "max_tokens", 500
                );
                return webClient.post()
                        .uri("/chat/completions")
                        .bodyValue(request)
                        .retrieve()
                        .bodyToMono(String.class)
                        .map(this::parseResponse)
                        .onErrorResume(e -> Mono.just(fallbackResponse(messages)));
            } catch (Exception e) {
                return Mono.just(fallbackResponse(messages));
            }
        }
        return Mono.just(fallbackResponse(messages));
    }

    private String parseResponse(String json) {
        try {
            JsonNode root = objectMapper.readTree(json);
            return root.path("choices").get(0).path("message").path("content").asText();
        } catch (Exception e) {
            return "عذرا، مشكل في تحليل الرد.";
        }
    }

    // ─────────────────────────────────────────────────────────────
    //  PREMIUM FALLBACK CONVERSATION ENGINE
    // ─────────────────────────────────────────────────────────────

    private String fallbackResponse(List<Map<String, String>> messages) {
        if (messages == null || messages.isEmpty()) {
            return pick(GREETINGS);
        }

        List<String> userMessages = new ArrayList<>();
        List<String> assistantMessages = new ArrayList<>();
        Map<String, String> alreadyCollected = new HashMap<>();

        for (Map<String, String> msg : messages) {
            String role = msg.get("role");
            String content = msg.get("content");
            if ("user".equals(role)) {
                userMessages.add(content != null ? content : "");
            } else if ("assistant".equals(role)) {
                assistantMessages.add(content != null ? content : "");
            }
        }

        if (userMessages.isEmpty()) {
            return pick(GREETINGS);
        }

        String lastUserMsg = userMessages.get(userMessages.size() - 1);
        if (lastUserMsg == null || lastUserMsg.isBlank()) {
            return "واخا؟ واش كاين شي مشكل تحكي عليه؟";
        }

        Intent intent = detectIntent(lastUserMsg);

        String allUserText = String.join(" ", userMessages);
        String allText = allUserText + " " + String.join(" ", assistantMessages);
        alreadyCollected = extractAllFields(allText);

        return generateResponse(intent, lastUserMsg, allUserText, alreadyCollected,
                               userMessages, assistantMessages);
    }

    // ── Intent detection ──────────────────────────────────────────

    enum Intent {
        GREETING, THANKS, CONFIRM, REJECT, UNSURE, REPEAT, STOP,
        PLATE_INFO, LOCATION,
        PROBLEM_DESC, ELEMENT_INFO, CRITICITY_INFO,
        INCOMPLETE, QUESTION_TO_AI, UNKNOWN
    }

    private Intent detectIntent(String msg) {
        if (msg == null || msg.trim().isEmpty()) return Intent.UNKNOWN;
        String lower = msg.trim().toLowerCase();

        if (matchesAny(lower, INTENT_PATTERNS.get("STOP"))) return Intent.STOP;
        if (matchesAny(lower, INTENT_PATTERNS.get("THANKS"))) return Intent.THANKS;
        if (matchesAny(lower, INTENT_PATTERNS.get("UNSURE"))) return Intent.UNSURE;
        if (matchesAny(lower, INTENT_PATTERNS.get("REPEAT"))) return Intent.REPEAT;
        if (matchesAny(lower, INTENT_PATTERNS.get("GREETING"))) return Intent.GREETING;
        if (matchesAny(lower, INTENT_PATTERNS.get("LOCATION"))) return Intent.LOCATION;

        if (containsProblemDescription(lower)) return Intent.PROBLEM_DESC;

        String clean = lower.replaceAll("[^a-zA-Z0-9]", "");
        long digitCount = clean.chars().filter(Character::isDigit).count();
        if (clean.length() >= 4 && clean.length() <= 10
            && digitCount >= 2
            && clean.matches(".*[a-zA-Z].*") && clean.matches(".*\\d.*")) {
            return Intent.PLATE_INFO;
        }
        if (matchesAny(lower, INTENT_PATTERNS.get("PLATE_INFO"))) return Intent.PLATE_INFO;

        for (Map.Entry<String, List<String>> entry : ELEMENT_PATTERNS.entrySet()) {
            if (matchesAny(lower, entry.getValue())) return Intent.ELEMENT_INFO;
        }

        if (matchesAny(lower, INTENT_PATTERNS.get("REJECT"))) return Intent.REJECT;

        if (matchesAny(lower, INTENT_PATTERNS.get("CONFIRM"))) return Intent.CONFIRM;

        if (lower.split("\\s+").length <= 2) return Intent.INCOMPLETE;

        return Intent.UNKNOWN;
    }

    private boolean containsProblemDescription(String lower) {
        if (lower.contains("ما") && (lower.contains("ش") || lower.contains("ch"))) return true;
        if (lower.contains("مكاين")) return true;
        if (lower.contains("bqach") || lower.contains("tb9ach")) return true;
        if (lower.contains("ma") && lower.contains("ch") && lower.length() < 20) return true;

        String[] problemWords = {
            "مشكل", "panne", "عطل", "casse", "ضرب", "خرب", "mrat", "kharab",
            "خطر", "وقعة", "حادس", "accident", "تلف", "blessé", "جرح", "جريح",
            "دخان", "fumée", "smoke", "حريق", "incendie",
            "صوت", "bruit", "noise", "تكتكة",
            "كاين", "kayn", "عندي", "فيه", "katch",
            "تسرب", "fuite", "leak", "قطر", "t9atr",
            "t9atta", "تقطّع", "تقطع", "blocké", "bloque",
            "wa9f", "واقف", "machi kaymchi", "ماشي كيمشي",
            "ma khdemch", "ما خدامش", "ma7bès", "ماحابس",
            "khassar", "خاسر", "chahla", "شاحلة",
            "zabta", "زابطة", "kbira", "كبيرة",
            "crevé", "crever", "tsakket", "تسكيت", "تسكات",
            "kaytsen", "كاتسن", "katfrghi", "mahloul", "مهلول",
            "choc", "صدم", "ضرب", "khatarn",
            "moteur", "motor", "frein", "frain", "pneu",
            "roue", "jante", "batterie", "phare", "clim",
            "ma bqach", "tb9ach", "bqach", "ma9adch", "ma9adarch"
        };
        for (String w : problemWords) {
            if (lower.contains(w)) return true;
        }
        return false;
    }

    private boolean matchesAny(String text, List<String> patterns) {
        if (patterns == null || text == null) return false;
        String lower = text.toLowerCase();
        for (String p : patterns) {
            if (lower.contains(p)) return true;
        }
        return false;
    }

    // ── Field extraction ──────────────────────────────────────────

    public Map<String, String> extractAllFields(String text) {
        Map<String, String> extracted = new HashMap<>();
        if (text == null || text.isBlank()) return extracted;

        String lower = text.toLowerCase();

        String immat = extractImmat(text);
        if (immat != null) extracted.put("immatriculation", immat);

        String typePanne = extractTypePanne(lower);
        if (typePanne != null) extracted.put("typePanne", typePanne);

        String element = extractElement(lower);
        if (element != null) extracted.put("elementVehicule", element);

        String criticite = extractCriticite(lower);
        if (criticite != null) extracted.put("criticite", criticite);

        String lieu = extractLieu(text);
        if (lieu != null) extracted.put("lieu", lieu);

        String categorie = extractCategorie(lower);
        if (categorie != null) extracted.put("categorie", categorie);

        String description = extractDescription(text, lower);
        if (description != null && !description.isBlank()) {
            extracted.put("description", description);
        }

        String km = extractKilometrage(text);
        if (km != null) extracted.put("kilometrage", km);

        return extracted;
    }

    public String extractImmat(String text) {
        String[] words = text.split("\\s+");
        for (String w : words) {
            String clean = w.replaceAll("[^a-zA-Z0-9-]", "");
            if (clean.length() >= 4 && clean.length() <= 10) {
                long digitCount = clean.chars().filter(Character::isDigit).count();
                boolean hasLetter = clean.matches(".*[a-zA-Z].*");
                if (hasLetter && digitCount >= 2) return clean.toUpperCase();
            }
        }
        for (String w : words) {
            String clean = w.replaceAll("[^a-zA-Z0-9\\u0600-\\u06FF]", "");
            if (clean.length() >= 3 && clean.length() <= 12) {
                long digitCount = clean.chars().filter(c -> Character.isDigit(c) || (c >= 0x0660 && c <= 0x0669)).count();
                boolean hasLetter = clean.matches(".*[a-zA-Z].*");
                if (hasLetter && digitCount >= 2) return clean.toUpperCase();
            }
        }
        // Join adjacent tokens ("247 A", "A 247", "123 B"): combine and validate
        for (int i = 0; i < words.length - 1; i++) {
            String a = words[i].replaceAll("[^a-zA-Z0-9]", "");
            String b = words[i + 1].replaceAll("[^a-zA-Z0-9]", "");
            String combined = a + b;
            if (combined.length() >= 4 && combined.length() <= 10) {
                long digitCount = combined.chars().filter(Character::isDigit).count();
                boolean hasLetter = combined.matches(".*[a-zA-Z].*");
                if (hasLetter && digitCount >= 2) return combined.toUpperCase();
            }
        }
        return null;
    }

    private String extractTypePanne(String lower) {
        for (Map.Entry<String, List<String>> entry : PANNE_PATTERNS.entrySet()) {
            if (matchesAny(lower, entry.getValue())) return entry.getKey();
        }
        return null;
    }

    private String extractElement(String lower) {
        String best = null;
        int bestPos = -1;
        for (Map.Entry<String, List<String>> entry : ELEMENT_PATTERNS.entrySet()) {
            for (String p : entry.getValue()) {
                int idx = lower.lastIndexOf(p);
                if (idx > bestPos) {
                    bestPos = idx;
                    best = entry.getKey();
                }
            }
        }
        return best;
    }

    private String extractCriticite(String lower) {
        if (lower.contains("urgent") || lower.contains("عاجل") || lower.contains("urgence")
            || lower.contains("بزاف") || lower.contains("بلا") && lower.contains("وقت")) {
            return "URGENT";
        }
        if (lower.contains("ماقادرش") || lower.contains("ma bqach") || lower.contains("kaydémarrer")
            || lower.contains("démarrer") || lower.contains("كاين")
            || lower.contains("خطر") || lower.contains("danger") || lower.contains("خطير")
            || lower.contains("مشكل") || lower.contains("panne") || lower.contains("حادس")
            || lower.contains("accident") || lower.contains("باغي") && lower.contains("تمشي")
            || lower.contains("ماكاين") && lower.contains("فران")
            || lower.contains("ma9adch") || lower.contains("ma9adarch")) {
            return "BLOQUANT";
        }
        if (lower.contains("أمان") || lower.contains("sécurité") || lower.contains("blesser")
            || lower.contains("جريح") || lower.contains("فرامل") && lower.contains("ما")) {
            return "SECURITE";
        }
        if (lower.contains("قادر") && lower.contains("تمشي")
            || lower.contains("roule") || lower.contains("marche") || lower.contains("شويا")
            || lower.contains("non_bloquant") || lower.contains("ma") && lower.contains("khatarn")
            || lower.contains("بسيط") || lower.contains("صغير") || lower.contains("petit")) {
            return "NON_BLOQUANT";
        }
        return null;
    }

    private String extractLieu(String text) {
        String[] cities = {
            "الدار البيضاء", "Casablanca", "casa", "كازا", "الدار",
            "الرباط", "Rabat", "مراكش", "Marrakech",
            "فاس", "Fès", "Fes", "طنجة", "Tanger",
            "أكادير", "Agadir", "مكناس", "Meknès",
            "وجدة", "Oujda", "القنيطرة", "Kénitra",
            "تطوان", "Tétouan", "تازة", "Taza",
            "الجديدة", "El Jadida", "الصويرة", "Essaouira",
            "آسفي", "Safi", "الناظور", "Nador",
            "خريبكة", "Khouribga", "بني ملال", "Beni Mellal", "bni mellal",
            "سلا", "Salé", "تمارة", "Témara",
            "المحمدية", "Mohammedia", "سيدي قاسم", "Sidi Kacem",
            "العرائش", "Larache", "القصر الكبير", "Ksar El Kebir",
            "تاونات", "Taounate", "الحسيمة", "Al Hoceima",
            "ورزازات", "Ouarzazate", "الرشيدية", "Errachidia",
            "سطات", "Settat", "برشيد", "Berrechid",
            "اليوسفية", "Youssoufia", "أزمور", "Azemmour",
            "النواصر", "Nouaceur", "مديونة", "Médiouna",
            "ابن احمد", "Ben Ahmed", "الفقيه بن صالح", "Fkih Ben Salah",
            "خنيفرة", "Khenifra", "ميدلت", "Midelt", "الريش", "Errachidia"
        };
        String lower = text.toLowerCase();
        for (String city : cities) {
            if (text.contains(city) || lower.contains(city.toLowerCase())) return city;
        }
        return null;
    }

    private String extractCategorie(String lower) {
        for (Map.Entry<String, List<String>> entry : PANNE_PATTERNS.entrySet()) {
            if (matchesAny(lower, entry.getValue())) return entry.getKey();
        }
        return null;
    }

    private String extractKilometrage(String text) {
        String kmPattern = "(\\d{3,7})\\s*(?:km|كلم|كيلومتر|kilom[eè]tre|kms)?";
        java.util.regex.Pattern p = java.util.regex.Pattern.compile(kmPattern, java.util.regex.Pattern.CASE_INSENSITIVE);
        java.util.regex.Matcher m = p.matcher(text);
        if (m.find()) {
            return m.group(1);
        }
        return null;
    }

    private String extractDescription(String allText, String lower) {
        if (lower.contains("دخان") || lower.contains("fumée") || lower.contains("smoke")) {
            int idx = Math.max(0, lower.indexOf("دخان") >= 0 ? lower.indexOf("دخان") : 
                              lower.indexOf("fumée") >= 0 ? lower.indexOf("fumée") : 
                              lower.indexOf("smoke"));
            String context = allText.substring(Math.min(idx, allText.length()));
            if (context.length() > 100) context = context.substring(0, 100) + "...";
            return "Fumée anormale: " + context.trim();
        }
        if (lower.contains("صوت") || lower.contains("bruit") || lower.contains("noise")
            || lower.contains("تكتكة") || lower.contains("toc")) {
            int idx = Math.max(0, lower.indexOf("صوت") >= 0 ? lower.indexOf("صوت") :
                              lower.indexOf("bruit") >= 0 ? lower.indexOf("bruit") : 0);
            String context = allText.substring(Math.min(idx, allText.length()));
            if (context.length() > 100) context = context.substring(0, 100) + "...";
            return "Bruit anormal: " + context.trim();
        }
        if (lower.contains("تسرب") || lower.contains("fuite") || lower.contains("leak")
            || lower.contains("تسكات") || lower.contains("tsakket")) {
            return "Fuite signalée par le chauffeur";
        }
        if (lower.contains("accident") || lower.contains("حادس") || lower.contains("ضرب")
            || lower.contains("choc") || lower.contains("صدم")) {
            String desc = extractDescriptiveText(allText, 120);
            if (desc != null) return "Accident: " + desc;
            return "Accident signalé par le chauffeur";
        }
        String desc = extractDescriptiveText(allText, 100);
        if (desc != null) return desc;
        return null;
    }

    private String extractDescriptiveText(String text, int maxLen) {
        String[] sentences = text.split("[.!?\n]+");
        for (String s : sentences) {
            String trimmed = s.trim();
            if (trimmed.length() > 10 && !trimmed.toLowerCase().contains("سلام")
                && !trimmed.toLowerCase().contains("شكرا")) {
                return trimmed.length() > maxLen ? trimmed.substring(0, maxLen) + "..." : trimmed;
            }
        }
        return null;
    }

    // ── Response generation ───────────────────────────────────────

    private String generateResponse(Intent intent, String lastMsg, String allUserText,
                                     Map<String, String> extract,
                                     List<String> userMsgs, List<String> assistantMsgs) {
        switch (intent) {
            case GREETING: return handleGreeting(extract);
            case THANKS: return handleThanks(extract);
            case CONFIRM: return handleConfirm(extract);
            case REJECT: return handleReject(extract, lastMsg);
            case UNSURE: return handleUnsure(extract);
            case REPEAT: return handleRepeat(assistantMsgs, extract);
            case STOP: return "بسلامة! إذا احتجت شي حاجة، أنا هنا. فهاد خدمتك.";
            case PLATE_INFO: return handlePlateInfo(lastMsg, extract);
            case LOCATION: return handleLocation(lastMsg, extract);
            case PROBLEM_DESC: return handleProblemDesc(lastMsg, extract);
            case ELEMENT_INFO: return handleElementInfo(lastMsg, extract);
            case CRITICITY_INFO: return handleCriticite(lastMsg, extract);
            case INCOMPLETE: return handleIncomplete(lastMsg, extract);
            case QUESTION_TO_AI: return handleQuestion(lastMsg);
            case UNKNOWN:
            default: return handleUnknown(lastMsg, extract);
        }
    }

    private String handleGreeting(Map<String, String> extract) {
        if (extract == null || extract.isEmpty()) {
            return pick(GREETINGS) + " " + pick(OPENING_QUESTIONS);
        }
        return "أهلا! كملنا منين وقفنا. واش عندك شي معلومات أخرى؟";
    }

    private String handleThanks(Map<String, String> extract) {
        if (extract != null && extract.size() >= 6) {
            return "العفو! هادا واجبي. التصريح جاهز. غادي نقراه ليك باش تاكد.";
        }
        return "العفو! هادا واجبي. واش باقي شي حاجة تحكيني عليها؟";
    }

    private String handleConfirm(Map<String, String> extract) {
        if (extract != null && extract.containsKey("immatriculation") && extract.containsKey("description")) {
            return buildSummary(extract);
        }
        String next = getNextNaturalQuestion(extract);
        return "واخا، ولكن باقي شي معلومات محتاجينها. " + next;
    }

    private String handleReject(Map<String, String> extract, String lastMsg) {
        if (extract == null || extract.isEmpty()) {
            return "سمحلي. شنو المشكل بالضبط؟ نبداو من الأول. أعطيني رقم الشاحنة والمشكل.";
        }
        String lower = lastMsg.toLowerCase();
        if (lower.contains("immat") || lower.contains("رقم") || lower.contains("plaqu")
            || lower.contains("شاحنة") || lower.contains("camion")) {
            extract.remove("immatriculation");
            return "آسف. شنو رقم الشاحنة الصحيح؟ شوفو فاللوحة قدام ولا فالسير.";
        }
        if (lower.contains("lieu") || lower.contains("فين") || lower.contains("ville")
            || lower.contains("مكان") || lower.contains("مدينة")) {
            extract.remove("lieu");
            return "واخا. واش من مدينة أنت فيها بالضبط؟";
        }
        if (lower.contains("type") || lower.contains("عطل") || lower.contains("panne")
            || lower.contains("نوع")) {
            extract.remove("typePanne");
            extract.remove("categorie");
            return "شنو نوع العطل؟ ميكانيك، كهرباء، عجلة، ولا شي حاجة أخرى؟";
        }
        if (lower.contains("خطر") || lower.contains("critic") || lower.contains("خطير")) {
            extract.remove("criticite");
            return "واش السيارة قادرة تمشي ولا واقفة؟";
        }
        if (lower.contains("وصف") || lower.contains("description") || lower.contains("chroniq")) {
            extract.remove("description");
            return "واش تقدر توصف ليا المشكل؟ شنو كاتشوف وكاتسمع بالضبط؟";
        }
        return "سمحلي. واش الغلط فهاد المعلومات؟ شنو خاص يتغير؟";
    }

    private String handleUnsure(Map<String, String> extract) {
        if (extract == null || extract.isEmpty()) {
            return "مشكل. شوف الرقم فالكارت ديال السيارة ولا فالسير. كاين غير فالشيخة ولا الضهر.";
        }
        if (!extract.containsKey("typePanne") && !extract.containsKey("elementVehicule")) {
            return "واش المشكل فالماطور، العجلات، الفرانات، ولا شي حاجة أخرى؟";
        }
        if (!extract.containsKey("immatriculation")) {
            return "شوف رقم الشاحنة فالكارت ولا فاللوحة. راه كاين قدام ولا لور.";
        }
        if (!extract.containsKey("lieu")) {
            return "واش انت فالمغرب؟ فاش مدينة تقريبا؟ حتى غير المدينة ولا المنطقة.";
        }
        if (!extract.containsKey("typePanne")) {
            return "واش المشكل فالماطور، العجلات، الفرانات، ولا شي حاجة أخرى؟";
        }
        if (!extract.containsKey("description")) {
            return "واش تقد تحاول توصف شويا شنو كاين؟ حتى غير 'كاين صوت غريب' ولا 'ما كاينش ضو'";
        }
        if (!extract.containsKey("criticite")) {
            return "واش الشاحنة قادرة تمشي ولا واقفة بلا ما تحرك؟";
        }
        return "غادي نحاول نعاونك. واش المشكل فالماطور، العجلات، الفرانات، البطارية، ولا شي حاجة أخرى؟";
    }

    private String handleRepeat(List<String> assistantMsgs, Map<String, String> extract) {
        if (assistantMsgs != null && !assistantMsgs.isEmpty()) {
            String last = assistantMsgs.get(assistantMsgs.size() - 1);
            if (last.length() > 200) {
                return last.substring(0, 200) + "... واش فهمتي؟";
            }
            return last + " واش فهمتي؟";
        }
        return getNextNaturalQuestion(extract);
    }

    private String handlePlateInfo(String msg, Map<String, String> extract) {
        String immat = extractImmat(msg);
        if (immat != null) {
            extract.put("immatriculation", immat);
            String ack = pick(ACKNOWLEDGMENTS);
            String next = getNextNaturalQuestion(extract);
            return ack + " رقم " + immat + ". " + next;
        }
        return "واش تقدر تعطيني الرقم ديال الشاحنة؟ كاين فاللوحة قدام ولا فالسير ديال التمتة.";
    }

    private String handleLocation(String msg, Map<String, String> extract) {
        String lieu = extractLieu(msg);
        if (lieu != null) {
            extract.put("lieu", lieu);
            String ack = pick(ACKNOWLEDGMENTS);
            String next = getNextNaturalQuestion(extract);
            return ack + " فـ " + lieu + ". " + next;
        }
        return "فين راك بالضبط؟ فاش مدينة؟ ولا فاش المنطقة؟";
    }

    private String handleProblemDesc(String msg, Map<String, String> extract) {
        String lower = msg.toLowerCase();

        String element = extractElement(lower);
        if (element != null && !extract.containsKey("elementVehicule")) {
            extract.put("elementVehicule", element);
        }

        String typePanne = extractTypePanne(lower);
        if (typePanne != null && !extract.containsKey("typePanne")) {
            extract.put("typePanne", typePanne);
        }

        if (!extract.containsKey("description")) {
            String desc = extractDescription(msg, lower);
            if (desc != null) extract.put("description", desc);
            else extract.put("description", msg.length() > 100 ? msg.substring(0, 100) : msg);
        }

        String lieu = extractLieu(msg);
        if (lieu != null && !extract.containsKey("lieu")) {
            extract.put("lieu", lieu);
        }

        if (element != null) {
            return generateElementFollowUp(element, extract);
        }

        if (!extract.containsKey("criticite")) {
            return "واش الشاحنة قادرة تمشي ولا لا؟ واش كاين خطر؟";
        }

        String next = getNextNaturalQuestion(extract);
        return pick(ACKNOWLEDGMENTS) + " " + next;
    }

    private String handleElementInfo(String msg, Map<String, String> extract) {
        String lower = msg.toLowerCase();
        String element = extractElement(lower);
        if (element != null && !extract.containsKey("elementVehicule")) {
            extract.put("elementVehicule", element);
        }
        String typePanne = extractTypePanne(lower);
        if (typePanne != null && !extract.containsKey("typePanne")) {
            extract.put("typePanne", typePanne);
        }
        if (element != null) {
            return generateElementFollowUp(element, extract);
        }
        return "واش تقدر توصف ليا شوية شنو المشكل فهاد الجزء؟";
    }

    private String generateElementFollowUp(String element, Map<String, String> extract) {
        switch (element) {
            case "FREIN": return "واضح. المشكل فالفرانات. واش السيارة قادرة توقف ولا لا؟";
            case "MOTEUR": return "واش الماطور كاين فیه دخان؟ واش كايدوي بزاف؟ واش كايطلع صوت غريب؟";
            case "PNEU": return "واش العجلة مفرقعة بالكامل ولا باقي فيها الهوى؟ واش عندك عجلة احتياطية؟";
            case "BATTERIE": return "واش السيارة كاتبدا ولا لا؟ واش كاين تيار فالكهرباء؟";
            case "CAMERA": return "كاميرا دالمحور اللور ولا دالرجوع؟ واش التصوير كايخدم؟";
            case "PHARE": return "الضو قدام ولا لور؟ واش واحد الاتنين ولا واحد فيهم؟";
            case "PORTE": return "واش الباب كايتسد ولا باقي مخلوع؟ واش الزجاج كايخدم؟";
            case "CARROSSERIE": return "واش الضربة كبيرة ولا صغيرة؟ واش كاين شي حاجة مكسورة؟";
            case "SIEGE": return "الكرسي ديال السائق ولا ديال الشنطة؟ واش مخلوع ولا مكسور؟";
            case "GPS": return "واش كايخدم GPS ولا لا؟ واش المشكل فالشاشة ولا فالاتصال؟";
            case "CLIM": return "واش المكيف ما كايدويش ولا كايدوي وما كايبردش؟";
            case "SUSPENSION": return "واش السيارة كاتطربق فالحفر؟ واش كاتحس بيه فالمقود؟";
            case "ACCIDENT": return "واش كاين جريح؟ واش الحادس كبير ولا صغير؟ واش السيارة قادرة تمشي؟";
            default: {
                String next = getNextNaturalQuestion(extract);
                return "واخا فهمت. " + next;
            }
        }
    }

    private String handleCriticite(String msg, Map<String, String> extract) {
        String lower = msg.toLowerCase();
        String crit = extractCriticite(lower);
        if (crit != null) {
            extract.put("criticite", crit);
        }
        String next = getNextNaturalQuestion(extract);
        return pick(ACKNOWLEDGMENTS) + " " + next;
    }

    private String handleIncomplete(String msg, Map<String, String> extract) {
        if (extract == null || extract.isEmpty()) {
            return "واش تقدر تحكيني شويا على المشكل؟ حتى غير 'ماطور' ولا 'عجلة' ولا 'فران'";
        }
        if (msg.length() <= 3) {
            return "سمحلي، ما فهمتش. واش تقدر تعاود ببطء؟";
        }
        Map<String, String> newExtract = extractAllFields(msg);
        if (extract != null) {
            extract.putAll(newExtract);
        }
        if (newExtract.isEmpty()) {
            return "واش قصدك فهادشي اللي قلتي؟ واش تقدر توضح أكثر؟";
        }
        String next = getNextNaturalQuestion(extract);
        return "واخا فهمت. " + next;
    }

    private String handleQuestion(String msg) {
        String lower = msg.toLowerCase();
        if (lower.contains("شنو") || lower.contains("واش") || lower.contains("comment")
            || lower.contains("سؤال") || lower.contains("كيفاش")) {
            if (lower.contains("اسم") || lower.contains("سما") || lower.contains("appel")) {
                return "سما لي المساعد الصوتي ديال SmartFleet. أنا هنا باش نعاونك دير التصريح ديالك.";
            }
            return "أنا مساعد SmartFleet الصوتي. غادي نجميع المعلومات ديال التصريح ونحفظو فالنظام.";
        }
        return getNextNaturalQuestion(extractAllFields(lower));
    }

    private String handleUnknown(String msg, Map<String, String> extract) {
        Map<String, String> newExtract = extractAllFields(msg);
        boolean hasNewInfo = false;
        if (newExtract != null) {
            for (Map.Entry<String, String> e : newExtract.entrySet()) {
                if (extract != null && !extract.containsKey(e.getKey())) {
                    extract.put(e.getKey(), e.getValue());
                    hasNewInfo = true;
                }
            }
        }
        if (hasNewInfo) {
            String next = getNextNaturalQuestion(extract);
            return pick(ACKNOWLEDGMENTS) + " " + next;
        }
        return "سمحلي، ما فهمتش بزاف. واش تقدر تفسر ليا شنو المشكل؟ حتى غير كلمات بسيطة.";
    }

    // ── Natural question sequencing ───────────────────────────────

    private String getNextNaturalQuestion(Map<String, String> extract) {
        if (extract == null || extract.isEmpty()) {
            return pick(OPENING_QUESTIONS);
        }

        boolean hasImmat = extract.containsKey("immatriculation");
        boolean hasType = extract.containsKey("typePanne");
        boolean hasDesc = extract.containsKey("description");
        boolean hasElement = extract.containsKey("elementVehicule");
        boolean hasCriticite = extract.containsKey("criticite");
        boolean hasLieu = extract.containsKey("lieu");

        long filled = extract.size();

        if (hasImmat && hasDesc && hasCriticite && filled >= 5) {
            return buildSummary(extract);
        }

        if (hasImmat && hasDesc && !hasCriticite) {
            return "واش الشاحنة قادرة تمشي ولا لا؟ واش كاين خطر على السلامة؟";
        }

        if (hasImmat && !hasDesc) {
            if (hasElement && hasType) {
                return "وصفلي شنو وقع بالضبط؟ شحال من وقت هاد المشكل؟";
            }
            return "وصفلي شوية شنو المشكل. واش كاين دخان؟ صوت؟ ضو؟ ولا شنو؟";
        }

        if (hasImmat && !hasType && !hasDesc) {
            return "شنو نوع العطل؟ ميكانيك، كهرباء، عجلة، كابينة، ولا شي حاجة أخرى؟";
        }

        if (hasImmat && hasDesc && hasCriticite && !hasLieu) {
            return "فين راك دابا؟ فاش مدينة ولا منطقة؟";
        }

        if (!hasImmat && !hasDesc) {
            return "شنو رقم الشاحنة؟ وشنو المشكل اللي وقع؟";
        }

        if (hasImmat && !hasDesc && !hasElement) {
            return "شنو اللي وقع بالضبط؟ حكيني بالدارجة.";
        }

        if (!hasLieu) return "هذا المكان فين وقع فيه المشكل؟";
        if (!hasCriticite) return "واش هاد المشكل خطير ولا عادي؟ السيارة قادرة تمشي؟";

        return buildSummary(extract);
    }

    // ── Summary generation (Premium) ──────────────────────────────

    private String buildSummary(Map<String, String> extract) {
        StringBuilder sb = new StringBuilder();
        sb.append("خلاصة التصريح:\n");
        if (extract.containsKey("immatriculation")) {
            sb.append("• رقم الشاحنة: ").append(extract.get("immatriculation")).append("\n");
        }
        if (extract.containsKey("typePanne")) {
            sb.append("• نوع العطل: ").append(arType(extract.get("typePanne"))).append("\n");
        }
        if (extract.containsKey("description")) {
            String d = extract.get("description");
            sb.append("• الوصف: ").append(d.length() > 80 ? d.substring(0, 80) + "..." : d).append("\n");
        }
        if (extract.containsKey("elementVehicule")) {
            sb.append("• الجزء المعطوب: ").append(extract.get("elementVehicule")).append("\n");
        }
        if (extract.containsKey("criticite")) {
            sb.append("• الخطورة: ").append(arCriticite(extract.get("criticite"))).append("\n");
        }
        if (extract.containsKey("lieu")) {
            sb.append("• المكان: ").append(extract.get("lieu")).append("\n");
        }
        if (extract.containsKey("kilometrage")) {
            sb.append("• الكيلومترات: ").append(extract.get("kilometrage")).append("\n");
        }
        sb.append("\nواش هاد المعلومات صحيحة؟");

        String summary = sb.toString();
        extract.put("lastSummary", summary);
        return summary;
    }

    // ── Public API for French translation ─────────────────────────

    public String translateSummaryToFrench(Map<String, String> extract) {
        if (extract == null || extract.isEmpty()) return "";
        StringBuilder fr = new StringBuilder();
        fr.append("Rapport de déclaration SmartFleet:\n");
        if (extract.containsKey("immatriculation")) {
            fr.append("• Immatriculation: ").append(extract.get("immatriculation")).append("\n");
        }
        if (extract.containsKey("typePanne")) {
            fr.append("• Type panne: ").append(TYPE_FR.getOrDefault(extract.get("typePanne"), extract.get("typePanne"))).append("\n");
        }
        if (extract.containsKey("description")) {
            fr.append("• Description: ").append(extract.get("description")).append("\n");
        }
        if (extract.containsKey("elementVehicule")) {
            fr.append("• Élément: ").append(ELEMENT_FR.getOrDefault(extract.get("elementVehicule"), extract.get("elementVehicule"))).append("\n");
        }
        if (extract.containsKey("criticite")) {
            fr.append("• Criticité: ").append(CRITICITE_FR.getOrDefault(extract.get("criticite"), extract.get("criticite"))).append("\n");
        }
        if (extract.containsKey("lieu")) {
            fr.append("• Lieu: ").append(extract.get("lieu")).append("\n");
        }
        if (extract.containsKey("kilometrage")) {
            fr.append("• Kilométrage: ").append(extract.get("kilometrage")).append(" km\n");
        }
        fr.append("• Statut: Déclaration confirmée");
        return fr.toString();
    }

    // ── Public static helper for VoiceAiService ──────────────────

    public String getNextNaturalQuestionStatic(Map<String, String> extract) {
        return getNextNaturalQuestion(extract);
    }

    private static final List<String> STATIC_OPENING = List.of(
        "شنو رقم الشاحنة؟ وشنو المشكل اللي وقع؟",
        "أعطيني رقم الشاحنة واللي وقع بالضبط؟",
        "شنو رقم السيارة وشنو هاد المشكل؟"
    );

    // ── Helpers ───────────────────────────────────────────────────

    private String pick(List<String> list) {
        return list.get(new Random().nextInt(list.size()));
    }

    private String arType(String type) {
        return TYPE_AR.getOrDefault(type, type != null ? type : "");
    }

    private String arCriticite(String crit) {
        return CRITICITE_AR.getOrDefault(crit, crit != null ? crit : "");
    }
}
