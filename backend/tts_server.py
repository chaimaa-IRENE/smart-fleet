import sys, os, asyncio, io, ssl, tempfile, json

# Patch edge-tts SSL contexts BEFORE any edge_tts import
import edge_tts.communicate, edge_tts.voices
_ssl_ctx = ssl.create_default_context()
_ssl_ctx.check_hostname = False
_ssl_ctx.verify_mode = ssl.CERT_NONE
edge_tts.communicate._SSL_CTX = _ssl_ctx
edge_tts.voices._SSL_CTX = _ssl_ctx

from flask import Flask, Response, request
import edge_tts
import speech_recognition as sr

app = Flask(__name__)

async def _generate_tts(text: str, voice: str, rate: str) -> bytes:
    tts = edge_tts.Communicate(text, voice, rate=rate)
    buf = io.BytesIO()
    async for chunk in tts.stream():
        if chunk["type"] == "audio":
            buf.write(chunk["data"])
    return buf.getvalue()

@app.route("/api/tts/speak")
def speak():
    text = request.args.get("text", "")
    voice = request.args.get("voice", "ar-MA-JamalNeural")
    rate = request.args.get("rate", "-5%")
    if not text:
        return {"error": "missing text"}, 400
    try:
        data = asyncio.run(_generate_tts(text, voice, rate))
        return Response(data, mimetype="audio/mpeg")
    except Exception as e:
        return {"error": str(e)}, 500

@app.route("/api/stt/transcribe", methods=["POST"])
def transcribe():
    if "audio" not in request.files:
        return {"text": "", "available": True, "message": "missing audio file"}, 400
    audio_file = request.files["audio"]
    lang = request.form.get("language", "ar")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        audio_file.save(tmp.name)
        tmp_path = tmp.name
    try:
        recognizer = sr.Recognizer()
        with sr.AudioFile(tmp_path) as source:
            audio = recognizer.record(source)
        text = recognizer.recognize_google(audio, language=lang)
        return {"text": text, "available": True, "message": "OK"}
    except sr.UnknownValueError:
        return {"text": "", "available": True, "message": "لم يتم التعرف على الصوت"}
    except sr.RequestError as e:
        return {"text": "", "available": False, "message": f"STT service error: {e}"}
    except Exception as e:
        return {"text": "", "available": False, "message": str(e)}
    finally:
        try:
            os.unlink(tmp_path)
        except:
            pass

@app.route("/api/stt/status")
def stt_status():
    return {"available": True, "service": "google_web_speech"}

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
    print(f"TTS+STT server starting on port {port}...")
    app.run(host="0.0.0.0", port=port, debug=False, threaded=False)
