# GUIDE TECHNIQUE — Installation depuis les sources

> **Objectif :** compiler l'application vous-même à partir du code source et la lancer sur un téléphone.
> **Public :** équipes techniques. Cette voie exige d'installer des outils **une seule fois**.
> Si vous êtes un utilisateur non technique, utilisez plutôt **`GUIDE_CLIENT_SIMPLE.md`**.

---

## 0. TOUS LES OUTILS NÉCESSAIRES : versions exactes + liens de téléchargement

| # | Outil | Version exacte à installer | À quoi il sert | Lien de téléchargement officiel |
|---|---|---|---|---|
| 1 | **Flutter SDK** | **3.44.x** (canal stable) — inclut Dart 3.12 | Compile et lance l'application | https://docs.flutter.dev/get-started/install/windows |
| 2 | **Android Studio** | **Dernière version stable** | Fournit le SDK Android + l'outillage de compilation | https://developer.android.com/studio |
| 3 | **Git** | **Dernière version (2.5x)** | Requis par Flutter | https://git-scm.com/download/win |
| 4 | **Java (JDK)** | **21 LTS** (Temurin, Windows x64) | Serveur « Agent IA » (facultatif) | https://adoptium.net/temurin/releases/?version=21 |
| 5 | **Maven** | **3.9.x** (ex. 3.9.15) | Serveur « Agent IA » (facultatif) | https://maven.apache.org/download.cgi |
| 6 | **Python** | **3.10 ou plus** (ex. 3.12.x) | Serveur vocal TTS/STT (facultatif) | https://www.python.org/downloads/ |

> **Rappel important :** les outils **4, 5 et 6 ne servent qu'au serveur « Agent IA » (optionnel)**.
> Pour compiler et lancer l'application, seuls les outils **1, 2 et 3** sont indispensables.

---

## 1. Installer Flutter SDK (outil 1)

