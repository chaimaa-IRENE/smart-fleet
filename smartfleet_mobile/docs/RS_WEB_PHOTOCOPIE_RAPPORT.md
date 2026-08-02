# Rapport Photocopie — Module RS Web → Mobile

Source web : `PFE-CHAIMAA/frontend/src/components/ModernResponsableSupportDashboard.tsx` (1024 lignes) + `FleetDocumentManager.tsx` (1031 lignes) + `PowerBiDashboard/`
Mobile : `smartfleet_mobile/lib/features/auth/rs_dashboard.dart`, `rs_declarations.dart`, `rs_documents.dart`

Date : 31/07/2026

---

## 1. JSON structuré — Structure du module RS web

```json
{
  "role": "RS",
  "page": "Responsable Support",
  "sous_titre": "Gestion anomalies & declarations",
  "onglets": [
    {
      "id": "declarations",
      "label": "Declarations",
      "badge": "AVEC budget",
      "sections": [
        { "id": "budget", "titre": "Budget Trimestriel", "icone": "DollarSign",
          "bouton": "+ Nouveau Budget",
          "stats": ["Budget Total (MAD)", "Utilise (MAD)", "Restant (MAD)"],
          "barre_progression": true, "periode": "Periode: T{trimestre} {annee}",
          "modal_creation": { "champs": ["Annee", "Trimestre (T1-T4)", "Budget Total (MAD)"],
            "boutons": ["Annuler", "Creer"], "validation": "budgetTotal > 0, bouton Creer desactive si vide" } },
        { "id": "pie", "titre": "Repartition des declarations", "cliquable": true,
          "segments": [ {"label": "En attente", "couleur": "#f59e0b", "filtre": "EN_ATTENTE"},
            {"label": "En cours", "couleur": "#3b82f6", "filtre": "EN_COURS"},
            {"label": "En validation", "couleur": "#8b5cf6", "filtre": "EN_VALIDATION"},
            {"label": "Cloturees", "couleur": "#10b981", "filtre": "CLOTURE"},
            {"label": "Retournees", "couleur": "#ef4444", "filtre": "RETOURNEE"} ] },
        { "id": "stats", "cliquable": true, "items": ["Total", "En attente", "En cours", "En validation", "Cloturees", "Retournees"] },
        { "id": "filtres", "champs": ["Statut", "Type panne", "Immatriculation", "Date debut", "Date fin"],
          "boutons": ["Reinitialiser", "Auto (30s)"],
          "statuts": ["EN_ATTENTE", "EN_COURS", "EN_VALIDATION", "CLOTURE", "RETOURNEE", "REFUSE"],
          "types_panne": ["MECANIQUE", "ELECTRIQUE", "CAISSE", "CABINE", "SECURITE", "AUTRES"] },
        { "id": "tableau", "titre": "Declarations ({count})",
          "colonnes": ["N. Demande", "Date", "Type", "Criticite", "Statut", "Chauffeur", "Immatriculation", "Source", "Actions"],
          "ligne_etendue": ["Cout", "Duree reparation", "Actions realisees", "Contrat / Bon commande",
            "Date debut intervention", "Date reparation", "Pieces necessaires", "Qualification"],
          "actions": [
            { "id": "details", "toujours": true },
            { "id": "cloturer", "si_statut": "EN_VALIDATION", "modal": "confirm" },
            { "id": "retourner", "si_statut": "EN_VALIDATION", "modal": "motif obligatoire" },
            { "id": "budget_check", "si_statut": "EN_VALIDATION", "modal": "Verification Budget" },
            { "id": "prendre_charge", "si_statut": "EN_ATTENTE" }
          ] }
      ]
    },
    { "id": "checklists", "label": "Checklists", "badge": "count non-conformes + REPAIRE",
      "sections": [
        { "id": "non_conformes", "titre": "Checklists — Check-up Chauffeur",
          "colonnes": ["Vehicule", "Chauffeur", "Date", "Statut", "Conforme", "Actions"],
          "actions": [ {"id": "repare", "si_statut": "REPAIRE"}, {"id": "non_repare", "si_statut": "REPAIRE"},
            {"id": "reparation_effectuee", "si_statut": "COMPLETE et non conforme"} ] },
        { "id": "en_attente", "titre": "Check-ups en attente de validation RS",
          "colonnes": ["Vehicule", "Chauffeur", "Date", "Conforme", "Actions"], "action": "Valider" }
      ] },
    { "id": "powerbi", "label": "Power BI", "composant": "PowerBiDashboard" },
    { "id": "documents", "label": "Documents RS", "composant": "FleetDocumentManager",
      "types_documents": [ {"value": "ASSURANCE", "mois": 12, "obligatoire": true},
        {"value": "CARTE_GRISE", "mois": 120, "obligatoire": true},
        {"value": "VISITE_TECHNIQUE", "mois": 12, "obligatoire": true},
        {"value": "VIGNETTE", "mois": 12, "obligatoire": false},
        {"value": "AUTORISATION", "mois": 6, "obligatoire": false},
        {"value": "CONTROLE_TACHYGRAPHE", "mois": 24, "obligatoire": true},
        {"value": "ONSSA", "mois": 24, "obligatoire": true},
        {"value": "METROLOGIQUE", "mois": 12, "obligatoire": false} ],
      "statuts_doc": ["VALIDE", "EXPIRE_BIENTOT (<=30j)", "EXPIRE", "MANQUANT"],
      "crud": ["ajouter", "editer", "archiver", "pieces jointes", "historique"] },
    { "id": "vehicleHistory", "label": "Historique Vehicule",
      "sections": ["Fiche vehicule + compteurs (Checkups/Anomalies/Documents)",
        "Infos blocage (Date blocage / Date deblocage / Raison / Departs-Tournees)",
        "Documents reglementaires (ASSURANCE, ONSSA, VISITE_TECHNIQUE, CARTE_GRISE, METROLOGIQUE)",
        "Check-ups Chauffeur (10 items: Pneus, Freins, Feux, Extincteur, Documents, Carrosserie, Huile, Batterie, Essuie-glaces, Ceintures + defauts + commentaire + reparations + validePar + signature)",
        "Anomalies (statut, element-description, date, photo)",
        "Historique Blocages/Deblocages", "Departs", "Tournees"] }
  ]
}
```

