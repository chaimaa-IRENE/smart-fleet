package com.smartfleet.voiceai.controller;

import com.smartfleet.voiceai.service.WhisperService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;

@RestController
@RequestMapping("/api/stt")
public class SttController {

    private final WhisperService whisperService;

    public SttController(WhisperService whisperService) {
        this.whisperService = whisperService;
    }

    @PostMapping("/transcribe")
    public ResponseEntity<Map<String, Object>> transcribe(
            @RequestParam("audio") MultipartFile audioFile,
            @RequestParam(value = "language", defaultValue = "ar") String language) {

        if (!whisperService.isAvailable()) {
            return ResponseEntity.ok(Map.of(
                "text", "",
                "available", false,
                "message", "Whisper API non configuré"
            ));
        }

        try {
            byte[] audioBytes = audioFile.getBytes();
            String fileName = audioFile.getOriginalFilename();
            if (fileName == null || fileName.isBlank()) {
                fileName = "audio.wav";
            }

            String transcription = whisperService.transcribe(audioBytes, fileName, language).block();

            if (transcription == null || transcription.isBlank()) {
                return ResponseEntity.ok(Map.of(
                    "text", "",
                    "available", true,
                    "message", "Transcription vide"
                ));
            }

            return ResponseEntity.ok(Map.of(
                "text", transcription,
                "available", true,
                "message", "OK"
            ));
        } catch (IOException e) {
            return ResponseEntity.badRequest().body(Map.of(
                "text", "",
                "available", false,
                "message", "Erreur lecture fichier: " + e.getMessage()
            ));
        }
    }

    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> status() {
        return ResponseEntity.ok(Map.of(
            "available", whisperService.isAvailable()
        ));
    }
}