1. Ouvrir le lien ci-dessus (documentation officielle Flutter → onglet **Windows**).
2. Cliquer sur **« Download the Flutter SDK »** (canal **stable**). Un dossier compressé `.zip` est téléchargé.
3. **Extraire** le contenu dans un dossier simple, ex. `C:\flutter` (évitez les dossiers avec espaces).
4. Ouvrir le fichier **`flutter_console.bat`** situé dans `C:\flutter` (un écran noir s'ouvre).
5. Dans cet écran, taper la commande : `flutter doctor` puis Entrée.
   - La première exécution télécharge des composants (patience : plusieurs minutes).
   - À la fin, des lignes vertes doivent s'afficher. S'il reste des croix rouges, ce sont les points **2 (Android Studio)** et **3 (Git)** à installer ci-dessous.
6. ✅ Quand `flutter doctor` n'affiche plus de croix sur « Flutter », « Android toolchain » et « Git », c'est bon.

---

## 2. Installer Android Studio (outil 2)

1. Ouvrir le lien officiel : https://developer.android.com/studio
2. Cliquer sur le gros bouton **« Download Android Studio »** (version Windows).
3. Lancer le fichier téléchargé, choisir **« Standard »** lors de l'installation, puis **Installer**.
4. À la première ouverture, un assistant télécharge le **SDK Android** automatiquement. Laissez-le terminer.
5. Dans Android Studio : **File → Settings → Appearance & Behavior → System Settings → Android SDK** pour vérifier qu'au moins une version du SDK est installée (ex. API 35 ou plus récente).
6. ✅ Résultat attendu : Android Studio s'ouvre sans erreur.

---

## 3. Installer Git (outil 3)

1. Ouvrir le lien officiel : https://git-scm.com/download/win
2. Télécharger la version **64-bit** et lancer l'installation.
3. Dans l'assistant, laisser toutes les valeurs par défaut et cliquer **Next** jusqu'à **Install**.
4. ✅ Résultat attendu : « Installation terminée ».

---

## 4. (Optionnel) Installer Java 21, Maven, Python

> Réservé au **serveur Agent IA**. Sautez cette section si vous ne l'utilisez pas.

### 4.1 Java 21 (JDK)
1. Lien : https://adoptium.net/temurin/releases/?version=21
2. Choisir **Windows → x64 → fichier `.msi`** et lancer l'installation (valeurs par défaut).
3. Vérifier : ouvrir un terminal et taper `java -version` → doit afficher `java version "21.x"`.

### 4.2 Maven 3.9.x
1. Lien : https://maven.apache.org/download.cgi
2. Télécharger **« Binary zip archive »** (`apache-maven-3.9.x-bin.zip`), extraire dans `C:\apache-maven`.
3. Vérifier : dans un terminal, taper `mvn -version` → doit afficher `Apache Maven 3.9.x`.

### 4.3 Python 3.10+
1. Lien : https://www.python.org/downloads/
2. Lancer l'installateur et **COCHER la case « Add Python to PATH »** avant de cliquer Install.
3. Vérifier : dans un terminal, taper `python --version` → doit afficher `Python 3.x`.

---

## 5. Vérifier que tout est prêt

> **⚠️ Point important :** toutes les commandes `flutter …` se tapent dans la **console Flutter** (la fenêtre noire `flutter_console.bat` de l'étape 1). Dans un terminal Windows ordinaire (`cmd` ou PowerShell), la commande `flutter` n'est **pas reconnue** tant que le dossier `C:\flutter\bin` n'a pas été ajouté aux variables d'environnement (voir la note de fin de section).

1. Rouvrir la **console Flutter** : double-cliquer sur `C:\flutter\flutter_console.bat`.
2. Taper : `flutter doctor` puis Entrée.
   - Si une ligne affiche `Android license status unknown` : taper la commande suivante puis répondre `y` à **chaque** question :
     ```
     flutter doctor --android-licenses
     ```
     Cette étape **autorise les licences du SDK Android** ; sans elle, la compilation échoue.
3. ✅ Résultat attendu : les lignes suivantes affichent **✓** :
   - Flutter
   - Android toolchain (développement Android)
   - Git

> **Pour utiliser `flutter` dans n'importe quel terminal** (optionnel) : `Paramètres → Rechercher « variables d'environnement » → Variables d'environnement → Variables système → Path → Modifier → Nouveau` puis ajouter le dossier `C:\flutter\bin`. Puis **fermer et rouvrir** le terminal. Si vous ne faites pas cette manipulation, **continuez simplement à utiliser la console Flutter**.

---

## 6. Préparer le téléphone de test

1. Sur le téléphone : **Paramètres → À propos du téléphone** → toucher **7 fois** sur « Numéro de build » (un message « Vous êtes développeur » apparaît).
2. **Paramètres → Options de développeur** → activer **« Débogage USB »**.
3. Brancher le téléphone à l'ordinateur avec un câble USB.
4. Sur le téléphone, une fenêtre « Autoriser le débogage USB ? » apparaît → cocher « Toujours » → **Autoriser**.
5. Vérifier : dans la **console Flutter** (section 5), taper `flutter devices` → votre téléphone doit apparaître dans la liste.

---

## 7. Compiler et lancer l'application (JUSQU'À L'EXÉCUTION)

> **Toutes les commandes ci-dessous se tapent dans la console Flutter** (section 5). La **première compilation** télécharge environ 2 à 3 Go de dépendances et prend **10 à 20 minutes** : c'est normal, il faut un ordinateur connecté à Internet et ~10 Go d'espace libre.

1. Naviguer jusqu'au dossier de l'application : le dossier **`smartfleet_mobile`** de votre livraison (celui qui contient le fichier `pubspec.yaml`). Dans la console Flutter :
   ```bash
   cd smartfleet_mobile
   ```
   > Si le chemin contient des espaces, entourez-le de guillemets, ex. `cd "C:\livraison\smartfleet_mobile"`.
2. Télécharger les composants du projet (à faire la 1re fois) :
   ```bash
   flutter pub get
   ```
3. **Lancer l'application** (compile, installe et ouvre sur le téléphone) :
   ```bash
   flutter run
   ```
4. ✅ **Résultat attendu :** après quelques minutes de compilation la première fois, l'application **s'ouvre sur le téléphone** et affiche l'écran de connexion.
5. Pour arrêter : toucher `q` puis Entrée dans la console Flutter.

> **Si vous voyez un message d'erreur**, copiez les dernières lignes du terminal et transmettez-les à votre fournisseur.

## 7bis. Générer l'APK de livraison (à fournir au client)

Le guide client (`GUIDE_CLIENT_SIMPLE.md`) fait installer un fichier **`SmartFleet.apk`** au client. Pour le produire :

1. Toujours dans la console Flutter :
   ```bash
   flutter build apk --release
   ```
2. ✅ Résultat attendu : `√ Built build\app\outputs\flutter-apk\app-release.apk` (≈ 115 Mo).
3. **Copier** ce fichier dans le dossier `dist` de la livraison en le **renommant `SmartFleet.apk`** :
   ```bash
   copy build\app\outputs\flutter-apk\app-release.apk ..\dist\SmartFleet.apk
   ```
4. Vérifier que `SmartFleet.apk` se trouve bien dans le dossier `dist`, à la racine de la livraison.

> **Si la livraison utilise Git :** le fichier `.gitignore` ignore les `*.apk`. Pour forcer l'envoi du fichier : `git add -f SmartFleet.apk`.
>
> **Signature :** l'APK produit est signé avec la clé *debug* (configuration par défaut du projet). Pour une publication officielle, remplacez la ligne `signingConfig = signingConfigs.getByName("debug")` du fichier `android/app/build.gradle.kts` par un vrai certificat de production.

---

## 8. Exécuter TOUS les serveurs (3 serveurs + application)

> Le système peut faire tourner jusqu'à **3 serveurs**, plus l'application mobile. Pour une démonstration complète de l'**Agent IA vocal**, les 2 premiers serveurs sont indispensables.

| # | Serveur | Port | Rôle | Indispensable ? |
|---|---|---|---|---|
| 1 | Serveur « Agent IA » (Spring Boot) | **8082** | Cœur de l'assistant vocal (conversation, extraction de la plaque) | **OUI** |
| 2 | Serveur vocal TTS/STT (Python) | **5000** | Synthèse vocale (TTS) + reconnaissance vocale (STT) | **OUI** |
| 3 | LLM local Ollama | **11434** | Alternative locale au serveur Agent IA (modèle `llama3.2`) | **NON** (non utilisé par l'app actuelle) |
| — | Application mobile (Flutter) | — | Se lance sur le téléphone / l'émulateur | **OUI** |

> **État vérifié (livraison) :** les serveurs 1 et 2 ont été démarrés et testés avec succès (voir §8.8).
> **Serveur 3 (Ollama) :** présent dans le code (`lib/services/ollama_service.dart`) mais **non relié** à l'application : l'Agent IA fonctionne entièrement avec le serveur 1. Ollama est une option pour l'avenir, sa section de démarrage est fournie ci-dessous.
> **Sans les serveurs 1 et 2**, l'application fonctionne entièrement en local ; seule la fonction « Agent IA » affichera un message de connexion impossible.

### 8.1 Ordre de démarrage recommandé

1. Démarrer le serveur **Agent IA** (port 8082)
2. Démarrer le serveur **vocal** (port 5000)
3. Lancer l'application (`flutter run`)

### 8.2 Composant 1 — Serveur « Agent IA » (port 8082)

> Prérequis : **Java 21 + Maven 3.9** (section 4).

1. Ouvrir un terminal et aller dans le dossier `backend` :
   ```bash
   cd backend
   ```
2. Lancer le serveur :
   ```bash
   mvn spring-boot:run
   ```
3. ✅ Résultat attendu (après ~30 secondes) : le log se termine par
   `Tomcat started on port 8082 (http)` → le serveur tourne.
4. **Vérification rapide** : ouvrir un navigateur sur `http://127.0.0.1:8082/api/stt/status` → la page affiche `{"available":false}` (normal : la STT réelle est assurée par le composant 2).
5. **Arrêter** : toucher `Ctrl + C` dans le terminal.

### 8.3 Composant 2 — Serveur vocal TTS/STT (port 5000)

> Prérequis : **Python 3.10+** (section 4.3).

1. Dans un **second terminal**, installer les dépendances (une seule fois) :
   ```bash
   cd backend
   python -m pip install flask edge-tts SpeechRecognition
   ```
2. Lancer le serveur :
   ```bash
   python tts_server.py
   ```
3. ✅ Résultat attendu : le message `TTS+STT server starting on port 5000...` s'affiche.
4. **Vérification rapide** : ouvrir un navigateur sur `http://127.0.0.1:5000/api/stt/status` → la page affiche `{"available":true,...}`.
5. **Arrêter** : toucher `Ctrl + C` dans le terminal.

### 8.3bis Serveur 3 — LLM local Ollama (port 11434, optionnel)

> Ollama est un serveur d'intelligence artificielle **local** qui peut remplacer le serveur Agent IA (serveur 1). Il est présent dans le code (`lib/services/ollama_service.dart`) mais **pas encore relié** à l'application : sa mise en route n'est donc **pas nécessaire** pour la démonstration. Étapes si vous souhaitez le préparer :

1. Installer Ollama (Windows) :
   ```bash
   winget install --id Ollama.Ollama -e
   ```
   ou télécharger l'installateur **`OllamaSetup.exe`** sur https://ollama.com/download puis l'ouvrir.
2. Une fois installé, Ollama démarre seul et écoute sur le port **11434**.
3. Télécharger le modèle utilisé par l'application (`llama3.2`) :
   ```bash
   ollama pull llama3.2
   ```
4. ✅ **Vérification** : ouvrir un navigateur sur `http://127.0.0.1:11434/api/tags` → la page affiche la liste des modèles dont `llama3.2`.
5. **Arrêter** : icône Ollama dans la barre des tâches → **Quitter Ollama**.

> ⚠️ **Réseau :** l'installation d'Ollama et le téléchargement du modèle (~2 Go) nécessitent une connexion Internet vers `ollama.com`. Sur certains réseaux ce site est bloqué (testé lors de la livraison) ; dans ce cas, Ollama ne peut pas être installé — **sans conséquence** pour l'application, qui utilise le serveur 1.

### 8.4 Composant 3 — Application mobile (`flutter run`)

1. Dans la console Flutter (section 5), aller dans le dossier de l'application :
   ```bash
   cd smartfleet_mobile
   flutter run
   ```
2. ✅ L'application s'ouvre sur le téléphone / l'émulateur.

### 8.5 Connecter un TÉLÉPHONE PHYSIQUE aux 2 serveurs

L'application se connecte à `127.0.0.1:8082` et `127.0.0.1:5000`. Sur un téléphone **branché en USB** (débogage USB activé, section 6), il faut rediriger ces ports vers l'ordinateur :

1. Téléphone branché + « Autoriser le débogage USB » accepté.
2. Double-cliquer sur **`restore_tunnels.bat`** (à la racine de la livraison). La fenêtre affiche :
   ```
   Restoring adb reverse tunnels...
   Tunnels restored:
   tcp:8082 ...
   tcp:5000 ...
   ```
3. ✅ Résultat attendu : `adb reverse --list` affiche `tcp:8082` et `tcp:5000` → le téléphone peut joindre les 2 serveurs comme s'ils étaient sur le téléphone.
4. Si les tunnels se perdent (débranchement USB) : relancer `restore_tunnels.bat`.

> **Émulateur Android :** pas besoin de tunnels, `127.0.0.1` de l'émulateur correspond à celui de l'ordinateur.

### 8.6 Vérifier que TOUT est connecté

1. **Test du serveur Agent IA (chat)** — dans un terminal, taper la commande `curl` ci-dessous puis Entrée :
   ```bash
   curl -X POST http://127.0.0.1:8082/api/voice-ai/chat -H "Content-Type: application/json" -d "{\"messages\":[{\"role\":\"user\",\"content\":\"Plaque AA-123-BC, le moteur fume\"}],\"extract\":{}}"
   ```
   ✅ Résultat attendu : une réponse JSON dont `extract` contient `"immatriculation": "AA123BC"` et `"typePanne": "MECANIQUE"`.
2. Dans l'application, ouvrir la fonction **Agent IA (vocal)**.
3. ✅ La voix est synthétisée (TTS) et la reconnaissance vocale (STT) répond.
4. Tester une phrase : *« Plaque AA-123-BC »* → l'agent répond et reconnaît la plaque.

### 8.7 Variables d'environnement du serveur « Agent IA »

| Variable | Défaut | Rôle |
|---|---|---|
| `OPENAI_API_KEY` | *(vide)* | Sans clé : l'Agent IA répond en mode pré-programmé. |
| `OPENAI_MODEL` | `gpt-4` | Modèle utilisé si une clé est fournie. |
| `JWT_ENABLED` | `false` | **Mettre `true` en production** (sécurité) + définir `JWT_SECRET`. |

### 8.8 Résultats des tests de la livraison (serveurs 1 et 2 — vérifiés)

| Serveur | Commande de lancement | Résultat vérifié |
|---|---|---|
| Agent IA (8082) | `java -jar target/voice-ai-service-1.0.0.jar` | log `Tomcat started on port 8082` ✅ |
| Agent IA — chat | `POST /api/voice-ai/chat` | réponse + extraction `AA123BC`, `MECANIQUE` ✅ |
| Vocal (5000) | `python tts_server.py` | message `TTS+STT server starting on port 5000` ✅ |
| Vocal — TTS | `GET /api/tts/speak?text=...` | réponse `audio/mpeg` (200) ✅ |
| Vocal — statut | `GET /api/stt/status` | `{"available":true,"service":"google_web_speech"}` ✅ |

> Ces tests ont été réalisés le jour de la livraison sur un ordinateur Windows (Java 21, Python 3.10).

---

## 10. Vérifications finales

- [ ] `flutter doctor` : ✓ Flutter, ✓ Android toolchain, ✓ Git
- [ ] `flutter devices` : le téléphone apparaît
- [ ] `flutter run` : l'application s'ouvre sur le téléphone
- [ ] Connexion possible avec les 4 comptes (`admin@smartfleet.fr`, `jean@smartfleet.fr`, `presta@smartfleet.fr`, `rs_support@smartfleet.fr`)
- [ ] (Optionnel) Composant 1 — Serveur Agent IA : `mvn spring-boot:run` → log `Tomcat started on port 8082`
- [ ] (Optionnel) Composant 2 — Serveur vocal : `python tts_server.py` → message `TTS+STT server starting on port 5000`
- [ ] (Optionnel) Serveur 3 — Ollama : `ollama pull llama3.2` → modèle présent (port 11434)
- [ ] (Optionnel) Téléphone physique : `restore_tunnels.bat` → tunnels `tcp:8082` et `tcp:5000` actifs
