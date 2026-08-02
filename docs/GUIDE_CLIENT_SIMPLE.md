# GUIDE CLIENT — Installation simple (aucun outil requis)

> **Objectif :** avoir l'application **installée et ouverte sur votre téléphone** en 5 minutes.
> Vous n'avez **rien** à installer et **aucune connaissance technique** n'est nécessaire.

---

## 0. Vérifications avant de commencer

- Votre téléphone doit être **Android 7.0 (année 2016) ou plus récent**. Pour le vérifier : **Paramètres → À propos du téléphone → Version Android** (sur Samsung : Paramètres → À propos du téléphone → Informations sur le logiciel).
- L'application n'est **pas disponible sur iPhone** dans cette livraison.
- Vous avez besoin d'environ **500 Mo d'espace libre** sur le téléphone.

## 1. Récupérer le fichier de l'application

L'application est un **fichier `.apk`** (version 1.0.0).

- **Nom du fichier attendu dans la livraison : `SmartFleet.apk`** (environ 115 Mo).
- Il se trouve dans le dossier **`dist`** à la racine de votre dossier de livraison.
- **Le fichier peut s'appeler `app-debug.apk`** : c'est le **même** fichier, vous pouvez l'utiliser tel quel.
- **Si aucun fichier `.apk` n'est présent : c'est un oubli du fournisseur, demandez-le-lui.** C'est le **seul** fichier dont vous avez besoin.
- ⚠️ **Important :** dans votre dossier de livraison, il y a d'autres dossiers (ex. `docs`, `backend`, `fetched`). **Ignorez-les totalement : seul `SmartFleet.apk` vous sert.**

## 2. Transférer le fichier sur le téléphone

Choisissez une méthode (**USB** et **WhatsApp** fonctionnent toujours) :

1. **Par câble USB** *(méthode la plus sûre)* : branchez le téléphone à l'ordinateur, copiez le fichier dans le dossier « Téléchargements » du téléphone.
2. **Par messagerie** (WhatsApp, etc.) : envoyez le fichier sur votre propre téléphone (WhatsApp accepte les fichiers volumineux).
3. **Par e-mail** : ⚠️ **évitez l'e-mail** : la plupart des boîtes mail (Gmail, Outlook…) **refusent les pièces jointes de plus de 25 Mo**, or le fichier pèse **115 Mo**. Ne choisissez l'e-mail que si votre messagerie accepte les gros fichiers.

> **Où retrouver le fichier sur le téléphone ?** Ouvrez l'application **« Fichiers »** ou **« Mes fichiers »** (icône dossier), puis le dossier **« Téléchargements »**. Les fichiers reçus par WhatsApp/mail sont dans les dossiers « WhatsApp » ou « Downloads ».

## 3. Installer l'application — selon votre version Android

