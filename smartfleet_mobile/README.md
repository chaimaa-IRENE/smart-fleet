# SmartFleet Mobile

> Application mobile de gestion de flotte automobile : déclaration d'incidents véhicules, check-up, tournées, documents, maintenance, budget et alertes.

## Comment utiliser la documentation

| Vous êtes… | Lisez… | Lien |
|---|---|---|
| **Utilisateur sans outils techniques** (installation simple sur téléphone) | Guide client — aucune installation, pas à pas | [`../docs/GUIDE_CLIENT_SIMPLE.md`](../docs/GUIDE_CLIENT_SIMPLE.md) |
| **Équipe technique** (compilation depuis les sources, versions + liens des outils) | Guide technique — installation complète | [`../docs/GUIDE_TECHNIQUE.md`](../docs/GUIDE_TECHNIQUE.md) |
| **Testeur** (vérifier toutes les fonctions, étape par étape) | Guide de test — scénario complet | [`../TEST_CLIENT.md`](../TEST_CLIENT.md) |

---

## À retenir

- **L'essentiel de l'application fonctionne sans ordinateur et sans serveur** : les données sont enregistrées dans le téléphone (base de données locale, créée automatiquement au premier lancement).
- **APK installable (livraison)** : `SmartFleet.apk` — fourni dans le dossier **`dist`** du dossier de livraison (hors GitHub, le fichier dépasse la limite de 100 Mo). C'est le fichier à installer sur le téléphone (voir le guide client).
- **Comptes de démonstration :**

| Email | Mot de passe | Rôle |
|---|---|---|
| admin@smartfleet.fr | admin123 | ADMIN |
| rs_support@smartfleet.fr | support123 | RS |
| jean@smartfleet.fr | chauffeur123 | CHAUFFEUR |
| presta@smartfleet.fr | presta123 | PRESTATAIRE |

- **L'« Agent IA » (vocal) est optionnel.** Sa version complète nécessite les serveurs fournis (`backend/`), mais il se **dégrade automatiquement hors ligne** : reconnaissance vocale native + synthèse vocale intégrée du téléphone, agent conversationnel déterministe sans Internet (voir le guide technique, §8.9).

---

## Fonctionnalités

- Authentification e-mail/mot de passe + biométrie
- Déclarations d'incidents (8 statuts : En attente → Prise en charge → En cours → En validation → Traité → Clôturée + Retournée + Rejetée)
- Check-up véhicule (checklist + décision automatique)
- Tournées, suivi GPS, documents avec alertes d'expiration
- Maintenance (tickets, interventions), budget trimestriel, analyses
- Alertes & blocages de véhicules, audit log, QR codes
- Hors ligne, bilingue FR/AR, thème clair/sombre

## Rôles et accès

| Rôle | Ce qu'il voit |
|---|---|
| **ADMIN** | Utilisateurs, véhicules, affectations, audit, documents, alertes, check-ups |
| **RS** | Budget, analyses, anomalies, tickets, documents, alertes, suivi, audit |
| **SL** | Alertes, suivi en temps réel, tournées |
| **CHAUFFEUR** | Déclarations, check-up, tournées, documents |
| **PRESTATAIRE** | Déclarations à traiter, tickets, anomalies |
| **MAINTENANCE** | Identique au Prestataire |

## Architecture

```
smartfleet_mobile/     Application mobile (Flutter, base SQLite locale)
backend/               Serveur « Agent IA » (Spring Boot, port 8082)
                       + Serveur vocal TTS/STT (Python, port 5000)
powerbi_rs/            Rapport Power BI (rôle RS)
docs/                  Documentation : guides client, technique, captures d'écran
scripts/               Tunnels adb (démonstration locale) : restore_tunnels.bat
dist/                  APK de livraison : SmartFleet.apk
```

## Mode online / offline de l'Agent IA vocal

| Situation | Écoute (STT) | Agent IA | Voix (TTS) | Déclaration |
|---|---|---|---|---|
| En ligne | Serveur vocal (5000) | Backend (8082) | Serveur vocal (5000) | Locale + sync |
| Téléphone branché au PC, sans Internet | STT natif (fallback) | Backend — déterministe sans OpenAI | Synthèse locale (fallback) | Locale + sync |
| Téléphone seul | STT natif | ✗ message de connexion | Synthèse locale (fallback) | Locale + sync |
