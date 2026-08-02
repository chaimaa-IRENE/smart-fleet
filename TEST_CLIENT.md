# Guide de test SmartFleet — Étape par étape

> Ce guide vous permet de **tester toutes les fonctions de l'application** comme un utilisateur normal, sans connaissance technique.
> Chaque étape indique **ce qu'il faut faire** et **ce que vous devez voir** (résultat attendu).
> Si un résultat attendu n'apparaît pas, notez-le : c'est une anomalie à signaler au fournisseur.

> **Avant de tester :** l'application doit déjà être **installée et ouverte** sur votre téléphone.
> Si ce n'est pas encore fait, suivez d'abord le guide d'installation : **`docs/GUIDE_CLIENT_SIMPLE.md`** (aucun outil requis, ~5 minutes).

---

## Avant de commencer

### Connexions de test

| Profil | Adresse e-mail | Mot de passe |
|---|---|---|
| Administrateur | `admin@smartfleet.fr` | `admin123` |
| Chauffeur | `jean@smartfleet.fr` | `chauffeur123` |
| Prestataire | `presta@smartfleet.fr` | `presta123` |
| Responsable Support | `rs_support@smartfleet.fr` | `support123` |

> **Conseil :** pour tester tous les rôles, il suffit de vous **déconnecter** puis de vous **reconnecter** avec un autre compte.

### Étiquette de résultat

Chaque scénario se termine par : ✅ **Résultat attendu :** *(ce que vous devez voir)*.

---

## 1. Se connecter

1. Ouvrir l'application.
2. Saisir `jean@smartfleet.fr` et le mot de passe `chauffeur123`.
3. Toucher **Se connecter**.
4. ✅ **Résultat attendu :** vous arrivez sur l'**accueil Chauffeur**, avec votre nom en haut et 3 indicateurs (Déclarations, Véhicules, Synchronisation).

---

## 2. Tester en tant que Chauffeur

### 2.1 Créer une déclaration d'incident (scénario complet)

1. Sur l'accueil, toucher **« + Nouvelle déclaration »**.
2. **Étape 1 — Localisation :** toucher **« GPS automatique »** (autoriser la localisation si demandé). La position se remplit. Sinon, taper une ville dans le champ « Lieu », ex. `Casablanca`.
3. Toucher **Suivant**.
4. **Étape 2 — Véhicule :** choisir un véhicule dans la liste déroulante (seuls vos véhicules affectés doivent apparaître). Saisir le **kilométrage** si vous le connaissez.
5. Toucher **Suivant**.
6. **Étape 3 — Détails :**
   - **Type de panne** : choisir, ex. `Moteur`.
   - **Criticité** : choisir, ex. `Non bloquant`.
   - **Description** : écrire, ex. `Le moteur émet une fumée anormale`.
   - (facultatif) **Source**, **Élément véhicule**, **Catégorie**, **Photo / Vidéo**.
7. Toucher **Créer**.
8. ✅ **Résultat attendu :** un message « Déclaration créée » s'affiche, puis vous revenez à l'accueil.

### 2.2 Vérifier la liste des déclarations

1. Sur l'accueil, toucher **« Déclarations »**.
2. ✅ **Résultat attendu :** la déclaration créée apparaît avec le statut **« En attente »**, sa date, le véhicule et la description.

### 2.3 Faire un check-up véhicule

1. Sur l'accueil, toucher **« Check-up »**.
2. Sélectionner un véhicule.
3. Renseigner les points de contrôle (freins, pneus, éclairage, etc.) — une croix ✅ pour « conforme », ❌ pour « non conforme ».
4. Terminer le check-up.
5. ✅ **Résultat attendu :** un résultat de conformité s'affiche (conforme / non conforme) avec les anomalies éventuelles.

### 2.4 Consulter les documents

1. Sur l'accueil, toucher **« Documents »**.
2. ✅ **Résultat attendu :** les documents des véhicules (assurance, carte grise, visite technique) avec un statut couleur : 🟢 Valide / 🟡 Expire bientôt / 🔴 Expiré.

---

## 3. Tester en tant que Prestataire

### 3.1 Prendre en charge la déclaration

1. Déconnexion, puis connexion avec **Prestataire** (`presta@smartfleet.fr` / `presta123`).
2. L'accueil affiche des indicateurs : **Total**, **En attente**, **En cours**, **Validation**, **Traitées**, **Clôturées**, **Retournées**.
3. La déclaration créée par le chauffeur doit apparaître avec le badge **« En attente »**.
4. Toucher **« Prendre en charge »**, puis **« Commencer »**.
5. ✅ **Résultat attendu :** le statut passe à **« En cours »**.

### 3.2 Saisir le rapport d'intervention

1. Toucher **« Rapport »** (ou **« Mode Stepper »**).
2. Renseigner les actions réalisées, la qualification et le coût.
3. Soumettre.
4. ✅ **Résultat attendu :** le statut passe à **« En validation »**.

### 3.3 Valider puis clôturer

1. Toucher **« Valider »**.
2. ✅ **Résultat attendu :** le statut passe à **« Traité »**.
3. Toucher **« Clôturer »** (confirmer si demandé).
4. ✅ **Résultat attendu :** le statut passe à **« Clôturée »**. **Le cycle de l'incident est terminé.**

### 3.4 Tester le retour de déclaration (facultatif)

1. Reprendre une déclaration **« En validation »** et toucher **« Retourner »**, en indiquant un motif.
2. ✅ **Résultat attendu :** le statut passe à **« Retournée »** avec le motif affiché en rouge.

