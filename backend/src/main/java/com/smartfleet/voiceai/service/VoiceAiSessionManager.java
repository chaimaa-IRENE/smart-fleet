package com.smartfleet.voiceai.service;

import com.smartfleet.voiceai.model.VoiceAiSession;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class VoiceAiSessionManager {
    private final Map<String, VoiceAiSession> sessions = new ConcurrentHashMap<>();

    public VoiceAiSession createSession(Integer chauffeurId, String chauffeurNom) {
        VoiceAiSession session = new VoiceAiSession(chauffeurId, chauffeurNom);
        sessions.put(session.getSessionId(), session);
        return session;
    }

    public VoiceAiSession getSession(String sessionId) {
        return sessions.get(sessionId);
    }

    public void removeSession(String sessionId) {
        sessions.remove(sessionId);
    }

    public int getActiveSessionCount() {
        return sessions.size();
    }
}
