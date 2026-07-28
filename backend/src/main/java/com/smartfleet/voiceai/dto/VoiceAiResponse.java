package com.smartfleet.voiceai.dto;

import java.util.Map;

public class VoiceAiResponse {
    private String response;
    private Map<String, String> extract;
    private boolean done;
    private boolean confirmed;
    private String summary;

    public VoiceAiResponse() {}

    public VoiceAiResponse(String response, Map<String, String> extract) {
        this.response = response;
        this.extract = extract;
        this.done = false;
        this.confirmed = false;
    }

    public String getResponse() { return response; }
    public void setResponse(String response) { this.response = response; }
    public Map<String, String> getExtract() { return extract; }
    public void setExtract(Map<String, String> extract) { this.extract = extract; }
    public boolean isDone() { return done; }
    public void setDone(boolean done) { this.done = done; }
    public boolean isConfirmed() { return confirmed; }
    public void setConfirmed(boolean confirmed) { this.confirmed = confirmed; }
    public String getSummary() { return summary; }
    public void setSummary(String summary) { this.summary = summary; }
}
