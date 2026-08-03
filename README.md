# SmartFleet — Gestion de flotte automobile

> Application mobile de gestion de flotte avec **assistant vocal IA**, pour les équipes Danone Maroc : déclaration d'incidents véhicules, check-up, tournées, documents, maintenance, budget, alertes et analyses Power BI.

## Composants du projet

| Dossier | Contenu |
|---|---|
| `smartfleet_mobile/` | Application mobile **Flutter** (base SQLite locale, bilingue FR/AR) |
| `backend/` | Serveur **Agent IA** (Spring Boot, port 8082) + serveur **vocal TTS/STT** (Python, port 5000) |
| `powerbi_rs/` | Rapport **Power BI** pour le rôle Responsable Support |
| `docs/` | Guides : client simple, technique, captures d'écran |
| `scripts/` | Tunnels adb pour la démonstration locale (`restore_tunnels.bat`) |
| `dist/` | APK de livraison (`SmartFleet.apk`) |
| `TEST_CLIENT.md` | Guide de test pas à pas de toutes les fonctions |

## Documentation

| Vous êtes… | Lisez… |
|---|---|
| **Utilisateur non technique** | [`docs/GUIDE_CLIENT_SIMPLE.md`](docs/GUIDE_CLIENT_SIMPLE.md) — installer l'app en 5 minutes, sans outils |
| **Équipe technique** | [`docs/GUIDE_TECHNIQUE.md`](docs/GUIDE_TECHNIQUE.md) — compiler depuis les sources, lancer les serveurs |
| **Testeur** | [`TEST_CLIENT.md`](TEST_CLIENT.md) — vérifier toutes les fonctions, étape par étape |

## Démarrage rapide (démonstration)

1. **Installer l'app** : `dist/SmartFleet.apk` sur un téléphone Android 7+ (voir le guide client).
2. **Lancer les serveurs** (agent IA 8082 + vocal 5000) :
   ```bash
   cd backend
   mvn spring-boot:run        # terminal 1 — serveur Agent IA (port 8082)
   python tts_server.py       # terminal 2 — serveur vocal TTS/STT (port 5000)
   ```
3. **Connecter un téléphone physique** (démonstration locale) : téléphone branché en USB, puis
   ```bash
   scripts\restore_tunnels.bat   # active adb reverse tcp:8082 et tcp:5000
   ```
4. **Comptes de démonstration** :
   - Admin : `admin@smartfleet.fr` / `admin123`
   - Chauffeur : `jean@smartfleet.fr` / `chauffeur123`
   - Prestataire : `presta@smartfleet.fr` / `presta123`
   - Responsable Support : `rs_support@smartfleet.fr` / `support123`

## Points clés

- **Offline-first** : toutes les données (déclarations, check-ups…) sont enregistrées dans le téléphone (SQLite) et synchronisées quand la connexion revient.
- **Agent IA vocal** : fonctionne **en ligne** (voix Jamal + Google STT + backend) et **hors ligne** (reconnaissance/voix natives du téléphone + agent conversationnel déterministe sans Internet).
- **Sans serveur** : l'application de gestion fonctionne entièrement en local ; seul le vocal est limité.

## Tests

- Application mobile : **65 tests fonctionnels** (`flutter test`), `flutter analyze` **0 erreur**.
- Backend : **19 tests unitaires** (`mvn test`).
- Pipeline Power BI : **15 tests** (`python powerbi_rs/test_powerbi_pipeline.py`).