> Choisissez **la section qui correspond à votre version Android** (trouvée à l'étape 0).

### A. Android 13 à 16 (2022 et après)

1. Touchez le fichier `.apk` (depuis votre boîte mail, WhatsApp ou Téléchargements).
2. Android affiche : **« Installer une application inconnue ? »** → touchez **Paramètres** (en haut).
3. Vous êtes sur la page de l'application que vous venez d'utiliser (ex. Chrome, Gmail, WhatsApp) : activez **« Autoriser l'installation d'applications inconnues »** → touchez la flèche **Retour**.
4. Si une page **« Google Play Protect »** (bleue/verte) apparaît : touchez **« Plus d'informations »** → **« Installer quand même »** → **« Installer quand même »** pour confirmer.
5. Touchez **Installer**, patientez quelques minutes (le fichier est volumineux), puis **Ouvrir**.

### B. Android 10, 11 ou 12 (2019–2022)

1. Touchez le fichier `.apk`.
2. Message **« Pour votre sécurité, votre téléphone n'est pas autorisé à installer des applications inconnues »** → touchez **Paramètres**.
3. Activez **« Autoriser à partir de cette source »** → flèche **Retour**.
4. Si « Play Protect » apparaît → **« Installer quand même »**.
5. **Installer** → patientez → **Ouvrir**.

### C. Android 8 ou 9 (2017–2018)

1. Allez dans **Paramètres → Applications** (ou « Gestionnaire d'applications »).
2. Touchez l'application qui contient le fichier (ex. Chrome, WhatsApp, messagerie).
3. Touchez **« Installer des applications inconnues »** → activez **Autoriser**.
4. Retournez au fichier `.apk` → **Installer** → **Ouvrir**.

### D. Android 7 (2016) — version minimale

1. Allez dans **Paramètres → Sécurité**.
2. Activez **« Sources inconnues »** (une confirmation peut s'afficher → **OK**).
3. Touchez le fichier `.apk` → **Installer** → **Ouvrir**.

### Après l'installation (toutes versions)

- L'icône **`smartfleet_mobile`** apparaît dans votre liste d'applications (tiroir d'applications) ou sur l'écran d'accueil. **Touchez-la pour ouvrir l'application.**

### En cas de problème

- **« Application non installée »** : l'espace libre est insuffisant. Allez dans **Paramètres → Stockage**, vérifiez l'espace libre, supprimez des fichiers, puis réessayez.
- **Installation bloquée** : recommencez avec les étapes de **votre version** ci-dessus (A, B, C ou D).
- **Fichier qui ne s'ouvre pas** : le téléchargement est peut-être incomplet. Vérifiez dans votre gestionnaire de fichiers que le fichier fait bien la taille annoncée (~115 Mo), sinon transférez-le à nouveau.
- **Les noms des boutons peuvent légèrement varier selon la marque** du téléphone (Samsung, Xiaomi, Huawei, Oppo…). Cherchez dans les Paramètres : **« Installer des applications inconnues »** ou **« Sources inconnues »**.

## 4. Ouvrir et se connecter

1. Au premier lancement, l'application **prépare elle-même** ses fichiers de données et ses données d'exemple — **vous n'avez rien à configurer**. **Patientez quelques secondes** au premier démarrage.
2. Saisissez l'un de ces comptes :

| Profil | Adresse e-mail | Mot de passe |
|---|---|---|
| Administrateur | `admin@smartfleet.fr` | `admin123` |
| Chauffeur | `jean@smartfleet.fr` | `chauffeur123` |
| Prestataire | `presta@smartfleet.fr` | `presta123` |
| Responsable Support | `rs_support@smartfleet.fr` | `support123` |

3. ✅ **Résultat attendu :** vous arrivez sur l'accueil correspondant à votre profil.

## 5. Premier test (5 minutes)

1. Connectez-vous avec le profil **Chauffeur** (`jean@smartfleet.fr` / `chauffeur123`).
2. Touchez **« + Nouvelle déclaration »**.
3. Remplissez les 3 étapes (Localisation → Véhicule → Détails) puis touchez **Créer**.
4. ✅ **Résultat attendu :** la déclaration apparaît avec le statut **« En attente »** dans le menu « Déclarations ».

> **Vous avez terminé.** L'application fonctionne entièrement **sans Internet** : vos données sont enregistrées dans le téléphone.

---

## Ce que l'application permet de faire

| Fonction | À quoi ça sert |
|---|---|
| **Déclarations** | Signaler un incident sur un véhicule et suivre sa réparation |
| **Check-up véhicule** | Vérifier un véhicule avec une checklist (freins, pneus, éclairage…) |
| **Tournées** | Planifier et suivre les trajets |
| **Documents** | Stocker les papiers des véhicules et être alerté des expirations |
| **Maintenance** | Tickets de maintenance et interventions |
| **Budget** | Suivi du budget de maintenance |
| **Alertes & blocages** | Alerter sur un véhicule et le bloquer/débloquer |
| **Agent IA (vocal)** | Déclarer un incident à la voix — *fonctionne si votre fournisseur a activé le service vocal* |

---

## Comment ça marche (workflow)

```
CHAUFFEUR signale un incident → « En attente »
        │
        ▼
PRESTATAIRE prend en charge → « En cours »
        │
        ▼
PRESTATAIRE rédige le rapport → « En validation »
        │
        ▼
Validation → « Traité » → Clôture → « Clôturée »
```

- Le prestataire peut **retourner** une déclaration incomplète → « Retournée » → le chauffeur la complète et la re-soumet.
- Le responsable support peut **rejeter** une demande → « Rejetée ».

---

## Scénario de test complet (résumé)

| # | Rôle | Action | Statut après |
|---|---|---|---|
| 1 | Chauffeur | Créer une déclaration (moteur, Casablanca) | En attente |
| 2 | Prestataire | Prendre en charge | En cours |
| 3 | Prestataire | Saisir le rapport | En validation |
| 4 | Prestataire | Valider | Traité |
| 5 | Prestataire | Clôturer | **Clôturée** |
| 6 | Admin | Vérifier l'historique (Audit Log) | — |

> **Le guide de test détaillé, étape par étape, se trouve dans `../TEST_CLIENT.md`.**

---

## Exemples d'écrans de l'application

> Les illustrations de chaque écran sont fournies dans le dossier **`docs/screenshots/`** de votre livraison (dossier « Captures d'écran »).

| N° | Écran | Fichier image |
|---|---|---|
| 01 | Écran de connexion | `01-connexion.png` |
| 02 | Accueil Chauffeur | `02-accueil-chauffeur.png` |
| 03 | Création de déclaration | `03-declaration.png` |
| 04 | Liste des déclarations | `04-liste-declarations.png` |
| 05 | Accueil Prestataire | `05-accueil-prestataire.png` |
| 06 | Accueil Admin | `06-accueil-admin.png` |
| 07 | Accueil RS | `07-accueil-rs.png` |
