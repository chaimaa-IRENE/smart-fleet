package com.smartfleet.voiceai.dto;

import java.util.List;
import java.util.Map;

public class VoiceAiRequest {
    private List<Map<String, String>> messages;
    private Map<String, String> extract;

    public List<Map<String, String>> getMessages() { return messages; }
    public void setMessages(List<Map<String, String>> messages) { this.messages = messages; }
    public Map<String, String> getExtract() { return extract; }
    public void setExtract(Map<String, String> extract) { this.extract = extract; }
}
