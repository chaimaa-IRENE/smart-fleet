# SmartFleet Mobile

Application mobile de gestion de flotte automobile 100% Flutter avec base de données SQLite locale.

## Fonctionnalités

- **Authentification** : Login email/mot de passe + biométrie (Face ID/Touch ID)
- **Gestion des déclarations** : Création, suivi, workflow complet (7 statuts)
- **Check-up véhicule** : Checklist 15 items + moteur de décision automatique
- **Tournées** : Planification, démarrage, terminaison, suivi distance
- **Tracking GPS** : Positions en temps réel, calcul distance Haversine, analytics
- **Documents** : Gestion avec alertes d'expiration (30 jours)
- **Maintenance** : Tickets, interventions, anomalies de checkup
- **Budget** : Budget trimestriel avec recalcul automatique, graphiques
- **Analytics** : Évolution des coûts, KPIs, carte de chaleur
- **Alertes & Blocages** : Alertes flotte, blocage/déblocage véhicule
- **Audit log** : Traçabilité des actions
- **QR Codes** : Génération et scan
- **Mode offline** : SQLite local-first, sync optionnelle
- **Bilingue FR/AR** : Support français et arabe
- **Thème clair/sombre** : Material 3

## Architecture

```
lib/
├── main.dart                    # Point d'entrée + sqflite_ffi init
├── config/                      # Configuration
│   ├── api_config.dart          # URL serveur (sync optionnelle)
│   ├── app_constants.dart       # Constantes (rôles, statuts, labels)
│   ├── app_sizes.dart           # Tailles et espacements
│   ├── theme.dart               # Thèmes Material 3
│   └── translations.dart        # Traductions FR/AR
├── database/                    # Couche données
│   ├── database_helper.dart     # SQLite schema (24 tables, v3)
│   └── dao/                     # 20 DAOs (CRUD par entité)
├── features/                    # Écrans par fonctionnalité
│   ├── admin/                   # Dashboard admin, users, vehicles, audit
│   ├── alerts/                  # Alertes & blocages
│   ├── analytics/               # Power BI, graphiques
│   ├── auth/                    # Login, dashboards par rôle
│   ├── budget/                  # Budget trimestriel
│   ├── checklist/               # Check-up véhicule
│   ├── checkup/                 # Checkups détaillés
│   ├── common/                  # Loading, error screens
│   ├── declaration/             # Déclarations, agent vocal
│   ├── documents/               # Documents véhicule
│   ├── maintenance/             # Tickets, interventions
│   ├── tournee/                 # Tournées
│   └── tracking/                # GPS tracking
├── models/                      # Modèles de données typés
│   ├── evolution_data.dart      # Données d'évolution (charts)
│   └── vehicle.dart             # Modèle véhicule
├── providers/                   # State management (Provider)
│   ├── auth_provider.dart       # Auth + user session
│   ├── declaration_provider.dart# Déclarations state
│   └── theme_provider.dart      # Thème + locale
├── routes/                      # Navigation
│   └── app_router.dart          # GoRouter avec guards par rôle
├── services/                    # Logique métier
│   ├── decision/                # Moteur de décision
│   ├── alert_service.dart       # Alertes
│   ├── anomalie_service.dart    # Anomalies
│   ├── audit_service.dart       # Audit log
│   ├── auth_service.dart        # Auth
│   ├── budget_service.dart      # Budget
│   ├── checklist_service.dart   # Checklist
│   ├── checkup_service.dart     # Checkups
│   ├── declaration_service.dart # Déclarations
│   ├── document_service.dart    # Documents
│   ├── export_service.dart      # Export CSV
│   ├── powerbi_service.dart     # Analytics
│   ├── qr_code_service.dart     # QR codes
│   ├── sync_service.dart        # Sync online/offline
│   ├── ticket_service.dart      # Tickets maintenance
│   ├── tournee_service.dart     # Tournées
│   ├── tracking_service.dart    # GPS tracking
│   ├── vehicle_service.dart     # Véhicules
│   └── voice_service.dart       # Reconnaissance vocale
└── widgets/                     # Widgets réutilisables
    ├── confirm_dialog.dart      # Dialogue de confirmation
    ├── dashboard_tile.dart      # Tuile dashboard
    ├── empty_state.dart         # État vide
    ├── evolution_chart.dart     # Graphique évolution
    ├── kpi_card.dart            # Carte KPI
    ├── loading_overlay.dart     # Overlay de chargement
    ├── month_selector.dart      # Sélecteur de mois
    ├── role_badge.dart          # Badge de rôle
    ├── section_header.dart      # Titre de section
    ├── status_badge.dart        # Badge de statut
    └── vehicle_selector.dart    # Sélecteur de véhicule
```

## Comptes de démonstration

| Email | Mot de passe | Rôle |
|-------|-------------|------|
| admin@smartfleet.fr | admin123 | ADMIN |
| rs_support@smartfleet.fr | support123 | RS |
| jean@smartfleet.fr | chauffeur123 | CHAUFFEUR |
| presta@smartfleet.fr | presta123 | PRESTATAIRE |

## Base de données

SQLite local (`smartfleet.db` v3) avec 24 tables :
- utilisateurs, vehicules, declarations, budget_trimestriel
- checklist_sessions, checklist_items, tournees
- checkups, checkup_details, anomalies_checkup
- documents_vehicule, tickets_maintenance, interventions
- fleet_alerts, vehicle_blockings, qr_codes
- tracking_history, audit_logs, departs_historique
- sync_queue, photos

## Démarrage

```bash
flutter pub get
flutter run
```

## Technologies

- **Flutter** 3.38+ / Dart 3.10+
- **SQLite** : sqflite + sqflite_common_ffi (desktop)
- **State management** : Provider
- **Navigation** : GoRouter
- **Charts** : fl_chart
- **GPS** : geolocator
- **Speech** : speech_to_text
- **Biometric** : local_auth
- **QR** : mobile_scanner
- **Connectivity** : connectivity_plus

## Rôles

| Rôle | Dashboard | Accès |
|------|-----------|-------|
| ADMIN | /admin | Users, Vehicles, Audit, Documents, Alerts, Checkups |
| RS | /rs | Budget, Analytics, Anomalies, Tickets, Documents, Alerts, Tracking, Audit |
| SL | /sl | Alerts, Tracking, Tournées |
| RPF/DRL | /rs | Même que RS |
| CHAUFFEUR | /chauffeur | Déclarations, Voice, Checklist, Tournées, Tracking, Documents |
| PRESTATAIRE | /prestataire | Tickets, Anomalies |
| MAINTENANCE | /prestataire | Même que Prestataire |
