package com.smartfleet.voiceai.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.reactive.function.BodyInserters;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

@Service
public class WhisperService {

    private final WebClient webClient;
    private final ObjectMapper objectMapper;
    private final String apiKey;

    public WhisperService(
            @Value("${openai.api.key:}") String apiKey,
            @Value("${openai.endpoint:https://api.openai.com/v1}") String endpoint) {
        this.apiKey = apiKey;
        this.objectMapper = new ObjectMapper();

        String baseUrl = endpoint;
        if (endpoint.contains("/chat/completions")) {
            baseUrl = endpoint.substring(0, endpoint.indexOf("/chat/completions"));
        }

        if (apiKey != null && !apiKey.isEmpty()) {
            this.webClient = WebClient.builder()
                    .baseUrl(baseUrl)
                    .defaultHeader("Authorization", "Bearer " + apiKey)
                    .build();
        } else {
            this.webClient = null;
        }
    }

    public Mono<String> transcribe(byte[] audioData, String fileName, String language) {
        if (webClient == null) {
            return Mono.just("");
        }

        if (language == null || language.isBlank()) {
            language = "ar";
        }

        try {
            MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
            body.add("file", new ByteArrayResource(audioData) {
                @Override
                public String getFilename() {
                    return fileName != null ? fileName : "audio.wav";
                }
            });
            body.add("model", "whisper-1");
            body.add("language", language);
            body.add("response_format", "json");

            return webClient.post()
                    .uri("/audio/transcriptions")
                    .contentType(MediaType.MULTIPART_FORM_DATA)
                    .body(BodyInserters.fromMultipartData(body))
                    .retrieve()
                    .bodyToMono(String.class)
                    .map(this::parseTranscription)
                    .onErrorResume(e -> Mono.just(""));
        } catch (Exception e) {
            return Mono.just("");
        }
    }

    private String parseTranscription(String json) {
        try {
            JsonNode root = objectMapper.readTree(json);
            return root.path("text").asText("");
        } catch (Exception e) {
            return "";
        }
    }

    public boolean isAvailable() {
        return webClient != null && apiKey != null && !apiKey.isEmpty();
    }
}
