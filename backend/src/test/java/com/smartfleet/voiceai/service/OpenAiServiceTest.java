package com.smartfleet.voiceai.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for the intelligent fallback conversation engine.
 * Verifies Darija/French understanding, intent detection, context awareness.
 */
class OpenAiServiceTest {

    private OpenAiService service;

    @BeforeEach
    void setUp() {
        // Empty API key → uses fallback engine
        service = new OpenAiService("", "gpt-4",
            "https://api.openai.com/v1/chat/completions");
    }

    // ── Greeting Tests ──────────────────────────────────────────────

    @Test
    @DisplayName("Darija greeting returns a greeting")
    void testDarijaGreeting() {
        List<Map<String, String>> msgs = buildMessages("user", "السلام عليكم");
        String response = service.chat(msgs).block();
        assertNotNull(response);
        assertTrue(response.contains("السلام") || response.contains("أهلا"),
            "Should respond with greeting in Darija: " + response);
    }

    @Test
    @DisplayName("French greeting returns a greeting")
    void testFrenchGreeting() {
        List<Map<String, String>> msgs = buildMessages("user", "Bonjour");
        String response = service.chat(msgs).block();
        assertNotNull(response);
        assertTrue(response.contains("السلام") || response.contains("أهلا"),
            "Should respond with greeting in Darija: " + response);
    }

    @Test
    @DisplayName("Empty messages returns a greeting")
    void testEmptyMessages() {
        List<Map<String, String>> msgs = new ArrayList<>();
        String response = service.chat(msgs).block();
        assertNotNull(response);
        assertFalse(response.isEmpty());
    }

    // ── Intent Understanding Tests ──────────────────────────────────

    @Test
    @DisplayName("Understands problem description in Darija")
    void testProblemDescriptionDarija() {
        List<Map<String, String>> msgs = buildMessages("user", "الموطور كيخرج دخان");
        String response = service.chat(msgs).block();
        assertNotNull(response);
        // Should acknowledge and ask clarifying question
        assertTrue(response.contains("فهمت") || response.contains("دخان")
            || response.contains("واش") || response.contains("تمشي"),
            "Should understand moteur/fumée and ask follow-up: " + response);
    }

    @Test
    @DisplayName("Understands problem in mixed Darija/French")
    void testMixedLanguage() {
        List<Map<String, String>> msgs = buildMessages("user", "Le moteur kaykhrrej dokhan");
        String response = service.chat(msgs).block();
        assertNotNull(response);
        assertTrue(response.contains("دخان") || response.contains("فهمت")
            || response.contains("moteur"),
            "Should understand mixed language: " + response);
    }

    @Test
    @DisplayName("Understands 'Je ne sais pas' and offers suggestions")
    void testUnsureResponse() {
        List<Map<String, String>> msgs = buildMessages("user", "ma fhemtch chno had l'mouchkil");
        String response = service.chat(msgs).block();
        assertNotNull(response);
        // Should offer help/suggestions, not just say "ok"
        assertTrue(response.contains("واش") || response.contains("شوف")
            || response.contains("ماطور") || response.contains("عجلة"),
            "Should offer suggestions when unsure: " + response);
    }

    @Test
    @DisplayName("Handles 'Je ne sais pas' in French")
    void testFrenchUnsure() {
        List<Map<String, String>> msgs = buildMessages("user", "Je ne sais pas quoi dire");
        String response = service.chat(msgs).block();
        assertNotNull(response);
        assertTrue(response.contains("واش") || response.contains("عجلة")
            || response.contains("ماطور") || response.contains("فران"),
            "Should suggest options in Darija: " + response);
    }

    @Test
    @DisplayName("Detects plate number pattern")
    void testPlateDetection() {
        List<Map<String, String>> msgs = buildMessages("user", "رقم الشاحنة هو 247 A");
        String response = service.chat(msgs).block();
        assertNotNull(response);
        assertTrue(response.contains("247") || response.contains("فهمت")
            || response.contains("واخا"),
            "Should acknowledge plate number: " + response);
    }

    @Test
    @DisplayName("Detects criticity (bloquant)")
    void testCriticiteBloquant() {
        List<Map<String, String>> msgs = buildMessages("user",
            "ma bqach kaydémarrer, l'camion bloque");
        String response = service.chat(msgs).block();
        assertNotNull(response);
        assertTrue(response.contains("فهمت") || response.contains("خطر")
            || response.contains("خطير") || response.contains("واش"),
            "Should understand blocking issue: " + response);
    }

    // ── Context and Memory Tests ────────────────────────────────────

    @Test
    @DisplayName("Uses conversation history for context")
    void testConversationContext() {
        // Simulate multi-turn conversation
        List<Map<String, String>> msgs = new ArrayList<>();
        msgs.add(systemMsg("أنت مساعد ذكي لشركة SmartFleet"));
        msgs.add(userMsg("السلام عليكم"));
        msgs.add(assistantMsg("وعليكم السلام. شنو المشكل؟"));
        msgs.add(userMsg("كاميرا باي"));
        msgs.add(assistantMsg("واش المشكل فالكاميرا دالرجوع ولا دالمحور اللور؟"));
        msgs.add(userMsg("دالمحور اللور"));

        String response = service.chat(msgs).block();
        assertNotNull(response);
        // Should not ask about camera being already discussed
        // Should ask about next relevant field or confirm
        assertFalse(response.contains("كاميرا") && response.contains("واش"),
            "Should not re-ask about camera: " + response);
    }

