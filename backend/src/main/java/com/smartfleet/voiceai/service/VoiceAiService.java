package com.smartfleet.voiceai.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.smartfleet.voiceai.dto.VoiceAiRequest;
import com.smartfleet.voiceai.dto.VoiceAiResponse;
import com.smartfleet.voiceai.model.VoiceAiSession;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class VoiceAiService {

    private final OpenAiService openAiService;
    private final VoiceAiSessionManager sessionManager;
    private final ObjectMapper objectMapper;

    public VoiceAiService(OpenAiService openAiService, VoiceAiSessionManager sessionManager) {
        this.openAiService = openAiService;
        this.sessionManager = sessionManager;
        this.objectMapper = new ObjectMapper();
    }

    public VoiceAiResponse processVoiceChat(VoiceAiRequest request) {
        List<Map<String, String>> messages = request.getMessages();
        Map<String, String> currentExtract = request.getExtract() != null
                ? new HashMap<>(request.getExtract())
                : new HashMap<>();

        String response = openAiService.chat(messages).block();
        if (response == null) {
            response = "عذرا، حدث خطأ. الرجاء المحاولة مرة أخرى.";
        }

        Map<String, String> updatedExtract = extractFields(response, currentExtract, messages);

        String lastUserMsg = messages.stream()
                .filter(m -> "user".equals(m.get("role")))
                .map(m -> m.get("content"))
                .reduce((a, b) -> b)
                .orElse("");
        boolean userConfirmed = isConfirmation(lastUserMsg);

        boolean isDone = response.contains("واش هاد المعلومات صحيحة") || response.contains("تم التصريح")
                || response.contains("شكرا بزاف") || response.contains("خلاصة");
        boolean isConfirmed = userConfirmed && isDone;

        VoiceAiResponse aiResponse = new VoiceAiResponse(response, updatedExtract);
        aiResponse.setDone(isDone);
        aiResponse.setConfirmed(isConfirmed);
        if (isDone && isConfirmed) {
            aiResponse.setSummary(buildSummary(updatedExtract));
            String frenchSummary = openAiService.translateSummaryToFrench(updatedExtract);
            aiResponse.setSummary(frenchSummary);
        }
        return aiResponse;
    }

    public VoiceAiSession startSession(Integer chauffeurId, String chauffeurNom) {
        return sessionManager.createSession(chauffeurId, chauffeurNom);
    }

    public VoiceAiResponse processSessionMessage(String sessionId, String userMessage) {
        VoiceAiSession session = sessionManager.getSession(sessionId);
        if (session == null) {
            VoiceAiResponse error = new VoiceAiResponse();
            error.setResponse("جلسة غير صالحة. الرجاء البدء من جديد.");
            return error;
        }

        session.addMessage("user", userMessage);

        boolean userConfirmed = isConfirmation(userMessage);

        String prevAiResponse = "";
        for (int i = session.getMessages().size() - 2; i >= 0; i--) {
            if ("assistant".equals(session.getMessages().get(i).get("role"))) {
                prevAiResponse = session.getMessages().get(i).get("content");
                break;
            }
        }
        boolean wasAskingConfirmation = prevAiResponse.contains("واش هاد المعلومات صحيحة");

        if (wasAskingConfirmation && userConfirmed) {
            String darijaSummary = buildSummary(session.getExtract());
            String frenchSummary = openAiService.translateSummaryToFrench(session.getExtract());
            String finalMsg = pick(List.of(
                "تم التصريح بنجاح! شكرا بزاف.",
                "واخا! التصريح ديالك تم تسجيله. شكرا على صبرك.",
                "تم! كلشي نشر. شكرا بزاف."
            ));

            VoiceAiResponse doneResponse = new VoiceAiResponse(finalMsg, session.getExtract());
            doneResponse.setDone(true);
            doneResponse.setConfirmed(true);
            doneResponse.setSummary(darijaSummary);
            session.addMessage("assistant", "تم التصريح بنجاح! شكرا بزاف.");
            session.setDone(true);

            // Store French translation + bilingual report
            session.getExtract().put("frenchSummary", frenchSummary);
            session.getExtract().put("darijaSummary", darijaSummary);
            Map<String, Object> metadata = session.getMetadata();
            if (metadata == null) {
                metadata = new HashMap<>();
                session.setMetadata(metadata);
            }
            metadata.put("frenchSummary", frenchSummary);
            metadata.put("voiceQuality", "premium");
            metadata.put("voiceName", OpenAiService.VOICE_NAME);
            metadata.put("voiceLang", OpenAiService.VOICE_LANG);

            return doneResponse;
        }

        if (wasAskingConfirmation && !userConfirmed) {
            String correctionResponse = handleCorrection(session, userMessage);
            session.addMessage("assistant", correctionResponse);
            session.setExtract(extractFields(correctionResponse, session.getExtract(), session.getMessages()));

            VoiceAiResponse response = new VoiceAiResponse(correctionResponse, session.getExtract());
            response.setDone(false);
            response.setConfirmed(false);
            return response;
        }

        String aiResponse = openAiService.chat(session.getMessages()).block();
        if (aiResponse == null) {
            aiResponse = "عذرا، حدث خطأ.";
        }

        session.addMessage("assistant", aiResponse);
        session.setExtract(extractFields(aiResponse, session.getExtract(), session.getMessages()));

        boolean done = aiResponse.contains("واش هاد المعلومات صحيحة") || aiResponse.contains("تم التصريح")
                || aiResponse.contains("شكرا بزاف") || aiResponse.contains("خلاصة");
        boolean confirmed = userConfirmed && done;

        session.setDone(done);

        VoiceAiResponse response = new VoiceAiResponse(aiResponse, session.getExtract());
        response.setDone(done);
        response.setConfirmed(confirmed);
        if (done && confirmed) {
            String darijaSummary = buildSummary(session.getExtract());
            String frenchSummary = openAiService.translateSummaryToFrench(session.getExtract());
            response.setSummary(darijaSummary);
            session.getExtract().put("frenchSummary", frenchSummary);
            session.getExtract().put("darijaSummary", darijaSummary);
        }
        return response;
    }

    private String handleCorrection(VoiceAiSession session, String userMessage) {
        String lower = userMessage.toLowerCase();

        if (lower.contains("ماشي") || lower.contains("لا") || lower.contains("non")
                || lower.contains("غلط") || lower.contains("faux") || lower.contains("erreur")) {

            Map<String, String> extract = session.getExtract();
            if (extract.containsKey("immatriculation")) {
                extract.remove("immatriculation");
                return "سمحلي. شنو رقم الشاحنة الصحيح؟ شوفو فاللوحة قدام.";
            }
            if (extract.containsKey("lieu")) {
                extract.remove("lieu");
                return "واخا. واش من مدينة أنت فيها بالضبط؟";
            }
            if (extract.containsKey("typePanne")) {
                extract.remove("typePanne");
                extract.remove("categorie");
                return "شنو نوع العطل الصحيح؟ ميكانيك، كهرباء، عجلة، ولا شي حاجة أخرى؟";
            }
            if (extract.containsKey("description")) {
                extract.remove("description");
                return "واش تقدر تعاود توصف المشكل؟ حكيني بالدارجة شنو وقع بالضبط.";
            }
            return "سمحلي. شنو الغلط فهاد المعلومات؟";
        }

        // If user just says "t9atta" or another problem word, accept as updated description
        if (lower.contains("t9atta") || lower.contains("تقطع") || lower.contains("kharab")
                || lower.contains("خرب") || lower.contains("panne") || lower.contains("moteur")) {
            session.getExtract().put("description", userMessage.length() > 100
                    ? userMessage.substring(0, 100) : userMessage);
            return "واخا، فهمت التصحيح. " + openAiService.getNextNaturalQuestionStatic(session.getExtract());
        }

        session.getExtract().put("description", userMessage.length() > 100
                ? userMessage.substring(0, 100) : userMessage);
        return "واخا، فهمت التصحيح. " + openAiService.getNextNaturalQuestionStatic(session.getExtract());
    }

    private Map<String, String> extractFields(String aiResponse, Map<String, String> currentExtract,
                                               List<Map<String, String>> messages) {
        Map<String, String> extract = new HashMap<>(currentExtract);

        String allText = aiResponse + "\n" + messages.stream()
                .filter(m -> "user".equals(m.get("role")))
                .map(m -> m.get("content"))
                .reduce((a, b) -> a + " " + b)
                .orElse("");

        String lower = allText.toLowerCase();

        if (!extract.containsKey("immatriculation")) {
            String immat = extractImmat(allText);
            if (immat != null) extract.put("immatriculation", immat);
        }
        if (!extract.containsKey("typePanne")) {
            String type = extractTypePanne(lower);
            if (type != null) extract.put("typePanne", type);
        }
        if (!extract.containsKey("description")) {
            String desc = extractDescription(allText, lower);
            if (desc != null) extract.put("description", desc);
        }
        if (!extract.containsKey("elementVehicule")) {
            String elem = extractElement(lower);
            if (elem != null) extract.put("elementVehicule", elem);
        }
        if (!extract.containsKey("criticite")) {
            String crit = extractCriticite(lower);
            if (crit != null) extract.put("criticite", crit);
        }
        if (!extract.containsKey("lieu")) {
            String lieu = extractLieu(allText);
            if (lieu != null) extract.put("lieu", lieu);
        }
        if (!extract.containsKey("categorie")) {
            String cat = extractCategorie(lower);
            if (cat != null) extract.put("categorie", cat);
        }
        // Always try to extract kilometrage; update if found with explicit suffix (strong signal)
        String km = extractKilometrage(allText);
        if (km != null) {
            boolean hadKm = extract.containsKey("kilometrage");
            boolean hasSuffix = java.util.regex.Pattern.compile("\\d{3,7}\\s*(?:km|كلم|كيلومتر|kilom[eè]tre|kms)", java.util.regex.Pattern.CASE_INSENSITIVE).matcher(allText).find();
            if (!hadKm || hasSuffix) {
                extract.put("kilometrage", km);
            }
        }

        return extract;
    }

    private boolean isConfirmation(String text) {
        if (text == null) return false;
        String lower = text.toLowerCase();
        return lower.contains("ايوه") || lower.contains("أيوه")
                || lower.contains("واخا") || lower.contains("oui") || lower.contains("yes")
                || lower.contains("iyyeh") || lower.contains("sawa") || lower.contains("s7i7")
                || lower.contains("sahih") || lower.contains("bien") || lower.contains("daccord")
                || lower.contains("صحيح") || lower.contains("تمام") || lower.contains("wi5a")
                || lower.contains("nah") || lower.contains("aywa") || lower.contains("sah")
                || lower.contains("صح") || lower.contains("mzyan") || lower.contains("مزيان")
                || lower.contains("tam") || lower.contains("met2akida") || lower.contains("متأكدة");
    }

    private String pick(List<String> list) {
        return list.get(new Random().nextInt(list.size()));
    }

    // ── Extraction helpers ────────────────────────────────────────

    private String extractImmat(String text) {
        String[] words = text.split("\\s+");
        for (String w : words) {
            w = w.replaceAll("[^a-zA-Z0-9]", "");
            long digitCount = w.chars().filter(Character::isDigit).count();
            if (w.length() >= 4 && w.length() <= 10 && w.matches(".*[a-zA-Z].*") && digitCount >= 2) {
                return w.toUpperCase();
            }
        }
        for (String w : words) {
            w = w.replaceAll("[^a-zA-Z0-9\\u0600-\\u06FF]", "");
            if (w.length() >= 3 && w.length() <= 12) {
                long digitCount = w.chars().filter(c -> Character.isDigit(c) || (c >= 0x0660 && c <= 0x0669)).count();
                boolean hasLetter = w.matches(".*[a-zA-Z].*");
                if (hasLetter && digitCount >= 2) return w.toUpperCase();
            }
        }
        return null;
    }

    private String extractTypePanne(String lower) {
        if (lower.contains("موطور") || lower.contains("moteur") || lower.contains("محرك")
                || lower.contains("فران") || lower.contains("frein") || lower.contains("فرملة")
                || lower.contains("boite") || lower.contains("علبة") || lower.contains("vitesse"))
            return "MECANIQUE";
        if (lower.contains("كاميرا") || lower.contains("camera") || lower.contains("باتري")
                || lower.contains("batterie") || lower.contains("ضو") || lower.contains("phare")
                || lower.contains("lumière") || lower.contains("électricité"))
            return "ELECTRIQUE";
        if (lower.contains("عجلة") || lower.contains("pneu") || lower.contains("اطار")
                || lower.contains("roue") || lower.contains("jante"))
            return "PNEUMATIQUE";
        if (lower.contains("باب") || lower.contains("porte") || lower.contains("كرسي")
                || lower.contains("siège") || lower.contains("vitre") || lower.contains("carrosserie")
                || lower.contains("zjaj") || lower.contains("mkssr") || lower.contains("mraya"))
            return "CARROSSERIE";
        if (lower.contains("sécurité") || lower.contains("أمان") || lower.contains("ceinture")
                || lower.contains("airbag") || lower.contains("accident") || lower.contains("حادس"))
            return "SECURITE";
        if (lower.contains("cabine") || lower.contains("كابينة") || lower.contains("climatisation")
                || lower.contains("clim"))
            return "CABINE";
        return "AUTRE";
    }

    private String extractDescription(String allText, String lower) {
        String userMsg = "";
        if (lower.contains("دخان") || lower.contains("fumée") || lower.contains("smoke"))
            userMsg = "Fumée anormale";
        else if (lower.contains("صوت") || lower.contains("bruit") || lower.contains("noise"))
            userMsg = "Bruit anormal";
        else if (lower.contains("كاين") || lower.contains("kayn"))
            userMsg = allText.length() > 100 ? allText.substring(0, 100) : allText;
        else if (lower.contains("مشكل") || lower.contains("probleme")
                || lower.contains("panne") || lower.contains("عطل"))
            userMsg = "Problème signalé par le chauffeur";
        else if (lower.contains("accident") || lower.contains("حادس") || lower.contains("ضرب"))
            userMsg = "Accident signalé par le chauffeur";
        else if (lower.contains("t9atta") || lower.contains("تقطع"))
            userMsg = "Véhicule bloqué: " + (allText.length() > 80 ? allText.substring(0, 80) : allText);
        return userMsg.isEmpty() ? null : userMsg;
    }

    private String extractElement(String lower) {
        if (lower.contains("موطور") || lower.contains("moteur") || lower.contains("محرك")
                || lower.contains("t9atta")) return "MOTEUR";
        if (lower.contains("فران") || lower.contains("frein") || lower.contains("فرملة")) return "FREIN";
        if (lower.contains("عجلة") || lower.contains("pneu") || lower.contains("اطار")) return "PNEU";
        if (lower.contains("كاميرا") || lower.contains("camera")) return "CAMERA";
        if (lower.contains("باتري") || lower.contains("batterie")) return "BATTERIE";
        if (lower.contains("ضو") || lower.contains("phare") || lower.contains("lumière")) return "PHARE";
        if (lower.contains("باب") || lower.contains("porte")) return "PORTE";
        if (lower.contains("كرسي") || lower.contains("siège")) return "SIEGE";
        if (lower.contains("zjaj") || lower.contains("mkssr") || lower.contains("mraya")
                || lower.contains("retroviseur") || lower.contains("كرسو")) return "CARROSSERIE";
        return null;
    }

    private String extractCriticite(String lower) {
        if (lower.contains("باغي") || lower.contains("قادر") || lower.contains("تمشي")
                || lower.contains("roule") || lower.contains("marche") || lower.contains("شويا"))
            return "NON_BLOQUANT";
        if (lower.contains("ماقادرش") || lower.contains("ma bqach") || lower.contains("kaydémarrer")
                || lower.contains("démarrer") || lower.contains("khatarn")
                || lower.contains("خطر") || lower.contains("danger")
                || lower.contains("ma9adch") || lower.contains("ma9adarch"))
            return "BLOQUANT";
        if (lower.contains("urgent") || lower.contains("عاجل") || lower.contains("urgence"))
            return "URGENT";
        if (lower.contains("sécurité") || lower.contains("أمان") || lower.contains("blesser")
                || lower.contains("accident") || lower.contains("جريح") || lower.contains("حادس"))
            return "SECURITE";
        return "NON_BLOQUANT";
    }

    private String extractLieu(String text) {
        String[] cities = {"الدار البيضاء", "Casablanca", "الرباط", "Rabat", "مراكش", "Marrakech",
                "فاس", "Fès", "Fes", "طنجة", "Tanger", "أكادير", "Agadir", "مكناس", "Meknès",
                "وجدة", "Oujda", "القنيطرة", "Kénitra", "تطوان", "Tétouan", "تازة", "Taza",
                "الجديدة", "El Jadida", "الصويرة", "Essaouira", "آسفي", "Safi",
                "الناظور", "Nador", "خريبكة", "Khouribga", "بني ملال", "Beni Mellal", "bni mellal",
                "سلا", "Salé", "تمارة", "Témara", "المحمدية", "Mohammedia", "سيدي قاسم", "Sidi Kacem",
                "الدار", "كازا", "casa", "المغرب", "dalam",
                "برشيد", "Berrechid", "سطات", "Settat", "النواصر"};
        String lower = text.toLowerCase();
        for (String city : cities) {
            if (text.contains(city) || lower.contains(city.toLowerCase())) return city;
        }
        return null;
    }

    private String extractKilometrage(String text) {
        // Pattern with explicit km suffix (strong match)
        String withSuffix = "(\\d{3,7})\\s*(?:km|كلم|كيلومتر|kilom[eè]tre|kms)";
        java.util.regex.Pattern p1 = java.util.regex.Pattern.compile(withSuffix, java.util.regex.Pattern.CASE_INSENSITIVE);
        java.util.regex.Matcher m1 = p1.matcher(text);
        if (m1.find()) return m1.group(1);

        // Pattern without suffix: only match 5+ digits to avoid immatriculation false positives
        String noSuffix = "(\\d{5,7})(?:\\s|$|،|,|\\.|\\?|!)";
        java.util.regex.Pattern p2 = java.util.regex.Pattern.compile(noSuffix);
        java.util.regex.Matcher m2 = p2.matcher(text);
        if (m2.find()) return m2.group(1);

        return null;
    }

    private String extractCategorie(String lower) {
        if (lower.contains("موطور") || lower.contains("moteur") || lower.contains("فران")
                || lower.contains("frein") || lower.contains("boite") || lower.contains("vitesse")
                || lower.contains("علبة"))
            return "MECANIQUE";
        if (lower.contains("كاميرا") || lower.contains("camera") || lower.contains("باتري")
                || lower.contains("batterie") || lower.contains("ضو") || lower.contains("phare")
                || lower.contains("électricité"))
            return "ELECTRIQUE";
        if (lower.contains("عجلة") || lower.contains("pneu") || lower.contains("roue"))
            return "PNEUMATIQUE";
        if (lower.contains("باب") || lower.contains("porte") || lower.contains("carrosserie")
                || lower.contains("كرسي") || lower.contains("siège") || lower.contains("vitre")
                || lower.contains("zjaj") || lower.contains("mkssr") || lower.contains("mraya"))
            return "CARROSSERIE";
        if (lower.contains("أمان") || lower.contains("sécurité") || lower.contains("ceinture")
                || lower.contains("accident") || lower.contains("حادس"))
            return "SECURITE";
        return "MECANIQUE";
    }

    private String buildSummary(Map<String, String> extract) {
        StringBuilder sb = new StringBuilder();
        sb.append("خلاصة التصريح:\n");
        extract.forEach((key, value) ->
                sb.append("• ").append(key).append(": ").append(value).append("\n"));
        sb.append("\nشكرا بزاف! التصريح تم بنجاح.");
        return sb.toString();
    }
}
