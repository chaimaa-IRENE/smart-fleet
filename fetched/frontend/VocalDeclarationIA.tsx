import React, { useState, useRef, useCallback, useEffect } from "react";
import axios from "axios";

export interface AnomalieIAResult {
  vehicule: string;
  chauffeur: string;
  localisation: string;
  element: string;
  anomalie: string;
  description: string;
  categorie: string;
  criticite: string;
  date: string;
  source: string;
  typePanne?: string;
  success?: boolean;
  erreur?: string;
}

interface VocalDeclarationIAProps {
  currentUser?: { id?: number; name?: string; firstname?: string; ville?: string } | null;
  locationCity?: string;
  latitude?: number | null;
  longitude?: number | null;
  onAnalyse?: (result: AnomalieIAResult) => void;
}

const Recognition =
  (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
const LOCALES = ["ar-MA", "fr-FR", "fr", "ar"];
const synth = typeof window !== "undefined" ? window.speechSynthesis : null;

let bestVoice: SpeechSynthesisVoice | null = null;
if (synth) {
  const pick = () => {
    const vs = synth.getVoices();
    bestVoice =
      vs.find((v) => v.lang.startsWith("ar")) ||
      vs.find((v) => v.lang.startsWith("fr")) ||
      null;
  };
  pick();
  synth.addEventListener("voiceschanged", pick);
}

const MSG = {
  welcome:
    "Salam. Hbes 3la l'micro, w 9ol chno mochkil f camion dyalek: num\u00e9ro camion, chno khayb, fin rak.",
  listening: "Kanssma3... 9ol daba.",
  analysing: "Kan7ellel... sber chwiya.",
  success: (r: AnomalieIAResult) =>
    `Sma7 lia. Camion ${r.vehicule}, mochkil ${r.element}, ${r.anomalie}. Bghiti n3amer l'formulaire? 9ol oui wla wakha.`,
  confirmPrompt: "9ol oui, wakha, wah \u2014 bach n3amer l'formulaire.",
  confirmed: "Mezyan! Formulaire 3amer. Chouf w sir l'envoi.",
  errorMic:
    "Micro ma khdemch. 3tii l'application l'acc\u00e8s dial micro f t\u00e9l\u00e9phone.",
  errorServer: "Mochkil f connexion. 3awed men ba3d.",
  noSpeech: "Ma sme3t walo. 3awed 9ol mochkil dyalek.",
};

async function parler(text: string): Promise<void> {
  if (!synth || !text) return;
  try {
    synth.cancel();
  } catch {
    /* ignore */
  }
  return new Promise((resolve) => {
    const u = new SpeechSynthesisUtterance(text);
    u.lang = bestVoice?.lang.startsWith("ar") ? "ar-MA" : "fr-FR";
    u.rate = 0.88;
    if (bestVoice) u.voice = bestVoice;
    u.onend = () => resolve();
    u.onerror = () => resolve();
    try {
      synth.speak(u);
    } catch {
      resolve();
    }
  });
}

const VocalDeclarationIA: React.FC<VocalDeclarationIAProps> = ({
  currentUser,
  locationCity,
  latitude,
  longitude,
  onAnalyse,
}) => {
  const [modeParole] = useState(true);
  const [listening, setListening] = useState(false);
  const [loading, setLoading] = useState(false);
  const [awaitingConfirm, setAwaitingConfirm] = useState(false);
  const [transcript, setTranscript] = useState("");
  const [result, setResult] = useState<AnomalieIAResult | null>(null);
  const [error, setError] = useState("");
  const [textInput, setTextInput] = useState("");
  const [showAdvanced, setShowAdvanced] = useState(false);
  const recognizerRef = useRef<any>(null);
  const localeIdxRef = useRef(0);
  const resultRef = useRef<AnomalieIAResult | null>(null);
  const awaitingConfirmRef = useRef(false);
  const welcomedRef = useRef(false);

  const driverName =
    currentUser?.name ||
    [currentUser?.firstname, currentUser?.name].filter(Boolean).join(" ") ||
    "";

  const buildGpsContext = useCallback((): string => {
    if (locationCity && locationCity !== "MANUEL") return locationCity;
    if (latitude != null && longitude != null) {
      return `${latitude},${longitude}`;
    }
    return currentUser?.ville || "";
  }, [locationCity, latitude, longitude, currentUser?.ville]);

  useEffect(() => {
    resultRef.current = result;
  }, [result]);

  useEffect(() => {
    awaitingConfirmRef.current = awaitingConfirm;
  }, [awaitingConfirm]);

  useEffect(() => {
    if (welcomedRef.current || !modeParole) return;
    welcomedRef.current = true;
    const t = setTimeout(() => parler(MSG.welcome), 600);
    return () => clearTimeout(t);
  }, [modeParole]);

  const isAffirmative = (t: string) => {
    const l = t.toLowerCase().trim();
    const yes = ["oui", "yes", "wah", "wa7", "wakha", "\u0648\u0627\u062E\u0627", "\u0646\u0639\u0645", "naam", "iyeh", "ah", "sahih", "\u0635\u062D\u064A\u062D", "ok"];
    const no = ["non", "la", "\u0644\u0627", "mashi", "\u0645\u0627\u0634\u064A"];
    if (no.some((n) => l.includes(n))) return false;
    return yes.some((y) => l.includes(y) || l.startsWith(y));
  };

  const remplirFormulaire = useCallback(() => {
    const r = resultRef.current;
    if (r && onAnalyse) {
      onAnalyse(r);
      parler(MSG.confirmed);
    }
  }, [onAnalyse]);

  const analyserTexte = useCallback(
    async (texte: string) => {
      if (!texte.trim()) return;
      setLoading(true);
      setError("");
      setAwaitingConfirm(false);
      setResult(null);
      setTranscript(texte.trim());
      await parler(MSG.analysing);

      const gps = buildGpsContext();
      const body = {
        texte: texte.trim(),
        userName: driverName,
        chauffeur: driverName,
        gpsLocation: gps,
        localisation: locationCity && locationCity !== "MANUEL" ? locationCity : gps,
        latitude: latitude ?? undefined,
        longitude: longitude ?? undefined,
        dateTime: new Date().toISOString(),
        date: new Date().toISOString().slice(0, 10),
      };

      try {
        const { data } = await axios.post<AnomalieIAResult>(
          "http://localhost:8080/api/anomalie-ia/analyser",
          body,
          {
            headers: {
              "X-User-Name": driverName,
              "X-GPS-Location": gps,
              "X-Date-Time": body.dateTime,
            },
          }
        );
        if (data.success === false) {
          setError(data.erreur || "Analyse impossible");
          await parler(MSG.errorServer);
          return;
        }
        const parsed: AnomalieIAResult = {
          vehicule: data.vehicule || "UNKNOWN",
          chauffeur: data.chauffeur || driverName || "UNKNOWN",
          localisation: data.localisation || gps || "UNKNOWN",
          element: data.element || "UNKNOWN",
          anomalie: data.anomalie || "",
          description: data.description || texte.trim(),
          categorie: data.categorie || "M\u00e9canique",
          criticite: data.criticite || "Moyenne",
          date: data.date || body.date,
          source: data.source || "Voix chauffeur",
          typePanne: data.typePanne,
          success: true,
        };
        setResult(parsed);
        resultRef.current = parsed;
        setAwaitingConfirm(true);
        await parler(MSG.success(parsed));
        await parler(MSG.confirmPrompt);
      } catch {
        setError("Serveur injoignable");
        await parler(MSG.errorServer);
      } finally {
        setLoading(false);
      }
    },
    [driverName, locationCity, latitude, longitude, buildGpsContext]
  );

  const handleVoiceInput = useCallback(
    (t: string) => {
      if (awaitingConfirmRef.current && resultRef.current) {
        if (isAffirmative(t)) {
          setAwaitingConfirm(false);
          remplirFormulaire();
        } else {
          setAwaitingConfirm(false);
          setResult(null);
          resultRef.current = null;
          parler("Wakha. 3awed 9ol mochkil dyalek men l'bda.");
        }
        return;
      }
      analyserTexte(t);
    },
    [analyserTexte, remplirFormulaire]
  );

  const startListening = useCallback(() => {
    if (!Recognition) {
      setError("Micro non support\u00e9");
      parler(MSG.errorMic);
      return;
    }
    if (listening || loading) return;

    setListening(true);
    setError("");
    parler(awaitingConfirm ? MSG.confirmPrompt : MSG.listening);

    const recognizer = new Recognition();
    recognizer.continuous = false;
    recognizer.interimResults = false;
    recognizer.maxAlternatives = 3;
    recognizer.lang = LOCALES[localeIdxRef.current % LOCALES.length];

    recognizer.onresult = (event: any) => {
      setListening(false);
      localeIdxRef.current = 0;
      const t = event.results[0][0].transcript.trim();
      if (t) handleVoiceInput(t);
    };

    recognizer.onerror = (event: any) => {
      if (event.error === "no-speech") {
        localeIdxRef.current++;
        if (localeIdxRef.current < LOCALES.length) {
          setListening(false);
          setTimeout(() => startListening(), 400);
          return;
        }
        parler(MSG.noSpeech);
      } else if (event.error === "not-allowed") {
        setError("Micro bloqu\u00e9");
        parler(MSG.errorMic);
      }
      setListening(false);
      localeIdxRef.current = 0;
    };

    recognizer.onend = () => setListening(false);

    try {
      recognizer.start();
      recognizerRef.current = recognizer;
    } catch {
      setListening(false);
      parler(MSG.errorMic);
    }
  }, [listening, loading, awaitingConfirm, handleVoiceInput]);

  const stopListening = () => {
    try {
      recognizerRef.current?.stop();
    } catch {
      /* ignore */
    }
    setListening(false);
  };

  const micLabel = listening
    ? "\uD83D\uDD34"
    : loading
      ? "\u23F3"
      : awaitingConfirm
        ? "\u2705"
        : "\uD83C\uDFA4";

  const micHint = listening
    ? "Kanssma3..."
    : loading
      ? "Kan7ellel..."
      : awaitingConfirm
        ? "9ol OUI / WAKHA"
        : "HBES HNA";

  return (
    <div className="flex flex-col h-full max-w-lg mx-auto space-y-6 p-4">
      <div className="text-center space-y-3">
        <div className="text-7xl" aria-hidden="true">
          🎤
        </div>
        <p className="text-2xl font-black text-slate-800 tracking-wide" dir="rtl" lang="ar">
          {'\u062A\u0643\u0644\u0645 \u2014 \u0645\u0627 \u0645\u062D\u062A\u0627\u062C\u0634 \u062A\u0642\u0631\u0627'}
        </p>
        <p className="text-lg font-bold text-blue-700">
          Parlez seulement — pas besoin de lire ni \u00e9crire
        </p>
        {driverName && (
          <p className="text-sm text-slate-500" aria-label={`Chauffeur ${driverName}`}>
            👤 {driverName}
          </p>
        )}
      </div>

      <button
        type="button"
        aria-label={
          awaitingConfirm
            ? "Confirmer en disant oui"
            : "Appuyer et parler pour d\u00e9clarer la panne"
        }
        onClick={listening ? stopListening : startListening}
        disabled={loading}
        className={`w-full aspect-square max-w-[280px] mx-auto rounded-full text-4xl font-black flex flex-col items-center justify-center gap-2 transition-all shadow-2xl border-4 ${
          listening
            ? "bg-red-500 border-red-300 text-white animate-pulse scale-105"
            : loading
              ? "bg-slate-300 border-slate-200 text-slate-600"
              : awaitingConfirm
                ? "bg-green-500 border-green-300 text-white animate-bounce"
                : "bg-blue-600 border-blue-400 text-white hover:bg-blue-700 hover:scale-105"
        }`}
      >
        <span className="text-6xl">{micLabel}</span>
        <span className="text-base font-bold uppercase tracking-widest">{micHint}</span>
      </button>

      {awaitingConfirm && result && (
        <button
          type="button"
          onClick={remplirFormulaire}
          className="w-full py-6 bg-green-600 text-white rounded-2xl text-2xl font-black shadow-lg hover:bg-green-700"
          aria-label="Valider et remplir le formulaire"
        >
          ✅ OUI — VALIDER
        </button>
      )}

      {error && (
        <div
          className="px-4 py-4 bg-red-100 border-2 border-red-400 text-red-800 rounded-2xl text-lg font-bold text-center"
          role="alert"
        >
          ⚠️ {error}
        </div>
      )}

      {transcript && modeParole && (
        <p className="text-center text-slate-600 dark:text-slate-400 text-sm italic" aria-live="polite">
          « {transcript} »
        </p>
      )}

      <button
        type="button"
        className="text-xs text-slate-600 dark:text-slate-400 underline mx-auto"
        onClick={() => setShowAdvanced((v) => !v)}
      >
        {showAdvanced ? "Masquer d\u00e9tails" : "Mode technicien (texte)"}
      </button>

      {showAdvanced && (
        <div className="space-y-3 border-t pt-4">
          <div className="flex gap-2">
            <input
              className="flex-1 border rounded-xl px-3 py-2 text-sm"
              placeholder='Test: "camion 452 fran khayb f casa"'
              value={textInput}
              onChange={(e) => setTextInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && !loading && analyserTexte(textInput)}
            />
            <button
              type="button"
              onClick={() => analyserTexte(textInput)}
              disabled={loading || !textInput.trim()}
              className="px-4 py-2 bg-slate-700 text-white rounded-xl text-sm"
            >
              Test
            </button>
          </div>
          {result && (
            <pre className="text-xs bg-slate-50 p-3 rounded-lg overflow-x-auto">
              {JSON.stringify(result, null, 2)}
            </pre>
          )}
        </div>
      )}
    </div>
  );
};

export default VocalDeclarationIA;