---

## 4. Tester en tant que Responsable Support (RS)

### 4.1 Tableau des anomalies

1. Déconnexion, puis connexion avec **RS** (`rs_support@smartfleet.fr` / `support123`).
2. ✅ **Résultat attendu :** 7 indicateurs (Détectées, En réparation, Réparées, Validées, Non réparables, Véhicules bloqués, Taux de réparation).
3. Ouvrir l'onglet **« Anomalies »** : les anomalies issues des check-ups apparaissent avec leur statut.

### 4.2 Budget

1. Ouvrir l'onglet **« Déclarations »** puis la section **Budget trimestriel**.
2. ✅ **Résultat attendu :** le budget affiche Total, Utilisé et Restant, avec une barre de progression.

### 4.3 Documents légaux

1. Ouvrir l'onglet **« Documents »**, sélectionner un véhicule.
2. ✅ **Résultat attendu :** les documents s'affichent avec leur statut couleur (Vert / Jaune / Rouge).

---

## 5. Tester en tant qu'Administrateur

### 5.1 Gestion des utilisateurs

1. Déconnexion, puis connexion avec **Admin** (`admin@smartfleet.fr` / `admin123`).
2. Toucher **« Utilisateurs »**.
3. ✅ **Résultat attendu :** 4 indicateurs (Total, Actifs, Inactifs, Chauffeurs) et la liste des utilisateurs avec recherche.
4. **Modifier** un utilisateur (icône stylo) : le formulaire s'ouvre avec les sections Identité / Contact / Accès & Sécurité. Annuler sans enregistrer (ou enregistrer, puis remettre les valeurs).

### 5.2 Gestion des véhicules

1. Toucher **« Véhicules »**.
2. ✅ **Résultat attendu :** 4 indicateurs (Total, Disponibles, Bloqués, Non conformes) et la liste des véhicules.
3. Tester la **recherche** par immatriculation (ex. `AA-123-BC`).

### 5.3 Affectations chauffeur ↔ véhicule

1. Toucher **« Affectations »**.
2. ✅ **Résultat attendu :** le texte d'information *« 1 chauffeur peut avoir plusieurs camions. Un camion ne peut appartenir qu'à un seul chauffeur. »* et 3 indicateurs (Total, Assignés, Libres).
3. Pour un véhicule **libre**, choisir un chauffeur dans la liste déroulante → le véhicule devient **assigné**.
4. Pour un véhicule **assigné**, toucher **« Désaffecter »** (rouge) et confirmer → le véhicule redevient **libre**.

### 5.4 Historique (Audit Log)

1. Toucher **« Audit Log »**.
2. ✅ **Résultat attendu :** les connexions (succès/échec), avec utilisateur, date et méthode.

---

## 6. Scénario de bout en bout (récapitulatif en 10 étapes)

| # | Rôle | Action | Statut après |
|---|---|---|---|
| 1 | Chauffeur | Créer une déclaration (moteur, Casablanca) | En attente |
| 2 | Prestataire | Prendre en charge | En cours |
| 3 | Prestataire | Saisir le rapport (actions + coût) | En validation |
| 4 | Prestataire | Valider | Traité |
| 5 | Prestataire | Clôturer | **Clôturée** |
| 6 | Admin | Vérifier l'historique (Audit Log) | — |

✅ **Ce scénario valide l'ensemble du parcours de déclaration d'incident.**

---

## 7. Vérifications finales — checklist de recette

Cochez chaque point validé :

- [ ] Connexion possible avec les 4 comptes (`admin`, `jean`, `presta`, `rs_support`)
- [ ] Un mauvais mot de passe est **refusé** avec un message d'erreur
- [ ] Le chauffeur ne voit que **ses** véhicules affectés
- [ ] Création d'une déclaration en 3 étapes
- [ ] La déclaration passe par tous les statuts : En attente → En cours → En validation → Traité → Clôturée
- [ ] Retour de déclaration possible avec motif
- [ ] Check-up véhicule : résultat conforme / non conforme
- [ ] Documents : statuts Valide / Expire bientôt / Expiré
- [ ] Admin : gestion des utilisateurs, véhicules, affectations, audit
- [ ] RS : indicateurs, budget, documents
- [ ] Aucun plantage (l'application ne se ferme pas toute seule) lors des manipulations

---

## 8. (Équipe technique) Vérifications automatiques et fabrication de l'APK

> Ces étapes nécessitent des outils (Flutter, etc.) : elles sont détaillées dans le **`docs/GUIDE_TECHNIQUE.md`**.

- **22 tests fonctionnels** passent (`flutter test`)
- `flutter analyze` : **0 erreur**
- Fabrication du fichier d'installation : `flutter build apk --release` → copier `app-release.apk` en le renommant **`SmartFleet.apk`** dans le dossier `dist` de la livraison

---

## 9. Exemples d'écrans (illustrations)

> Les images de chaque écran sont fournies dans le dossier **`docs/screenshots/`** de la livraison.

| N° | Écran | Fichier image |
|---|---|---|
| 01 | Écran de connexion | `01-connexion.png` |
| 02 | Accueil Chauffeur | `02-accueil-chauffeur.png` |
| 03 | Création de déclaration | `03-declaration.png` |
| 04 | Liste des déclarations | `04-liste-declarations.png` |
| 05 | Accueil Prestataire | `05-accueil-prestataire.png` |
| 06 | Accueil Admin | `06-accueil-admin.png` |
| 07 | Accueil RS | `07-accueil-rs.png` |