## 2. Flow RS complet

```
Login → Dashboard RS
  └─ Onglet Declarations
      ├─ Carte Budget Trimestriel → [+ Nouveau Budget] → Modal (Annee, Trimestre, Total) → POST /api/budget/create → toast
      ├─ Pie chart (clic segment → filtre statut + scroll tableau)
      ├─ Stats (clic carte → filtre statut)
      ├─ Filtres (Statut / Type panne / Immatriculation / Date debut / Date fin / Reinitialiser / Auto)
      ├─ Tableau Declarations
      │   ├─ Clic ligne → detail etendu (8 champs)
      │   └─ Actions:
      │       ├─ Details → modal detail complet
      │       ├─ EN_VALIDATION: Cloturer → PUT /close (confirm) | Retourner → PUT /return (motif) | Budget → GET /admin/budget/check
      │       └─ EN_ATTENTE: Prendre en charge → PUT /takeCharge
      └─ Auto-refresh 30s (toggle Auto)
  └─ Onglet Checklists
      ├─ Non-conformes/REPAIRE: Valider → POST /validate-repair (debloque vehicule) | Rejeter → POST /reject-repair | Reparation effectuee → POST /repair
      └─ PENDING: Valider → POST /validate-pending
  └─ Onglet Power BI → PowerBiDashboard
  └─ Onglet Documents RS → FleetDocumentManager (CRUD docs vehicule + reglementaires)
  └─ Onglet Historique Vehicule
      ├─ Selecteur vehicule → GET /vehicles/{id}/history (+ docs, declarations, blocked-vehicules)
      └─ Sections: fiche, blocage, docs, checkups, anomalies, blocages, departs, tournees
```

## 3. Vérification de conformité (web → mobile)

| Element web | Mobile | Statut |
|---|---|---|
| Onglet Declarations + badge "AVEC budget" | Onglet Déclarations | ✔ |
| Carte Budget Trimestriel (3 stats + barre + Periode) | `_buildBudgetSection` identique | ✔ |
| Modal budget (Annee, Trimestre T1-T4, Total, Annuler/Creer) | Ajouté champ Annee + labels T1 (Jan-Mar)... | ✔ (corrigé ce jour) |
| Pie chart cliquable | `_buildDeclPieChart` | ✔ |
| 6 stats cliquables | `_buildDeclStats` | ✔ |
| Filtres (Statut, Type panne, Immat, dates, Reinit, Auto) | `RsDeclarations` | ✔ |
| Tableau 9 colonnes / carte | Carte avec tous les champs + **Date ajoutée** | ✔ (corrigé ce jour) |
| Detail etendu 8 champs | Card étendue 8 champs | ✔ |
| Actions (Details/Cloturer/Retourner/Prendre en charge) | Identiques | ✔ |
| Modal Verification Budget | **Non restauree** (decision utilisateur) | ✓ assumé |
| Checklists 2 cartes + actions | `_buildChecklistsTab` | ✔ |
| Power BI | `PowerBiView` | ✔ |
| Documents: 8 types + statuts + CRUD | `rs_documents.dart` identique | ✔ |
| Historique: 8 sections | `_buildVehicleHistoryTab` | ✔ + icônes par type doc ajoutées |
| Onglet Budget (ajouté avant) | **Supprimé** (decision utilisateur) | ✓ assumé |
| Onglet Anomalies (non web) | **Conservé** (decision utilisateur) | ✓ assumé |

## 4. Composants UI mobiles

- `_buildBudgetSection` / `_BudgetLabelValue` / `_StatusBadge` — carte budget
- `_buildDeclPieChart` / `_PieData` — camembert
- `_buildDeclStats` — cartes stats
- `RsDeclarations` — filtres + cartes déclarations + modals (Détail/Clôturer/Retourner)
- `_buildChecklistsTab` / `_buildChecklistRow` / `_buildPendingChecklistRow` — checklists
- `RsDocuments` — documents (CRUD + pièces jointes + historique)
- `PowerBiView` — Power BI
- `_buildVehicleHistoryTab` + `_buildHistorySection` + `_histCountCard` + `_histInfoCard` — historique
- `_buildCreateBudgetModal` / `_handleCreateBudget` — création budget (API → fallback local)

## 5. API utilisées (web = mobile)

`/api/declarations`, `/api/vehicles`, `/api/checkups`, `/api/fleet/checklist/*`, `/api/budget/active`, `/api/budget/create`, `/api/documents-vehicule`, `/api/documents-reglementaires`, `/admin/budget/check` (modal supprimée), `/admin/budget/decision` (modal supprimée)
