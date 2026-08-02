# SmartFleet RS - Rapport Power BI (photocopie du module web Responsable Support)

## Contenu

```
powerbi_rs/
  SmartFleetRS.pbip/
    SmartFleetRS.SemanticModel/   # modele semantique (definition.pbism + model.tmdl)
    SmartFleetRS.Report/          # rapport (definition.pbir + report.json)
  dataset/                        # exports CSV (entetes exacts de la base H2)
  export_powerbi.py               # script de regeneration des CSV depuis la base de l'app
  test_powerbi_pipeline.py        # suite de tests app -> CSV -> logique Power BI (15 tests)
```

## Regenerer les donnees (apres chaque manipulation dans l'app)

Le rapport est alimente par `dataset/*.csv`. Ces fichiers sont maintenant **generes depuis la base SQLite de l'application** (`smartfleet.db`), pour que le rapport RS reflete les interactions reelles :

```
python export_powerbi.py
```

Options : `--db <chemin smartfleet.db>` (defaut : base de demonstration du projet), `--out <dossier>` (defaut : `dataset/`).

Puis dans Power BI Desktop : **Accueil > Actualiser**. Les 6 tables regenerees :
vehicules, users, declaration_incident, driver_checklists, anomalies_checkup, documents_vehicule.

> Sur un vrai telephone : recuperer `smartfleet.db` (dossier de l'app) via `adb pull`, puis `python export_powerbi.py --db <chemin recupere>`.

## Tester que le rapport reflete chaque interaction/modification

Une suite de tests verifie le pipeline complet **app -> CSV -> Power BI** pour chaque
interaction (FRONTEND : DAOs/services Flutter ; BACKEND : agent IA, file de sync, WebSocket) :

```
python test_powerbi_pipeline.py
```

Pour chaque scenario elle : (1) copie la base, (2) rejoue les memes ecritures SQL que
l'app, (3) relance `export_powerbi.py`, (4) verifie les CSV **et** la logique DAX du
`model.tmdl` (labels de statuts, segments du pie, statut d'expiration des documents,
mesures, score conduite...). Resultat : `15/15 passes`.

Couverture (15 tests) :
- Declarations : creation (En attente), prise en charge (En cours), soumission
  validation (duree/h), cloture + recalcul budget, retour/refus (pie).
- Checklists : conforme / non conforme (defauts JSON) / mesures PENDING-REPAIRE-VALIDATED.
- Documents : VALIDE / EXPIRE_BIENTOT / EXPIRE / MANQUANT + groupes d'expiration.
- Vehicules (donut), workflow anomalies + score conduite, users + budget.
- Backend : declaration VOICE_AI (agent IA), file de sync, flux WebSocket.

## Ouvrir le rapport

1. Installer **Power BI Desktop** (requis pour lire le format PBIP).
2. Ouvrir le dossier `SmartFleetRS.pbip` depuis Power BI Desktop (Fichier > Ouvrir, ou double-clic sur `SmartFleetRS.Report/definition.pbir`).
3. A l'ouverture, le modele recharge les donnees depuis `dataset/*.csv` (chemins absolus dans les partitions M de `model.tmdl`). Si le projet est deplace, mettre a jour le chemin dans `model.tmdl` (10 partitions `Csv.Document`).

## Pages

| Page | Contenu |
|---|---|
| Declarations | Budget trimestriel (Total / Utilise / Restant + barre Budget vs Reel), donut Repartition des declarations (5 segments web : En attente / En cours / En validation / Cloturees / Retournees ; statuts hors liste exclus comme le web), 6 cartes par statut (Total, En attente, En cours, En validation, Cloturees, Retournees), filtres (Statut, Type panne, Immatriculation, Date), table Declarations (ordre web : N. Demande, Date, Type, Criticite, Statut, Chauffeur, Immatriculation, Source) |
| Checklists | 4 cartes (Check-ups, En attente de validation, Reparations a valider, Non conformes) + table Checklists + table des check-ups PENDING (filtre STATUT=PENDING = badge "en attente de validation RS") |
| Documents RS | 5 cartes (Total, Valides, Expire bientot, Expires, Manquants), filtres (Type document, Statut, Vehicule), table Documents (colonne web : Vehicule, Type, N° Document, Emission, Expiration, Jours rest., Statut) + Notifications (EXPIRE_BIENTOT) |
| Historique Vehicule | Slicer Vehicule + compteurs (Check-ups, Anomalies, Documents) + detail Documents / Blocages / Check-ups / Anomalies / Departs / Tournees |
| Power BI | Page sombre (fond #0F172A, theme web) : 12 filtres web dans l'ordre exact du panneau de filtres (Periode, Tous sites, Tous vehicules, Tous chauffeurs, Tous statuts, Toutes criticites, Tous types panne, Toutes regions, Aucun prestataire, Toutes villes, Toutes annees, Tous mois), 8 KPI web (Total Vehicules, En Service, A l'Arret, En Maintenance, Anomalies Ouvertes, Check-ups (30j), Kilometrage Total, Taux Utilisation), donuts (statut vehicules avec labels web En Service/A l'Arret/Maintenance/Bloques, anomalies par source, Qualification), barres (Types d'incident, marques, documents par type), tables (Apercu vehicules, Alertes actives = EXPIRE+MANQUANT) |
| Vue d'ensemble | Dashboard 1280x720 organise (espacement 20 px, aucun debordement) : 4 KPI (Conformite, Consommation estimee L/100km, Score conduite, Alertes critiques), donut Repartition anomalies par categorie, courbe Kilometrage dans le temps, table dernieres declarations, colonne de filtres a droite (Date, Chauffeur, Vehicule, Categorie) |
| Performance vehicule | Courbe kilometrage journalier, histogramme Ralenti par vehicule (% vitesse < 5 km/h), jauge Consommation vs objectif, filtres (Vehicule, Chauffeur, Date) |
| Anomalies & reparations | Filtres (Criticite, Categorie, Vehicule, Chauffeur), table (Date, Categorie, Gravite, Description, Statut, Solution), histogramme Anomalies dans le temps, 3 donuts (par categorie, par marque, par element) |
| Chauffeurs | 3 KPI (Score conduite, Chauffeurs, Anomalies ouvertes), table Anomalies par chauffeur (nb, critiques, ouvertes, score), barre Top 5 chauffeurs |

## Fidelite au web (regles respectees)

- Aucun champ renomme : les colonnes portent les noms exacts des exports H2.
- Ordre des filtres et des colonnes identique au module web.
- Labels web exacts : statuts EN_ATTENTE/EN_COURS/EN_VALIDATION/CLOTURE/RETOURNEE/REFUSE -> "En attente / En cours / En validation / Cloture / Retourne / Refuse" ; statut documents VALIDE/EXPIRE_BIENTOT/EXPIRE/MANQUANT ; types de document ASSURANCE, CARTE_GRISE, VISITE_TECHNIQUE, VIGNETTE, AUTORISATION, CONTROLE_TACHYGRAPHE, ONSSA, METROLOGIQUE (5 obligatoires).
- Logique metier reproduite en DAX : statut document (0 j = expiré, <= 30 j = expire bientot), "non conforme" = COMPLETE + estConforme=false, badge checklists = REPAIRE ou (COMPLETE et non conforme), periode = 7j/30j/90j/1an par rapport a TODAY().

## Limites connues (donnees absentes de l'export H2)

- Tables non exportees par le script (absentes de `dataset/`) : vehicle_blocking, depart_historique, tournees -> leurs visuels restent vides (aucune donnee n'y transite dans les parcours de test).
- KPI web non calculables avec ces donnees (conso L/100km, vitesse moyenne, score IVMS, SLA, interventions prestataires, analyses IA, budget par mois) : mentionnes dans une note sur la page Power BI, non inventes.
- Actions cliquables du web (Details, Cloturer, Retourner, Prendre en charge, Budget, Valider, boutons) et recherche libre "Rechercher" : non reproductibles en lecture seule ; le statut se filtre/se consulte.
- Le filtre Periode s'applique aux visuels Declarations (colonne PERIODE), comme dans le web.
- Statuts declares : la base contient OUVERTE / CLOTURE / EN_VALIDATION / RESOLU. Le web ne compte dans son donut que ses 5 statuts fixes (En attente, En cours, En validation, Cloturees, Retournees) : le rapport reproduit exactement ce comportement (les lignes OUVERTE/RESOLU sont exclues du donut mais restent dans la table, comme le web).
- Filtres web "Toutes regions" et "Aucun prestataire" : listes vides dans le web (regions hardcodee [], aucune intervention en base) -> slicers vides reproduits a l'identique.
- Les filtres "Tous sites / Tous vehicules / Tous chauffeurs / Tous statuts" filtrent les vehicules (agence, immatriculation, statut brut) et utilisateurs (nom, ville) ; via les relations, ils croisent aussi les tables liees (comportement Power BI standard).
- Le select "Type panne" du web est fixe (Mecanique/Electrique/Caisse/Cabine/Securite/Autres) ; les donnees reelles contiennent d'autres libelles (Direction, Freins, Batterie...) : le slicer affiche les valeurs reelles de la base.
- Visuels web non reproduits faute de donnees/feuille de calcul equivalente : Taux d'utilisation (graphe), Histogramme anomalies ouvertes, Comparaison mensuelle, Evolution mensuelle, Budget vs Reel mensuel, Analyses IA, Interventions par prestataire, TOP 10 Vehicules (score IVMS), TOP 10 Chauffeurs.
- Le slicer "Reinitialiser" du web n'existe pas tel quel dans Power BI : vider les filtres via l'effaceur de chaque slicer.

## Source alternative

Les exports `dataset/*.csv` reprenaient a l'origine la base H2 (server TCP 9092). Ils sont desormais produits par `export_powerbi.py` depuis la base SQLite de l'application (voir section ci-dessus) : apres regeneration, **Actualiser** dans Power BI Desktop.