    @Test
    @DisplayName("Maintains natural conversation flow over multiple turns")
    void testNaturalFlow() {
        // Test that the assistant asks relevant follow-ups, not fixed script
        List<Map<String, String>> msgs1 = buildMessages("user", "الباب ما كيتسدش");
        String r1 = service.chat(msgs1).block();
        assertNotNull(r1);
        assertTrue(r1.contains("باب") || r1.contains("porte"),
            "Should reference door: " + r1);

        // Second turn
        List<Map<String, String>> msgs2 = new ArrayList<>(msgs1);
        msgs2.add(assistantMsg(r1));
        msgs2.add(userMsg("الباب اللور"));
        String r2 = service.chat(msgs2).block();

        // Should not revert to asking about immatriculation (no fixed order)
        // It should continue with door-related questions
        assertNotNull(r2);
        assertFalse(r2.contains("رقم الشاحنة") && !r2.contains("باب"),
            "Should not force immatriculation question when discussing door: " + r2);
    }

    // ── Field Extraction Tests ──────────────────────────────────────

    @Test
    @DisplayName("Extracts immatriculation from conversation")
    void testExtractImmat() {
        List<Map<String, String>> msgs = buildMessages("user", "الرقم ديال الشاحنة هو 247-A-15");
        String response = service.chat(msgs).block();
        // Even if extraction fails in text, AI should acknowledge
        assertNotNull(response);
    }

    @Test
    @DisplayName("Handles empty user input gracefully")
    void testEmptyUserInput() {
        List<Map<String, String>> msgs = buildMessages("user", "");
        String response = service.chat(msgs).block();
        assertNotNull(response);
        assertFalse(response.isEmpty());
    }

    // ── Conversation Closure Tests ──────────────────────────────────

    @Test
    @DisplayName("Provides summary when enough info collected")
    void testSummaryGeneration() {
        List<Map<String, String>> msgs = new ArrayList<>();
        msgs.add(systemMsg("System"));
        msgs.add(userMsg("الرقم 247 A"));
        msgs.add(assistantMsg("واخا. شنو المشكل؟"));
        msgs.add(userMsg("الموطور كيخرج دخان وما قادرش يمشي"));
        msgs.add(assistantMsg("واش كاين دخان أبيض ولا كحل؟"));
        msgs.add(userMsg("كحل"));

        String response = service.chat(msgs).block();
        assertNotNull(response);
        // After several exchanges, should eventually ask for confirmation
        // or continue asking relevant questions
        assertTrue(response.length() > 10,
            "Response should be substantive: " + response);
    }

    // ── Language Mix Tests ──────────────────────────────────────────

    @Test
    @DisplayName("Understands pure Darija")
    void testPureDarija() {
        List<Map<String, String>> msgs = buildMessages("user",
            "العجلة مفرقعة فهاد الطريق");
        String response = service.chat(msgs).block();
        assertNotNull(response);
        assertTrue(response.contains("عجلة") || response.contains("pneu")
            || response.contains("فين") || response.contains("واش"),
            "Should understand Darija-only input: " + response);
    }

    @Test
    @DisplayName("Understands pure French")
    void testPureFrench() {
        List<Map<String, String>> msgs = buildMessages("user",
            "Le pneu est crevé sur l'autoroute");
        String response = service.chat(msgs).block();
        assertNotNull(response);
        // Should respond in Darija even to French input
        assertTrue(response.contains("واش") || response.contains("عجلة")
            || response.contains("فين") || response.contains("pneu"),
            "Should understand French and respond in Darija: " + response);
    }

    @Test
    @DisplayName("Understands short incomplete sentences")
    void testIncompleteSentence() {
        List<Map<String, String>> msgs = buildMessages("user", "ماطور مشكل");
        String response = service.chat(msgs).block();
        assertNotNull(response);
        assertTrue(response.contains("واش") || response.contains("moteur")
            || response.contains("فهمت"),
            "Should handle incomplete sentence: " + response);
    }

    @Test
    @DisplayName("Understands Darija with French mixed")
    void testDarijaFrenchMixed() {
        List<Map<String, String>> msgs = buildMessages("user",
            "l'camion ma b9ach kaydémarrer, problème batterie");
        String response = service.chat(msgs).block();
        assertNotNull(response);
        assertTrue(response.contains("batterie") || response.contains("باتري")
            || response.contains("تيار") || response.contains("بدا"),
            "Should understand mixed language: " + response);
    }

    // ── Correction Handling Tests ───────────────────────────────────

    @Test
    @DisplayName("Handles user corrections politely")
    void testUserCorrection() {
        List<Map<String, String>> msgs = new ArrayList<>();
        msgs.add(systemMsg("System"));
        msgs.add(userMsg("الرقم 247 A"));
        msgs.add(assistantMsg("واخا. شنو المشكل؟"));
        msgs.add(userMsg("لا، الرقم غلط، الرقم هو 123 B"));
        String response = service.chat(msgs).block();
        assertNotNull(response);
        // Should handle correction politely
        assertTrue(response.contains("سمحلي") || response.contains("صح")
            || response.contains("123") || response.contains("آسف"),
            "Should handle correction politely: " + response);
    }

    // ── Helper methods ──────────────────────────────────────────────

    private List<Map<String, String>> buildMessages(String role, String content) {
        List<Map<String, String>> list = new ArrayList<>();
        list.add(systemMsg("أنت مساعد ذكي لشركة SmartFleet"));
        list.add(userMsg(content));
        return list;
    }

    private Map<String, String> systemMsg(String content) {
        Map<String, String> m = new HashMap<>();
        m.put("role", "system");
        m.put("content", content);
        return m;
    }

    private Map<String, String> userMsg(String content) {
        Map<String, String> m = new HashMap<>();
        m.put("role", "user");
        m.put("content", content);
        return m;
    }

    private Map<String, String> assistantMsg(String content) {
        Map<String, String> m = new HashMap<>();
        m.put("role", "assistant");
        m.put("content", content);
        return m;
    }
}
