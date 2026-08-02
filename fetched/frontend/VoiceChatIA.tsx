import React, { useState, useRef, useEffect, useCallback } from "react";
import axios from "axios";

interface VoiceChatIAProps {
  currentUser?: { name?: string; ville?: string } | null;
  locationCity?: string;
  latitude?: number | null;
  longitude?: number | null;
  onAnalyse?: (result: Record<string, string>) => void;
}

interface ChatMsg {
  type: "ai" | "user";
  textDarija: string;
  textFr?: string;
}

interface ChatResponse {
  sessionId: string;
  questionDarija: string;
  questionFrancais: string;
  field: string;
  done: boolean;
  rapportJson: string;
  success: boolean;
  erreur: string;
}

const synth = typeof window !== "undefined" ? window.speechSynthesis : null;
const Recognition =
  (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;

/** Darija marocaine en priorité pour la reconnaissance vocale */
const STT_LOCALES = ["ar-MA", "ar", "fr-FR", "fr"];

/** Corrige erreurs STT courantes (casa entendu comme gazelle) */
function normalizeTranscript(text: string, field: string): string {
  let t = text.trim();
  const loc = field === "localisation" || field === "ville" || field === "location";
  if (loc) {
    t = t.replace(/\b(gazelle|gaselle|gazel|gazell|gazal)\b/gi, "casa");
    t = t.replace(/\b(kaza|kasa|caza|qasa)\b/gi, "casa");
    t = t.replace(/\bkazablanka\b/gi, "casablanca");
  }
  return t;
}

const MSG = {
  welcome:
    "\u0627\u0644\u0633\u0644\u0627\u0645 \u0639\u0644\u064A\u0643\u0645! \u0623\u0646\u0627 \u0645\u0633\u0627\u0639\u062F\u0643 \u0628\u0627\u0644\u062F\u0627\u0631\u062C\u0629. \u063A\u0627\u062F\u064A \u0646\u0633\u0648\u0644\u0643 \u0634\u0648\u064A\u0629 \u0623\u0633\u0626\u0644\u0629 \u0628\u0627\u0644\u0635\u0648\u062A\u060C \u0648\u062C\u0627\u0648\u0628\u0646\u064A \u0628\u0627\u0644\u062F\u0627\u0631\u062C\u0629. \u0646\u0628\u062F\u0627\u0648\u061f",
  done: "\u062A\u0645\u0627\u0645 \u062E\u0648\u064A\u0627! \u0627\u0644\u062A\u0642\u0631\u064A\u0631 \u062C\u0627\u0647\u0632. \u0636\u063A\u0637 \u0639\u0644\u0649 \u0627\u0644\u0632\u0631 \u0627\u0644\u0623\u062E\u0636\u0631 \u0628\u0627\u0634 \u0646\u0639\u0645\u0631\u0648 \u0627\u0644\u0627\u0633\u062A\u0645\u0627\u0631\u0629.",
  listening: "\u0643\u0646\u0633\u0645\u0639\u0643... \u0647\u0636\u0631 \u062F\u0627\u0628\u0627.",
  errorMic: "\u0627\u0644\u0645\u064A\u0643\u0631\u0648 \u0645\u0627 \u062E\u062F\u0627\u0645\u0634. \u0639\u0637\u064A \u0627\u0644\u0625\u0630\u0646 \u062F\u064A\u0627\u0644 \u0627\u0644\u0645\u064A\u0643\u0631\u0648 \u0641\u0627\u0644\u0625\u0639\u062F\u0627\u062F\u0627\u062A.",
  errorNet: "\u0645\u0634\u0643\u0644 \u0641\u0627\u0644\u0627\u062A\u0635\u0627\u0644. \u0639\u0627\u0648\u062F \u0645\u0646 \u0628\u0639\u062F.",
};

let arVoice: SpeechSynthesisVoice | null = null;

function loadVoices() {
  if (!synth) return;
  const voices = synth.getVoices();
  arVoice =
    voices.find((v) => v.lang === "ar-MA") ||
    voices.find((v) => v.lang.startsWith("ar")) ||
    voices.find((v) => v.name.toLowerCase().includes("arabic")) ||
    null;
}

if (synth) {
  loadVoices();
  synth.addEventListener("voiceschanged", loadVoices);
}

/** Parle en darija — voix arabe marocaine si disponible */
async function parlerDarija(texte: string): Promise<void> {
  if (!synth || !texte.trim()) return;
  try {
    synth.cancel();
  } catch {
    /* ignore */
  }

  return new Promise((resolve) => {
    const u = new SpeechSynthesisUtterance(texte);
    u.lang = "ar-MA";
    u.rate = 0.82;
    u.pitch = 1;
    u.volume = 1;
    if (arVoice) u.voice = arVoice;
    u.onend = () => resolve();
    u.onerror = () => resolve();
    try {
      synth.speak(u);
    } catch {
      resolve();
    }
  });
}

const VoiceChatIA: React.FC<VoiceChatIAProps> = ({
  currentUser,
  locationCity,
  latitude,
  longitude,
  onAnalyse,
}) => {
  const [sessionId, setSessionId] = useState("");
  const [messages, setMessages] = useState<ChatMsg[]>([]);
  const [loading, setLoading] = useState(false);
  const [listening, setListening] = useState(false);
  const [speaking, setSpeaking] = useState(false);
  const [done, setDone] = useState(false);
  const [rapport, setRapport] = useState<Record<string, string> | null>(null);
  const [error, setError] = useState("");
  const [started, setStarted] = useState(false);
  const [waitingForInput, setWaitingForInput] = useState(false);
  const [micSupported] = useState(() => !!Recognition);

  const messagesEndRef = useRef<HTMLDivElement>(null);
  const recognitionRef = useRef<any>(null);
  const localeIdxRef = useRef(0);
  const sendMessageRef = useRef<(text: string) => void>(() => {});
  const startListeningRef = useRef<() => void>(() => {});
  const autoListenRef = useRef(true);
  const currentFieldRef = useRef("");

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const gpsContext = (): string => {
    if (locationCity && locationCity !== "MANUEL") return locationCity;
    if (latitude != null && longitude != null) return `${latitude},${longitude}`;
    return currentUser?.ville || "";
  };

  const speakAndMaybeListen = useCallback(
    async (darija: string, autoListen: boolean) => {
      setSpeaking(true);
      await parlerDarija(darija);
      setSpeaking(false);
      if (autoListen && autoListenRef.current && micSupported && !done) {
        setTimeout(() => startListeningRef.current(), 600);
      }
    },
    [micSupported, done]
  );

  const processBackendResponse = useCallback(
    async (data: ChatResponse) => {
      if (!data.success) {
        setError(data.erreur || "Erreur");
        setLoading(false);
        await parlerDarija(MSG.errorNet);
        return;
      }

      if (data.sessionId) setSessionId(data.sessionId);

      if (data.done && data.rapportJson) {
        const parsed = JSON.parse(data.rapportJson);
        setRapport(parsed);
        setDone(true);
        setLoading(false);
        setWaitingForInput(false);
        setMessages((prev) => [
          ...prev,
          {
            type: "ai",
            textDarija: MSG.done,
            textFr: "Rapport termin\u00e9.",
          },
        ]);
        await speakAndMaybeListen(MSG.done, false);
        return;
      }

      const qDarija = data.questionDarija || "";
      const qFr = data.questionFrancais || "";
      currentFieldRef.current = data.field || "";
      setMessages((prev) => [...prev, { type: "ai", textDarija: qDarija, textFr: qFr }]);
      setLoading(false);
      setWaitingForInput(true);
      await speakAndMaybeListen(qDarija, true);
    },
    [speakAndMaybeListen]
  );

  const sendMessage = useCallback(
    async (text: string) => {
      if (loading) return;
      const field = currentFieldRef.current;
      const trimmed = normalizeTranscript(text.trim(), field);
      setLoading(true);
      setError("");
      setWaitingForInput(false);

      if (trimmed) {
        setMessages((prev) => [...prev, { type: "user", textDarija: trimmed }]);
      }

      try {
        const res = await axios.post<ChatResponse>(
          "http://localhost:8080/api/voice-chat/message",
          { message: trimmed, sessionId, currentField: field },
          {
            headers: {
              "X-User-Name": currentUser?.name || "",
              "X-User-Location": gpsContext(),
              "X-Current-Field": field,
            },
          }
        );
        await processBackendResponse(res.data);
      } catch {
        setError("\u0645\u0634\u0643\u0644 \u0641\u0627\u0644\u0627\u062A\u0635\u0627\u0644");
        setLoading(false);
        await parlerDarija(MSG.errorNet);
      }
    },
    [sessionId, loading, currentUser, locationCity, latitude, longitude, processBackendResponse]
  );

  sendMessageRef.current = sendMessage;

  const startListening = useCallback(() => {
    if (!Recognition || listening || loading || speaking) return;

    setListening(true);
    setError("");
    parlerDarija(MSG.listening);

    const recognizer = new Recognition();
    recognizer.continuous = false;
    recognizer.interimResults = false;
    recognizer.maxAlternatives = 5;
    recognizer.lang = STT_LOCALES[localeIdxRef.current % STT_LOCALES.length];

    recognizer.onresult = (event: any) => {
      setListening(false);
      localeIdxRef.current = 0;
      let best = "";
      let bestConf = 0;
      for (let i = 0; i < event.results.length; i++) {
        for (let j = 0; j < event.results[i].length; j++) {
          const conf = event.results[i][j].confidence || 0.5;
          if (conf >= bestConf) {
            bestConf = conf;
            best = event.results[i][j].transcript;
          }
        }
      }
      const t = (best || event.results[0][0].transcript || "").trim();
      if (t) sendMessageRef.current(t);
    };

    recognizer.onerror = (event: any) => {
      if (event.error === "no-speech") {
        localeIdxRef.current++;
        if (localeIdxRef.current < STT_LOCALES.length) {
          setListening(false);
          setTimeout(() => startListeningRef.current(), 400);
          return;
        }
        parlerDarija("\u0645\u0627 \u0633\u0645\u0639\u062A \u0648\u0627\u0644\u0648. \u0639\u0627\u0648\u062F \u0647\u0636\u0631 \u0645\u0646 \u0641\u0636\u0644\u0643.");
      } else if (event.error === "not-allowed") {
        setError("\u0627\u0644\u0645\u064A\u0643\u0631\u0648 \u0645\u062D\u0638\u0648\u0631");
        parlerDarija(MSG.errorMic);
      }
      setListening(false);
      localeIdxRef.current = 0;
    };

    recognizer.onend = () => setListening(false);

    try {
      recognizer.start();
      recognitionRef.current = recognizer;
    } catch {
      setListening(false);
      parlerDarija(MSG.errorMic);
    }
  }, [listening, loading, speaking]);

  startListeningRef.current = startListening;

  const stopListening = () => {
    try {
      recognitionRef.current?.stop();
    } catch {
      /* ignore */
    }
    setListening(false);
  };

  const startConversation = async () => {
    setStarted(true);
    setMessages([]);
    setDone(false);
    setRapport(null);
    setSessionId("");
    setWaitingForInput(false);
    localeIdxRef.current = 0;
    await parlerDarija(MSG.welcome);
    await sendMessage("");
  };

  const remplirFormulaire = () => {
    if (rapport && onAnalyse) onAnalyse(rapport);
  };

  if (!started) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] space-y-6 p-6">
        <div className="text-7xl" aria-hidden="true">
          🎙️
        </div>
        <div className="text-center space-y-3" dir="rtl" lang="ar">
          <h2 className="text-3xl font-black text-slate-800">{'\u0645\u0633\u0627\u0639\u062F \u0627\u0644\u062F\u0627\u0631\u062C\u0629'}</h2>
          <p className="text-xl text-slate-700 leading-relaxed max-w-md">
            {'\u0643\u0646\u0647\u0636\u0631 \u0645\u0639\u0627\u0643 \u0628\u0627\u0644\u062F\u0627\u0631\u062C\u0629 \u0627\u0644\u0645\u063A\u0631\u0628\u064A\u0629'}
            <br />
            {'\u0648\u0643\u0646\u0641\u0647\u0645 \u062C\u0648\u0627\u0628\u0643 \u0628\u0627\u0644\u0635\u0648\u062A'}
          </p>
        </div>
        <p className="text-sm text-slate-500 text-center">
          Assistant vocal — questions et r\u00e9ponses en Darija
        </p>
        <button
          type="button"
          className="px-14 py-6 bg-blue-600 text-white rounded-full text-2xl font-black shadow-xl hover:bg-blue-700 transition-all"
          onClick={startConversation}
        >
          🎤 {'\u0628\u062F\u0627 / Commencer'}
        </button>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full max-w-lg mx-auto">
      <div className="flex-1 overflow-y-auto space-y-3 p-4">
        {messages.map((msg, i) => (
          <div
            key={i}
            className={`flex ${msg.type === "ai" ? "justify-start" : "justify-end"}`}
          >
            <div
              className={`max-w-[90%] rounded-2xl px-4 py-3 ${
                msg.type === "ai"
                  ? "bg-blue-50 border border-blue-100 rounded-bl-sm"
                  : "bg-green-50 border border-green-100 rounded-br-sm"
              }`}
            >
              {msg.type === "ai" ? (
                <>
                  <span className="text-xs font-bold text-blue-600 block mb-1">
                    🤖 {'\u0627\u0644\u0645\u0633\u0627\u0639\u062F'}
                  </span>
                  <p
                    className="text-lg font-semibold text-slate-900 leading-relaxed"
                    dir="rtl"
                    lang="ar"
                  >
                    {msg.textDarija}
                  </p>
                  {msg.textFr && (
                    <p className="text-xs text-slate-600 dark:text-slate-400 mt-1">{msg.textFr}</p>
                  )}
                </>
              ) : (
                <>
                  <span className="text-xs font-bold text-green-700 block mb-1 text-right">
                    🧑 {'\u0623\u0646\u062A / Ntaya'}
                  </span>
                  <p className="text-base text-slate-800" dir="rtl">
                    {msg.textDarija}
                  </p>
                </>
              )}
            </div>
          </div>
        ))}
        {loading && (
          <div className="flex justify-start">
            <div className="bg-slate-100 text-slate-500 rounded-2xl px-4 py-2 text-sm" dir="rtl">
              ⏳ {'\u0643\u0646\u062D\u0644\u0644...'}
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      {speaking && (
        <div
          className="mx-4 mb-2 px-4 py-2 bg-blue-100 text-blue-800 rounded-xl text-sm font-bold flex items-center gap-2"
          dir="rtl"
        >
          <span className="w-2 h-2 bg-blue-600 rounded-full animate-ping" />
          {'\u0643\u0646\u0647\u0636\u0631 \u0645\u0639\u0627\u0643...'}
        </div>
      )}

      {error && (
        <div className="mx-4 mb-2 px-4 py-3 bg-red-50 text-red-800 rounded-xl text-sm" dir="rtl">
          {error}
        </div>
      )}

      {!done && (
        <div className="border-t bg-white p-4">
          <button
            type="button"
            onClick={listening ? stopListening : startListening}
            disabled={loading || speaking || !micSupported}
            className={`w-full py-6 rounded-2xl text-xl font-black flex flex-col items-center gap-1 transition-all ${
              listening
                ? "bg-red-500 text-white animate-pulse"
                : waitingForInput
                  ? "bg-blue-600 text-white shadow-lg"
                  : "bg-blue-600 text-white"
            } disabled:opacity-50`}
          >
            <span className="text-4xl">{listening ? "🔴" : "🎤"}</span>
            <span dir="rtl">
              {listening ? '\u0643\u0646\u0633\u0645\u0639\u0643...' : waitingForInput ? '\u062C\u0627\u0648\u0628 \u0628\u0627\u0644\u0635\u0648\u062A' : '\u0636\u063A\u0637 \u0647\u0646\u0627'}
            </span>
          </button>
          <p className="text-center text-xs text-slate-600 dark:text-slate-400 mt-2" dir="rtl">
            {'\u0642\u0648\u0644: \u0648\u0627\u062E\u0627\u060C \u0644\u0627\u060C \u0631\u0642\u0645 \u0627\u0644\u0643\u0627\u0645\u064A\u0648\u060C \u0627\u0644\u0645\u062F\u064A\u0646\u0629\u060C \u0627\u0644\u0645\u0634\u0643\u0644...'}
          </p>
        </div>
      )}

      {rapport && (
        <div className="border-t bg-white p-4 space-y-3">
          <p className="text-lg font-bold text-center" dir="rtl">
            ✅ {'\u0627\u0644\u062A\u0642\u0631\u064A\u0631 \u062C\u0627\u0647\u0632'}
          </p>
          <button
            type="button"
            onClick={remplirFormulaire}
            className="w-full py-5 bg-green-600 text-white rounded-2xl text-xl font-black hover:bg-green-700"
          >
            ✅ {'\u0646\u0639\u0645\u0631\u0648 \u0627\u0644\u0627\u0633\u062A\u0645\u0627\u0631\u0629'}
          </button>
        </div>
      )}
    </div>
  );
};

export default VoiceChatIA;
