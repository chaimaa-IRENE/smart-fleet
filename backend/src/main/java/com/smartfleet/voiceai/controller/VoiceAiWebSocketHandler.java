package com.smartfleet.voiceai.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.smartfleet.voiceai.dto.VoiceAiResponse;
import com.smartfleet.voiceai.model.VoiceAiSession;
import com.smartfleet.voiceai.service.VoiceAiService;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.*;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class VoiceAiWebSocketHandler extends TextWebSocketHandler {

    private final VoiceAiService voiceAiService;
    private final ObjectMapper objectMapper;
    private final Map<String, WebSocketSession> activeSessions = new ConcurrentHashMap<>();
    private final Map<String, String> wsToAiSession = new ConcurrentHashMap<>();

    // Streaming state per session
    private final Map<String, Boolean> streamingStates = new ConcurrentHashMap<>();

    public VoiceAiWebSocketHandler(VoiceAiService voiceAiService) {
        this.voiceAiService = voiceAiService;
        this.objectMapper = new ObjectMapper();
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        activeSessions.put(session.getId(), session);
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws IOException {
        try {
            Map<String, Object> data = objectMapper.readValue(message.getPayload(), Map.class);
            String type = (String) data.getOrDefault("type", "message");

            switch (type) {
                case "start" -> handleStart(session, data);
                case "message" -> handleMessage(session, data);
                case "audio" -> handleAudio(session, data); // New: streaming audio
                case "stop" -> handleStop(session);
                case "ping" -> handlePing(session);
                // case "stream_cancel" -> handleStreamCancel(session); // for barge-in
                default -> sendError(session, "نوع غير معروف");
            }
        } catch (Exception e) {
            sendError(session, "خطأ: " + e.getMessage());
        }
    }

    private void handleStart(WebSocketSession session, Map<String, Object> data) throws IOException {
        Integer chauffeurId = data.get("chauffeurId") instanceof Integer
                ? (Integer) data.get("chauffeurId") : null;
        String chauffeurNom = (String) data.getOrDefault("chauffeurNom", "Chauffeur");

        VoiceAiSession aiSession = voiceAiService.startSession(chauffeurId, chauffeurNom);
        wsToAiSession.put(session.getId(), aiSession.getSessionId());

        Map<String, Object> response = Map.of(
                "type", "greeting",
                "sessionId", aiSession.getSessionId(),
                "text", "السلام عليكم! أنا المساعد الذكي ديال SmartFleet. كيف داير؟ شنو المشكل؟"
        );
        session.sendMessage(new TextMessage(objectMapper.writeValueAsString(response)));
    }

    private void handleMessage(WebSocketSession session, Map<String, Object> data) throws IOException {
        String aiSessionId = wsToAiSession.get(session.getId());
        if (aiSessionId == null) {
            sendError(session, "الرجاء بدء الجلسة أولاً");
            return;
        }

        String userText = (String) data.getOrDefault("text", "");
        VoiceAiResponse response = voiceAiService.processSessionMessage(aiSessionId, userText);

        // Send tokens progressively if streaming
        String fullText = response.getResponse();
        if (fullText != null && fullText.length() > 10) {
            sendStreamingTokens(session, fullText);
        }

        // Send final response
        Map<String, Object> wsResponse = new java.util.HashMap<>();
        wsResponse.put("type", "response");
        wsResponse.put("text", fullText);
        wsResponse.put("extract", response.getExtract());
        wsResponse.put("done", response.isDone());
        wsResponse.put("confirmed", response.isConfirmed());
        wsResponse.put("summary", response.getSummary());

        session.sendMessage(new TextMessage(objectMapper.writeValueAsString(wsResponse)));
    }

    private void handleAudio(WebSocketSession session, Map<String, Object> data) throws IOException {
        // Audio chunk received — currently echoed back
        // In full implementation, this would be sent to Whisper for streaming transcription
        Map<String, Object> response = Map.of(
            "type", "audio_ack",
            "status", "received"
        );
        session.sendMessage(new TextMessage(objectMapper.writeValueAsString(response)));
    }

    private void sendStreamingTokens(WebSocketSession session, String text) throws IOException {
        if (text == null || text.length() < 5) return;

        // Split into tokens (by word for Darija)
        String[] tokens = text.split("(?<=\\s+)");
        StringBuilder accumulated = new StringBuilder();

        for (String token : tokens) {
            accumulated.append(token);

            Map<String, Object> tokenMsg = Map.of(
                "type", "token",
                "text", accumulated.toString(),
                "partial", !accumulated.toString().equals(text)
            );

            session.sendMessage(new TextMessage(objectMapper.writeValueAsString(tokenMsg)));

            // Simulate streaming delay (small)
            try { Thread.sleep(30); } catch (InterruptedException e) { break; }
        }
    }

    private void handlePing(WebSocketSession session) throws IOException {
        Map<String, Object> response = Map.of("type", "pong");
        session.sendMessage(new TextMessage(objectMapper.writeValueAsString(response)));
    }

    private void handleStop(WebSocketSession session) throws IOException {
        String aiSessionId = wsToAiSession.remove(session.getId());
        Map<String, Object> response = Map.of("type", "stopped", "text", "تم إيقاف الجلسة");
        session.sendMessage(new TextMessage(objectMapper.writeValueAsString(response)));
    }

    private void sendError(WebSocketSession session, String message) throws IOException {
        Map<String, Object> error = Map.of("type", "error", "text", message);
        session.sendMessage(new TextMessage(objectMapper.writeValueAsString(error)));
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        activeSessions.remove(session.getId());
        wsToAiSession.remove(session.getId());
        streamingStates.remove(session.getId());
    }
}
