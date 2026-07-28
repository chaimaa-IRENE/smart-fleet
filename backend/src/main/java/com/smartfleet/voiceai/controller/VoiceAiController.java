package com.smartfleet.voiceai.controller;

import com.smartfleet.voiceai.dto.VoiceAiRequest;
import com.smartfleet.voiceai.dto.VoiceAiResponse;
import com.smartfleet.voiceai.model.VoiceAiSession;
import com.smartfleet.voiceai.service.VoiceAiService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/voice-ai")
public class VoiceAiController {

    private final VoiceAiService voiceAiService;

    public VoiceAiController(VoiceAiService voiceAiService) {
        this.voiceAiService = voiceAiService;
    }

    @PostMapping("/chat")
    public ResponseEntity<VoiceAiResponse> chat(@RequestBody VoiceAiRequest request) {
        VoiceAiResponse response = voiceAiService.processVoiceChat(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/correct")
    public ResponseEntity<Map<String, String>> correctTranscription(@RequestBody Map<String, String> body) {
        String text = body.getOrDefault("text", "");
        String language = body.getOrDefault("language", "ar");

        if (text.isBlank()) {
            return ResponseEntity.ok(Map.of("corrected", "", "original", ""));
        }

        // Use LLM to correct darija transcription if available
        // Otherwise return original
        String corrected = text;

        // If OpenAI is available, enhance the transcription
        if (true) { // Simplified: always return original for now
            // In production: call GPT with "Correct this darija transcription: [text]"
        }

        return ResponseEntity.ok(Map.of(
            "corrected", corrected,
            "original", text
        ));
    }

    @PostMapping("/start")
    public ResponseEntity<Map<String, Object>> startSession(@RequestBody Map<String, Object> body) {
        Integer chauffeurId = body.get("chauffeurId") instanceof Integer
                ? (Integer) body.get("chauffeurId") : null;
        String chauffeurNom = (String) body.getOrDefault("chauffeurNom", "Chauffeur");

        VoiceAiSession session = voiceAiService.startSession(chauffeurId, chauffeurNom);

        Map<String, Object> result = new java.util.HashMap<>();
        result.put("sessionId", session.getSessionId());
        String[] premiumGreetings = {
            "سلام عليكم! أنا المساعد الصوتي ديال SmartFleet. كيف داير؟ واش كاين شي مشكل؟",
            "وعليكم السلام! أنا هنا باش نعاونك. كي داير؟",
            "أهلا بيك فSmartFleet! أنا المساعد الصوتي ديالك. حكيني بالدارجة شنو وقع."
        };
        result.put("greeting", session.getMessages().size() > 1
                ? session.getMessages().get(1).get("content")
                : premiumGreetings[new java.util.Random().nextInt(premiumGreetings.length)]);
        result.put("chauffeurNom", session.getChauffeurNom());
        return ResponseEntity.ok(result);
    }

    @PostMapping("/respond")
    public ResponseEntity<VoiceAiResponse> respond(@RequestBody Map<String, Object> body) {
        String sessionId = (String) body.get("sessionId");
        String response = (String) body.get("response");

        if (sessionId == null || response == null) {
            VoiceAiResponse error = new VoiceAiResponse();
            error.setResponse("بيانات غير صالحة");
            return ResponseEntity.badRequest().body(error);
        }

        VoiceAiResponse aiResponse = voiceAiService.processSessionMessage(sessionId, response);
        return ResponseEntity.ok(aiResponse);
    }
}
