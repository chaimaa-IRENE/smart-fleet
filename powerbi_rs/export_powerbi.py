#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Export SmartFleet RS — exporte la base SQLite de l'application vers les CSV
Power BI (dataset/*.csv) pour que le rapport RS reflète les interactions réelles.

Usage :
    python export_powerbi.py --db <chemin/smartfleet.db> --out <dossier/dataset>

Sans arguments, il utilise la base de démonstration et le dossier dataset du projet.
Après chaque manipulation dans l'app : relancer ce script, puis Actualiser dans Power BI Desktop.
"""
import argparse
import csv
import json
import os
import sqlite3
import sys

FRENCH_MONTHS = {1: "Janvier", 2: "Février", 3: "Mars", 4: "Avril", 5: "Mai", 6: "Juin",
                 7: "Juillet", 8: "Août", 9: "Septembre", 10: "Octobre", 11: "Novembre", 12: "Décembre"}


def b(v):
    """1/0 SQLite -> TRUE/FALSE (format des exports H2), vide si None."""
    if v is None:
        return ""
    return "TRUE" if v else "FALSE"


def write_csv(path, header, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, quoting=csv.QUOTE_ALL)
        w.writerow(header)
        for row in rows:
            w.writerow(["" if v is None else v for v in row])
    print(f"  -> {os.path.basename(path)} : {len(rows)} ligne(s)")


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    default_db = os.path.join(
        here, "..", "smartfleet_mobile", ".dart_tool", "sqflite_common_ffi", "databases",
        ".dart_tool", "sqflite_common_ffi", "databases", "scan_before_checkup", "smartfleet.db")
    parser = argparse.ArgumentParser(description="Export SQLite -> CSV Power BI RS")
    parser.add_argument("--db", default=default_db, help="Chemin de la base SQLite de l'app")
    parser.add_argument("--out", default=os.path.join(here, "dataset"),
                        help="Dossier de sortie des CSV (défaut : dataset/)")
    args = parser.parse_args()

    if not os.path.exists(args.db):
        print(f"ERREUR : base introuvable -> {args.db}")
        print("Précisez le chemin avec --db. Sur téléphone : récupérez smartfleet.db via adb.")
        sys.exit(1)

    conn = sqlite3.connect(args.db)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    def rows(sql, params=()):
        cur.execute(sql, params)
        return [dict(r) for r in cur.fetchall()]

    # ---------------------------------------------------------------- VEHICULES
    vehicules_header = ["ID", "AGENCE", "ANNEE", "ARCHIVED", "ARCHIVED_AT", "ARCHIVED_BY", "BLOQUE_PAR",
                        "BRANCH_CODE", "CARBURANT", "CHAUFFEUR_ID", "CHAUFFEUR_NOM", "CONFORME",
                        "DATE_AFFECTATION", "DATE_BLOCAGE", "DATE_DEBLOCAGE", "DEBLOQUE_PAR",
                        "DERNIERE_LATITUDE", "DERNIERE_LONGITUDE", "DERNIERE_POSITION_DATE",
                        "DERNIERE_VITESSE", "DOCUMENTS_DISPONIBLES", "GEOTAB_ID", "IMMATRICULATION",
                        "KILOMETRAGE", "MARQUE", "MODELE", "MOTEUR_ALLUME", "NIVEAU_CARBURANT", "NOTES",
                        "RAISON_BLOCAGE", "STATUT", "TOURNEE", "TRUCK_NUMBER", "TYPE", "VEHICLE_ID"]
    vrows = []
    for v in rows("SELECT * FROM vehicules"):
        vrows.append([
            v["id"], v["agence"], v["annee"], b(v["archived"]), v["archivedAt"], v["archivedBy"], "",
            v["branche"], v["carburant"], v["chauffeurId"], v["chauffeurNom"], b(v["conforme"]),
            v["dateAffectation"], "", "", "", v["derniereLatitude"], v["derniereLongitude"],
            v["dernierePositionDate"], v["derniereVitesse"], "", v["geotabId"], v["immatriculation"],
            v["kilometrage"], v["marque"], v["modele"], b(v["moteurAllume"]), v["niveauCarburant"],
            v["notes"], "", v["statut"], "", v["truckNumber"], v["type"], v["vehicleId"],
        ])
    write_csv(os.path.join(args.out, "vehicules.csv"), vehicules_header, vrows)

    # ---------------------------------------------------------------- UTILISATEURS
    users_header = ["ID", "BRANCH_CODE", "CELLULAR_PHONE", "CREATED_BY_ROLE_ID", "CREATION_DATE", "EMAIL",
                    "EMAIL_VALIDATED", "FACE_DESCRIPTOR", "FACE_REGISTERED", "FIRSTNAME", "HOLD_PERSON",
                    "HOLD_REASON", "HOLD_RELATED_ROLE", "HOLD_ROLE_BRANCH", "LAST_CONNECTION_DATE",
                    "LAST_UPDATE", "NAME", "PASSWORD", "PASSWORD_DIGEST", "PASSWORD_EXPIRY_DATE",
                    "PASSWORD_RESET_TOKEN", "PASSWORD_RESET_TOKEN_EXPIRES_AT", "PERSON_CODE", "PHONE",
                    "PROFILE_CODE", "ROLE", "ROLE_BRANCH", "ROLE_CODE", "ROLE_DEPARTEMENT", "STATUS",
                    "USERNAME", "VALIDATION_CODE", "VALIDATION_CODE_EXPIRES_AT", "VILLE"]
    urows = []
    for u in rows("SELECT * FROM utilisateurs"):
        urows.append([
            u["id"], u["branchCode"], u["telephone"], "", u["dateCreation"], u["email"], "", "", "",
            u["prenom"], "", "", "", "", "", "", u["nom"], u["motDePasse"], "", "", "", "",
            u["matricule"], u["telephone"], "", u["role"], "", "", "", ("ACTIF" if u["actif"] else "INACTIF"),
            u["email"], "", "", "",
        ])
    write_csv(os.path.join(args.out, "users.csv"), users_header, urows)

    # ---------------------------------------------------------------- DECLARATIONS
    decl_header = ["ID_INCIDENT", "ACTIONS_REALISEES", "AUDIO", "BUDGET_MENSUEL", "CATEGORIE",
                   "CHAUFFEUR_ID", "CHAUFFEUR_MATRICULE", "CHAUFFEUR_NOM", "CONTRAT_BON_COMMANDE",
                   "COUT_PROBLEME", "CRITICITE", "DATE_DEBUT_INTERVENTION", "DATE_HEURE",
                   "DATE_RECLAMATION", "DATE_REPARATION", "DESCRIPTION_ARABE", "DESCRIPTION_FRANCAIS",
                   "DETAIL_ELEMENT", "DUREE_REPARATION", "ELEMENT_VEHICULE", "ETAT", "KILOMETRAGE",
                   "LIEU", "LIEU_INCIDENT_ARABE", "LIEU_INCIDENT_FRANCAIS", "LOCATION", "MOIS",
                   "MOTIF_REFUS", "NUMERO_DEMANDE", "NUMERO_ORDRE_CAMION", "PHOTO", "PHOTO_URL",
                   "PIECES_NECESSAIRES", "QUALIFICATION", "SLA", "SOURCE", "STATUT", "TOURNEE",
                   "TYPE_PANNE", "TYPE_PANNE_ARABE", "TYPE_PANNE_FRANCAIS", "VEHICULE_ID",
                   "VEHICULE_IMMATRICULATION", "VEHICULE_MARQUE", "VEHICULE_MODELE", "VEHICULE_TYPE",
                   "VIDEO", "VIDEO_URL"]
    drows = []
    for d in rows("SELECT * FROM declarations"):
        mois = ""
        if d["dateCreation"]:
            try:
                mois = FRENCH_MONTHS.get(int(d["dateCreation"][5:7]), "")
            except Exception:
                mois = ""
        drows.append([
            d["id"], d["actionsRealisees"], "", "", d["categorie"], d["chauffeurId"], "",
            d["chauffeurNom"], d["contratBonCommande"], "", d["criticite"], d["dateDebutIntervention"],
            d["dateCreation"], d["dateCreation"], d["dateReparation"], "", d["description"],
            d["detailElement"], d["dureeReparation"], d["elementVehicule"], d["etat"], d["kilometrage"],
            d["lieu"], "", d["lieu"], d["lieu"], mois, d["motifRejet"], d["numeroDemande"], "", "", "",
            d["piecesNecessaires"], d["qualification"], "", d["source"], d["statut"], "",
            d["typePanne"], "", d["typePanne"], d["vehiculeId"], d["immatriculation"],
            d["vehiculeMarque"], d["vehiculeModele"], d["vehiculeType"], d["video"], "",
        ])
    write_csv(os.path.join(args.out, "declaration_incident.csv"), decl_header, drows)

    # ---------------------------------------------------------------- ANOMALIES CHECKUP
    anom_header = ["ID", "ANOMALIE_CODE", "ASSIGNED_TO", "CATEGORIE", "CHAUFFEUR_ID", "CHAUFFEUR_NOM",
                   "CHECKUP_CODE", "CHECKUP_ID", "CREATED_AT", "CRITICITE", "DATE_DETECTION",
                   "DATE_PRISE_EN_CHARGE", "DATE_REPARATION", "DATE_VALIDATION", "DESCRIPTION", "ELEMENT",
                   "OBSERVATION", "PHOTO_URL", "REPARE_PAR", "RESOLUTION_NOTES", "SOURCE", "STATUT",
                   "TASK_ID", "UPDATED_AT", "VALIDE_PAR", "VEHICULE_ID", "VEHICULE_IMMATRICULATION"]
    arows = []
    for a in rows("SELECT * FROM anomalies_checkup"):
        arows.append([
            a["id"], a["code"], a["assignedTo"], a["categorie"], a["chauffeurId"], a["chauffeurNom"],
            a["checkupCode"], a["checkupId"], a["createdAt"] or a["dateCreation"], a["criticite"],
            a["dateCreation"], a["datePriseEnCharge"], a["dateReparation"], a["dateValidation"],
            a["description"], a["element"], a["observation"], a["photoUrl"], a["reparePar"],
            a["resolutionNotes"], a["source"], a["statut"], a["taskId"], a["updatedAt"],
            a["validePar"], a["vehiculeId"], a["immatriculation"],
        ])
    write_csv(os.path.join(args.out, "anomalies_checkup.csv"), anom_header, arows)

    # ---------------------------------------------------------------- CHECKLISTS (sessions + items pivotes)
    cl_header = ["ID", "BATTERIE", "CARROSSERIE", "CEINTURES_SECURITE", "CHAUFFEUR_ID", "CHAUFFEUR_MATRICULE",
                 "CHAUFFEUR_NOM", "COMMENTAIRE_GENERAL", "DATE_CHECKLIST", "DATE_VALIDATION", "DEFAUTS_JSON",
                 "DOCUMENTS", "ESSUIE_GLACES", "EST_CONFORME", "EXTINCTEUR", "FEEDBACK", "FEUX", "FREINS",
                 "HUILE_NIVEAU", "MESSAGE_ALERTE_ARABE", "MOTIF_REFUS", "PNEUS", "POST_REPAIR",
                 "REPARATIONS_JSON", "SIGNATURE", "STATUT", "TOURNEE_ID", "VALIDE_PAR", "VEHICULE_ID",
                 "VEHICULE_IMMATRICULATION"]
    item_col_map = [
        ("BATTERIE", "Batterie"), ("CARROSSERIE", "Carrosserie"), ("CEINTURES_SECURITE", "Ceintures sécurité"),
        ("DOCUMENTS", "Documents"), ("ESSUIE_GLACES", "Essuie-glaces"), ("EXTINCTEUR", "Extincteur"),
        ("FEUX", "Feux (Éclairage)"), ("FREINS", "Freins"), ("HUILE_NIVEAU", "Niveau d'huile"), ("PNEUS", "Pneus"),
    ]
    clrows = []
    for s in rows("SELECT * FROM checklist_sessions"):
        items = rows("SELECT nom, value, defauts, commentaire FROM checklist_items WHERE sessionId=?",
                     (s["id"],))
        item_map = {i["nom"]: i for i in items}
        item_vals = {}
        for col, nom in item_col_map:
            item_vals[col] = item_map.get(nom, {}).get("value")
        defauts = [{"nom": i["nom"], "commentaire": i["commentaire"] or ""}
                   for i in items if (i["value"] == 0 or i["defauts"])]
        clrows.append([
            s["id"], item_vals.get("BATTERIE", ""), item_vals.get("CARROSSERIE", ""),
            item_vals.get("CEINTURES_SECURITE", ""), s["chauffeurId"], s["chauffeurMatricule"],
            s["chauffeurNom"], s["commentaireGeneral"], s["date"], s["dateValidation"],
            json.dumps(defauts, ensure_ascii=False) if defauts else "",
            item_vals.get("DOCUMENTS", ""), item_vals.get("ESSUIE_GLACES", ""), b(s["conforme"]),
            item_vals.get("EXTINCTEUR", ""), s["feedback"], item_vals.get("FEUX", ""),
            item_vals.get("FREINS", ""), item_vals.get("HUILE_NIVEAU", ""), s["messageAlerteArabe"],
            s["motifRefus"], item_vals.get("PNEUS", ""), b(s["postRepair"]), s["reparationsJson"],
            s["signature"], s["statut"], s["tourneeId"], s["validePar"], s["vehiculeId"], s["immatriculation"],
        ])
    write_csv(os.path.join(args.out, "driver_checklists.csv"), cl_header, clrows)

    # ---------------------------------------------------------------- DOCUMENTS VEHICULE
    docs_header = ["ID", "ARCHIVED", "ARCHIVED_AT", "ARCHIVED_BY", "CREATED_AT", "DATE_EMISSION",
                   "DATE_EXPIRATION", "EST_DISPONIBLE", "FICHIER_URL", "IMPORTE_PAR", "NOTES",
                   "NUMERO_DOCUMENT", "TYPE_DOCUMENT", "UPDATED_AT", "VEHICULE_ID", "VEHICULE_IMMATRICULATION"]
    dows = []
    for doc in rows("SELECT * FROM documents_vehicule"):
        dows.append([
            doc["id"], b(doc["archived"]), doc["archivedAt"], doc["archivedBy"], doc["createdAt"],
            doc["dateEmission"], doc["dateExpiration"], b(doc["estDisponible"]), doc["fichierUrl"],
            doc["importePar"], doc["notes"], doc["numeroDocument"], doc["typeDocument"], doc["updatedAt"],
            doc["vehiculeId"], doc["immatriculation"],
        ])
    write_csv(os.path.join(args.out, "documents_vehicule.csv"), docs_header, dows)

    conn.close()
    print("\nOK : exports régénérés. Actualisez le rapport dans Power BI Desktop (Accueil > Actualiser).")


if __name__ == "__main__":
    main()
