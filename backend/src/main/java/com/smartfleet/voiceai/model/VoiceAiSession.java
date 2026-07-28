package com.smartfleet.voiceai.model;

import java.time.Instant;
import java.util.*;

public class VoiceAiSession {
    private final String sessionId;
    private final Integer chauffeurId;
    private final String chauffeurNom;
    private final Instant createdAt;
    private final List<Map<String, String>> messages;
    private Map<String, String> extract;
    private boolean done;
    private Map<String, Object> metadata;

    private static final String SYSTEM_PROMPT = """
Vous êtes l'assistant vocal intelligent de SmartFleet - Danone Maroc.
Vous parlez uniquement en darija marocain.
Votre mission est de guider le chauffeur pour déclarer un incident de manière naturelle et conversationnelle.

RÈGLES CONVERSATIONNELLES :
1. Parlez exclusivement en darija marocain naturel
2. Soyez chaleureux, patient, empathique, professionnel
3. Laissez le chauffeur guider la conversation — ne forcez PAS un ordre fixe
4. Si le chauffeur donne plusieurs informations à la fois, extrayez-les toutes
5. Posez des questions pertinentes selon le CONTEXTE, pas un script
6. Reformulez si le chauffeur n'est pas clair
7. Si le chauffeur dit "je ne sais pas", proposez des suggestions
8. Détectez les incohérences et demandez poliment une confirmation
9. Ne répétez JAMAIS une question déjà répondue
10. Avant de finaliser, relisez le résumé et demandez "واش هاد المعلومات صحيحة؟"
11. Si le chauffeur dit "non", corrigez uniquement les champs erronés
12. Comprenez le mélange darija/français, les accents, les hésitations

INFORMATIONS À COLLECTER (dans l'ordre naturel de la conversation) :
- immatriculation (رقم الشاحنة)
- typePanne (نوع العطل: mécanique, électrique, pneumatique, cabine, caisse, sécurité, autre)
- description (وصف المشكل بالتفصيل)
- elementVehicule (الجزء المعطوب: moteur, frein, pneu, batterie, phare, carrosserie, etc.)
- criticite (الخطورة: bloquant, non_bloquant, urgent, critique, sécurité)
- lieu (المكان: مدينة، منطقة)
- kilometrage (الكيلومترات)
- catégorie (تصنيف العطل)

EXEMPLES DE COMPRÉHENSION NATURELLE :
- "الموطور كيخرج دخان" → moteur, fumée, mécanique
- "العجلة مفرقعة" → pneu crevé, pneumatique
- "الفرانات ما خدامينش" → freins défaillants, mécanique/sécurité
- "الباب ما كيتسدش" → porte, carrosserie
- "كاميرا كاميرا باي" → batterie, électrique
- "الضو ما خدامش" → phare, électrique
- "كاين صوت غريب فالمطور" → moteur, bruit, mécanique
- "Le camion ma bqach kaydémarrer" → démarrage, mécanique
- "La porte elle est cassée" → porte, carrosserie
- "سمعت تكتكة فالعجلة" → pneu, bruit
- "الفريون ما كايدويش" → climatisation, cabine

Extraction JSON : renvoyez toujours un objet 'extract' mis à jour avec les champs collectés.
Utilisez 'done: true' quand toutes les informations sont collectées.
Utilisez 'confirmed: true' quand le chauffeur confirme le résumé.
""";

    public VoiceAiSession(Integer chauffeurId, String chauffeurNom) {
        this.sessionId = UUID.randomUUID().toString();
        this.chauffeurId = chauffeurId;
        this.chauffeurNom = chauffeurNom;
        this.createdAt = Instant.now();
        this.messages = new ArrayList<>();
        this.extract = new HashMap<>();
        this.done = false;

        Map<String, String> systemMsg = new HashMap<>();
        systemMsg.put("role", "system");
        systemMsg.put("content", SYSTEM_PROMPT + "\n\nChauffeur: " + (chauffeurNom != null ? chauffeurNom : "Inconnu"));
        messages.add(systemMsg);
    }

    public String getSessionId() { return sessionId; }
    public Integer getChauffeurId() { return chauffeurId; }
    public String getChauffeurNom() { return chauffeurNom; }
    public Instant getCreatedAt() { return createdAt; }
    public List<Map<String, String>> getMessages() { return messages; }
    public Map<String, String> getExtract() { return extract; }
    public void setExtract(Map<String, String> extract) { this.extract = extract; }
    public boolean isDone() { return done; }
    public void setDone(boolean done) { this.done = done; }
    public Map<String, Object> getMetadata() { return metadata; }
    public void setMetadata(Map<String, Object> metadata) { this.metadata = metadata; }

    public void addMessage(String role, String content) {
        Map<String, String> msg = new HashMap<>();
        msg.put("role", role);
        msg.put("content", content);
        messages.add(msg);
    }
}
