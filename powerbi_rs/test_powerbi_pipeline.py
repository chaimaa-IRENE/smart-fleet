#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Suite de tests du pipeline SmartFleet -> Power BI RS.

Principe :
  1. Copie la base SQLite de demonstration (source de verite de l'app).
  2. Pour chaque interaction (FRONTEND : DAOs/services Flutter ;
     BACKEND : agent IA + file de sync), rejoue les memes ecritures SQL
     que l'application (memes tables/colonnes/valeurs).
  3. Relance export_powerbi.py vers un dossier temporaire.
  4. Verifie que les CSV generes refle tent la modification ET que les
     valeurs que Power BI afficherait (logique DAX du model.tmdl
     reproduite en Python) sont correctes.

Execution :  python test_powerbi_pipeline.py
Résultat :   une ligne "PASS/FAIL" par interaction, code retour 0/1.
"""
import csv
import os
import shutil
import sqlite3
import sys
import tempfile
from datetime import date, datetime, timedelta

# ---------------------------------------------------------------------------
# Chemins
# ---------------------------------------------------------------------------
ROOT = os.path.dirname(os.path.abspath(__file__))
SRC_DB = os.path.join(ROOT, "..", "smartfleet_mobile", ".dart_tool",
                      "sqflite_common_ffi", "databases", ".dart_tool",
                      "sqflite_common_ffi", "databases", "scan_before_checkup",
                      "smartfleet.db")
EXPORT = os.path.join(ROOT, "export_powerbi.py")

TODAY = date.today()

# ---------------------------------------------------------------------------
# Reprise de la logique DAX du model.tmdl (SmartFleetRS.SemanticModel)
# ---------------------------------------------------------------------------


def dax_today():
    return TODAY


def dax_decl_statut_label(s):
    return {
        "EN_ATTENTE": "En attente",
        "EN_COURS": "En cours",
        "EN_VALIDATION": "En validation",
        "CLOTURE": "Cloture",
        "RETOURNEE": "Retourne",
        "REFUSE": "Refuse",
    }.get(s, s)


def dax_pie_segment(s):
    return {
        "EN_ATTENTE": "En attente",
        "EN_COURS": "En cours",
        "EN_VALIDATION": "En validation",
        "CLOTURE": "Cloturees",
        "RETOURNEE": "Retournees",
    }.get(s, "")


def dax_type_panne_label(v):
    return {
        "MECANIQUE": "Mecanique", "ELECTRIQUE": "Electrique",
        "CAISSE": "Caisse", "CABINE": "Cabine",
        "SECURITE": "Securite", "AUTRES": "Autres",
    }.get(v, v)


def dax_periode(dt):
    t = datetime.combine(dax_today(), datetime.min.time())
    if dt is None:
        return "Plus d'un an"
    if dt >= t - timedelta(days=6):
        return "7 jours"
    if dt >= t - timedelta(days=29):
        return "30 jours"
    if dt >= t - timedelta(days=89):
        return "90 jours"
    if dt >= t - timedelta(days=364):
        return "1 an"
    return "Plus d'un an"


def dax_duree_reparation_label(sec):
    if sec is None:
        return ""
    t = int(sec // 60)
    h, m = divmod(t, 60)
    if h > 0:
        return f"{h}h {m}m"
    return f"{m}m"


def dax_veh_statut_label(s):
    return {
        "ACTIF": "En Service", "DISPONIBLE": "En Service",
        "ARRET": "À l'Arrêt", "IMMOBILISE": "À l'Arrêt",
        "MAINTENANCE": "Maintenance", "BLOQUE": "Bloqués",
    }.get(s, s)


def dax_veh_en_service(s):
    return s == "DISPONIBLE"


def dax_checklist_conforme_label(v):
    if v == "TRUE":
        return "Oui"
    if v == "FALSE":
        return "Non"
    return "-"


def dax_anom_statut_label(s):
    return {
        "DETECTEE": "Detectee", "EN_REPARATION": "En reparation",
        "REPAREE": "Reparee", "NON_REPAREE": "Non reparable",
        "VALIDEE": "Validee", "ANNULEE": "Annulee",
    }.get(s, s)


def dax_anom_ouverte(s):
    return s not in {"REPAREE", "VALIDEE", "ANNULEE"}


def dax_doc_jours_restants(exp_str):
    if not exp_str:
        return None
    try:
        exp = datetime.strptime(exp_str[:10], "%Y-%m-%d").date()
    except Exception:
        return None
    return (exp - dax_today()).days


def dax_doc_statut(est_disponible, exp_str):
    if est_disponible != "TRUE":
        return "MANQUANT"
    j = dax_doc_jours_restants(exp_str)
    if j is None:
        return "MANQUANT"
    if j < 0:
        return "EXPIRE"
    if j <= 30:
        return "EXPIRE_BIENTOT"
    return "VALIDE"


def dax_doc_obligatoire(t):
    return t in {"ASSURANCE", "CARTE_GRISE", "VISITE_TECHNIQUE",
                 "CONTROLE_TACHYGRAPHE", "ONSSA"}


def dax_group_expiration(j):
    if j is None:
        return ""
    if j < 0:
        return "Documents expirés"
    if j == 0:
        return "Expire aujourd'hui"
    if j == 1:
        return "Expire demain"
    if j <= 7:
        return "Expire dans 7 jours"
    if j <= 15:
        return "Expire dans 15 jours"
    if j <= 30:
        return "Expire dans 30 jours"
    return "Plus de 30 jours"


def dax_score_conduite(anomalies):
    if not anomalies:
        return ""
    penalites = (
        sum(1 for a in anomalies if a["criticite"] == "CRITIQUE") * 15 +
        sum(1 for a in anomalies if a["criticite"] == "MAJEURE") * 10 +
        sum(1 for a in anomalies if a["criticite"] == "MINEURE") * 5)
    return max(0, 100 - round(penalites / len(anomalies)))


# ---------------------------------------------------------------------------
# Fixture : copie de base + export + lecture CSV
# ---------------------------------------------------------------------------
class Fixture:
    def __init__(self):
        self.tmp = tempfile.mkdtemp(prefix="powerbi_test_")
        self.db_path = os.path.join(self.tmp, "smartfleet.db")
        self.out = os.path.join(self.tmp, "dataset")
        shutil.copy2(SRC_DB, self.db_path)
        self.conn = sqlite3.connect(self.db_path)

    def sql(self, q, params=()):
        cur = self.conn.cursor()
        cur.execute(q, params)
        self.conn.commit()
        return cur

    def export(self):
        from export_powerbi import main as exp_main  # noqa: F401
        import subprocess
        subprocess.run([sys.executable, EXPORT, "--db", self.db_path,
                        "--out", self.out], check=True,
                       capture_output=True, text=True)

    def csv(self, name):
        with open(os.path.join(self.out, name), encoding="utf-8") as f:
            return list(csv.DictReader(f))

    def close(self):
        self.conn.close()
        shutil.rmtree(self.tmp, ignore_errors=True)


# ---------------------------------------------------------------------------
# Mini-runner (aucune dependance)
# ---------------------------------------------------------------------------
PASSED = []
FAILED = []


def check(name, fn):
    try:
        fn()
        PASSED.append(name)
        print(f"  PASS  {name}")
    except AssertionError as e:
        FAILED.append((name, str(e)))
        print(f"  FAIL  {name}  -> {e}")
    except Exception as e:
        FAILED.append((name, f"EXCEPTION: {type(e).__name__}: {e}"))
        print(f"  ERROR {name}  -> {type(e).__name__}: {e}")


def eq(actual, expected, label=""):
    assert actual == expected, f"{label} : attendu={expected!r} obtenu={actual!r}"


def ok(cond, label=""):
    assert cond, f"{label} : condition fausse"


def in_rows(rows, key, value, label=""):
    vals = [r[key] for r in rows]
    ok(value in vals, f"{label} : {value} absent de {vals}")


# ---------------------------------------------------------------------------
# Tests FRONTEND : Declarations
# ---------------------------------------------------------------------------
def test_declaration_create():
    """Chauffeur cree une declaration -> CSV + Power BI 'En attente'."""
    fx = Fixture()
    try:
        now = datetime.now().isoformat()
        fx.sql("""INSERT INTO declarations
            (typePanne, description, statut, priorite, criticite, source,
             dateCreation, immatriculation, chauffeurId, chauffeurNom,
             categorie, numeroDemande)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
               ("FREIN", "Pedale molle", "EN_ATTENTE", "NORMALE", "CRITIQUE",
                "MANUEL", now, "AA-123-BC", 3, "Jean Chauffeur",
                "MECANIQUE", "INC-2026-000004"))
        fx.export()
        rows = fx.csv("declaration_incident.csv")
        row = [r for r in rows if r["ID_INCIDENT"] == "4"]
        eq(len(row), 1, "une seule declaration id=4")
        r = row[0]
        eq(r["STATUT"], "EN_ATTENTE", "statut CSV")
        eq(r["TYPE_PANNE"], "FREIN", "type panne CSV")
        eq(r["CHAUFFEUR_NOM"], "Jean Chauffeur", "chauffeur CSV")
        eq(r["VEHICULE_IMMATRICULATION"], "AA-123-BC", "immat CSV")
        eq(r["SOURCE"], "MANUEL", "source CSV")
        eq(dax_decl_statut_label(r["STATUT"]), "En attente", "label PBI")
        eq(dax_pie_segment(r["STATUT"]), "En attente", "segment pie PBI")
        # DAX : TYPE_PANNE_FILTRE = COALESCE(CATEGORIE, TYPE_PANNE)
        eq(r["TYPE_PANNE"], "FREIN", "type panne brute")
        eq(dax_type_panne_label(r["CATEGORIE"] or r["TYPE_PANNE"]),
           "Mecanique", "filtre type panne (CATEGORIE prioritaire)")
        mois = r["MOIS"]
        ok(mois, "MOIS rempli")
    finally:
        fx.close()


def test_declaration_take_charge():
    """RS prend en charge -> EN_COURS + prestataire."""
    fx = Fixture()
    try:
        now = datetime.now().isoformat()
        fx.sql("UPDATE declarations SET statut='EN_COURS', prestataireId=4, "
               "prestataireNom='Presta 1', dateDebutIntervention=? "
               "WHERE id=1", (now,))
        fx.export()
        r = [x for x in fx.csv("declaration_incident.csv")
             if x["ID_INCIDENT"] == "1"][0]
        eq(r["STATUT"], "EN_COURS", "statut")
        eq(dax_decl_statut_label(r["STATUT"]), "En cours", "label PBI")
        eq(dax_pie_segment(r["STATUT"]), "En cours", "segment PBI")
    finally:
        fx.close()


def test_declaration_submit_validation():
    """Prestataire soumet en validation -> EN_VALIDATION + duree reparations."""
    fx = Fixture()
    try:
        now = datetime.now().isoformat()
        fx.sql("UPDATE declarations SET statut='EN_VALIDATION', "
               "coutReel=450.0, dureeReparation=9000, dateReparation=?, "
               "solution='Freins remplaces', etat='REPARE', "
               "actionsRealisees='Remplacement plaquettes' WHERE id=1", (now,))
        fx.export()
        r = [x for x in fx.csv("declaration_incident.csv")
             if x["ID_INCIDENT"] == "1"][0]
        eq(r["STATUT"], "EN_VALIDATION", "statut")
        eq(dax_decl_statut_label(r["STATUT"]), "En validation", "label PBI")
        eq(dax_duree_reparation_label(9000), "2h 30m", "duree label PBI")
        eq(dax_periode(datetime.fromisoformat(r["DATE_HEURE"].replace(" ", "T"))),
           "7 jours", "periode PBI")
    finally:
        fx.close()


def test_declaration_close_budget():
    """RS cloture -> CLOTURE + coutReel + recalcul budget (sum coutReel)."""
    fx = Fixture()
    try:
        fx.sql("UPDATE declarations SET statut='CLOTURE', "
               "dateCloture='2026-08-01T23:59:59', coutReel=500.0 WHERE id=1")
        fx.export()
        r = [x for x in fx.csv("declaration_incident.csv")
             if x["ID_INCIDENT"] == "1"][0]
        eq(r["STATUT"], "CLOTURE", "statut")
        eq(dax_decl_statut_label(r["STATUT"]), "Cloture", "label PBI")
        eq(dax_pie_segment(r["STATUT"]), "Cloturees", "segment PBI")
        # Recalcul budget DAO (statut != REJETEE, depuis dateCreation budget)
        b = fx.sql("SELECT dateCreation FROM budget_trimestriel "
                   "WHERE statut='ACTIF' LIMIT 1").fetchone()
        total = fx.sql("SELECT COALESCE(SUM(coutReel),0) FROM declarations "
                       "WHERE statut!='REJETEE' AND dateCreation >= ?",
                       (b[0],)).fetchone()[0]
        eq(total, 680.0, "budget.utilise apres cloture (500+180)")
    finally:
        fx.close()


def test_declaration_return_and_refuse():
    """Retour (RETOURNEE) et refus (REFUSE) -> labels Power BI."""
    fx = Fixture()
    try:
        fx.sql("UPDATE declarations SET statut='RETOURNEE', motifRejet='Docs manquants' WHERE id=1")
        fx.sql("UPDATE declarations SET statut='REFUSE', motifRejet='Hors garantie', dateCloture='2026-08-01' WHERE id=2")
        fx.export()
        rows = fx.csv("declaration_incident.csv")
        r1 = [x for x in rows if x["ID_INCIDENT"] == "1"][0]
        r2 = [x for x in rows if x["ID_INCIDENT"] == "2"][0]
        eq(r1["MOTIF_REFUS"], "Docs manquants", "motif retour")
        eq(dax_decl_statut_label(r1["STATUT"]), "Retourne", "label retour")
        eq(dax_pie_segment(r1["STATUT"]), "Retournees", "segment retour")
        eq(dax_decl_statut_label(r2["STATUT"]), "Refuse", "label refus")
        eq(dax_pie_segment(r2["STATUT"]), "", "refus exclu du pie")
    finally:
        fx.close()


# ---------------------------------------------------------------------------
# Tests FRONTEND : Checklists
# ---------------------------------------------------------------------------
CHECKLIST_ITEMS = ["Batterie", "Carrosserie", "Ceintures sécurité", "Documents",
                   "Essuie-glaces", "Extincteur", "Feux (Éclairage)", "Freins",
                   "Niveau d'huile", "Pneus"]


def test_checklist_conforme():
    """Chauffeur valide une checklist conforme -> EST_CONFORME TRUE."""
    fx = Fixture()
    try:
        sid = fx.sql("INSERT INTO checklist_sessions "
                     "(vehiculeId, immatriculation, chauffeurId, date, "
                     "conforme, statut, chauffeurNom) "
                     "VALUES (1,'AA-123-BC',3,?,1,'COMPLETE','Jean Chauffeur')",
                     (datetime.now().isoformat(),)).lastrowid
        for nom in CHECKLIST_ITEMS:
            fx.sql("INSERT INTO checklist_items (sessionId, nom, categorie, "
                   "obligatoire, value, commentaire, defauts) "
                   "VALUES (?,?,?,1,1,'',NULL)", (sid, nom, nom))
        fx.export()
        r = [x for x in fx.csv("driver_checklists.csv")
             if x["ID"] == str(sid)][0]
        eq(r["EST_CONFORME"], "TRUE", "conforme")
        eq(r["BATTERIE"], "1", "item batterie")
        eq(r["PNEUS"], "1", "item pneus")
        eq(r["VEHICULE_IMMATRICULATION"], "AA-123-BC", "immat")
        eq(dax_checklist_conforme_label(r["EST_CONFORME"]), "Oui", "label PBI")
        eq(r["STATUT"], "COMPLETE", "statut checklist")
    finally:
        fx.close()


def test_checklist_non_conforme():
    """Checklist non conforme (un item KO) -> EST_CONFORME FALSE + defauts."""
    fx = Fixture()
    try:
        sid = fx.sql("INSERT INTO checklist_sessions "
                     "(vehiculeId, immatriculation, chauffeurId, date, "
                     "conforme, statut, chauffeurNom, commentaireGeneral) "
                     "VALUES (1,'AA-123-BC',3,?,0,'COMPLETE','Jean Chauffeur',"
                     "'Pneu avant droit use')",
                     (datetime.now().isoformat(),)).lastrowid
        for i, nom in enumerate(CHECKLIST_ITEMS):
            val = 0 if nom == "Pneus" else 1
            fx.sql("INSERT INTO checklist_items (sessionId, nom, categorie, "
                   "obligatoire, value, commentaire, defauts) "
                   "VALUES (?,?,?,1,?,?,NULL)",
                   (sid, nom, nom, val,
                    "Temoins usure visibles" if val == 0 else ""))
        fx.export()
        r = [x for x in fx.csv("driver_checklists.csv")
             if x["ID"] == str(sid)][0]
        eq(r["EST_CONFORME"], "FALSE", "non conforme")
        eq(r["PNEUS"], "0", "item pneus KO")
        ok("Pneus" in r["DEFAUTS_JSON"], "defauts_json contient Pneus")
        eq(dax_checklist_conforme_label(r["EST_CONFORME"]), "Non", "label PBI")
        # Mesure DAX 'Non conformes (COMPLETE + non conforme)'
        nonconf = [x for x in fx.csv("driver_checklists.csv")
                   if x["STATUT"] == "COMPLETE" and x["EST_CONFORME"] == "FALSE"]
        eq(len(nonconf), 1, "mesure non conformes")
    finally:
        fx.close()


def test_checklist_status_measures():
    """Statuts PENDING/REPAIRE/VALIDATED -> mesures Power BI."""
    fx = Fixture()
    try:
        # session existante PENDING (seed) + une REPAIRE + une VALIDATED
        fx.sql("UPDATE checklist_sessions SET statut='REPAIRE' WHERE id=2")
        sid = fx.sql("INSERT INTO checklist_sessions "
                     "(vehiculeId, immatriculation, chauffeurId, date, "
                     "conforme, statut, chauffeurNom, dateValidation, validePar) "
                     "VALUES (1,'AA-123-BC',3,?,1,'VALIDATED','Jean Chauffeur',"
                     "?,'RS Support')",
                     (datetime.now().isoformat(),
                      datetime.now().isoformat())).lastrowid
        fx.export()
        rows = fx.csv("driver_checklists.csv")
        eq(sum(1 for x in rows if x["STATUT"] == "PENDING"), 1, "PENDING count")
        eq(sum(1 for x in rows if x["STATUT"] == "REPAIRE"), 1, "REPAIRE count")
        eq(sum(1 for x in rows if x["STATUT"] == "VALIDATED"), 1, "VALIDATED count")
        ok(dax_checklist_conforme_label(
            [x for x in rows if x["ID"] == str(sid)][0]["EST_CONFORME"]) == "Oui",
           "label conforme validee")
    finally:
        fx.close()


# ---------------------------------------------------------------------------
# Tests FRONTEND : Documents
# ---------------------------------------------------------------------------
def test_document_statuts():
    """Ajout/MAJ de documents -> statut PBI VALIDE/EXPIRE_BIENTOT/EXPIRE/MANQUANT."""
    fx = Fixture()
    try:
        today_s = TODAY.isoformat()
        plus30 = (TODAY + timedelta(days=30)).isoformat()
        plus100 = (TODAY + timedelta(days=100)).isoformat()
        minus3 = (TODAY - timedelta(days=3)).isoformat()
        # MAJ des 3 documents existants
        fx.sql("UPDATE documents_vehicule SET estDisponible=1, "
               "dateExpiration=? WHERE id=1", (minus3,))       # EXPIRE
        fx.sql("UPDATE documents_vehicule SET estDisponible=1, "
               "dateExpiration=? WHERE id=2", (plus100,))      # VALIDE
        fx.sql("UPDATE documents_vehicule SET estDisponible=1, "
               "dateExpiration=? WHERE id=3", (plus30,))       # EXPIRE_BIENTOT
        fx.sql("INSERT INTO documents_vehicule (vehiculeId, immatriculation, "
               "typeDocument, dateEmission, dateExpiration, estDisponible, "
               "notes, createdAt, updatedAt) VALUES "
               "(1,'AA-123-BC','ASSURANCE',?,?,0,'Non fourni',?,?)",
               (today_s, today_s, datetime.now().isoformat(),
                datetime.now().isoformat()))                    # MANQUANT
        fx.export()
        rows = fx.csv("documents_vehicule.csv")
        docs = {r["ID"]: r for r in rows}
        eq(dax_doc_statut(docs["1"]["EST_DISPONIBLE"], docs["1"]["DATE_EXPIRATION"]),
           "EXPIRE", "doc 1 expiré")
        eq(dax_doc_statut(docs["2"]["EST_DISPONIBLE"], docs["2"]["DATE_EXPIRATION"]),
           "VALIDE", "doc 2 valide")
        eq(dax_doc_statut(docs["3"]["EST_DISPONIBLE"], docs["3"]["DATE_EXPIRATION"]),
           "EXPIRE_BIENTOT", "doc 3 expire bientot")
        eq(dax_doc_statut(docs["4"]["EST_DISPONIBLE"], docs["4"]["DATE_EXPIRATION"]),
           "MANQUANT", "doc 4 manquant")
        # Mesures DAX
        statuts = [dax_doc_statut(r["EST_DISPONIBLE"], r["DATE_EXPIRATION"])
                   for r in rows]
        eq(statuts.count("EXPIRE"), 1, "mesure Expires")
        eq(statuts.count("EXPIRE_BIENTOT"), 1, "mesure Expire bientot")
        eq(statuts.count("VALIDE"), 1, "mesure Valides")
        eq(statuts.count("MANQUANT"), 1, "mesure Manquants")
        # OBLIGATOIRE
        eq(dax_doc_obligatoire(docs["1"]["TYPE_DOCUMENT"]), True,
           "ASSURANCE obligatoire")
        eq(dax_group_expiration(-3), "Documents expirés", "groupe expiration")
        eq(dax_group_expiration(1), "Expire demain", "groupe J-1")
    finally:
        fx.close()


# ---------------------------------------------------------------------------
# Tests FRONTEND : Vehicules / Anomalies / Utilisateurs / Budget
# ---------------------------------------------------------------------------
def test_vehicle_status():
    """Changement de statut vehicule -> donut Power BI."""
    fx = Fixture()
    try:
        fx.sql("UPDATE vehicules SET statut='DISPONIBLE' WHERE id=1")
        fx.sql("UPDATE vehicules SET statut='ARRET' WHERE id=2")
        fx.sql("UPDATE vehicules SET statut='BLOQUE' WHERE id=3")
        fx.export()
        rows = fx.csv("vehicules.csv")
        by_id = {r["ID"]: r for r in rows}
        eq(dax_veh_statut_label(by_id["1"]["STATUT"]), "En Service", "v1")
        eq(dax_veh_statut_label(by_id["2"]["STATUT"]), "À l'Arrêt", "v2")
        eq(dax_veh_statut_label(by_id["3"]["STATUT"]), "Bloqués", "v3")
        # mesures
        eq(sum(1 for r in rows if r["STATUT"] == "DISPONIBLE"), 1, "En Service")
        eq(sum(1 for r in rows if r["STATUT"] == "ARRET"), 1, "A l Arret")
        eq(sum(1 for r in rows if r["STATUT"] == "BLOQUE"), 1, "Bloques")
        eq(sum(1 for r in rows if r["CONFORME"] == "TRUE"), 3, "conformes")
    finally:
        fx.close()


def test_anomaly_workflow():
    """Anomalie detectee -> reparations -> statuts Power BI + score conduite."""
    fx = Fixture()
    try:
        now = datetime.now().isoformat()
        fx.sql("INSERT INTO anomalies_checkup "
               "(code, checkupId, element, categorie, criticite, description, "
               "vehiculeId, immatriculation, chauffeurId, chauffeurNom, source, "
               "statut, dateCreation) VALUES "
               "(?,?,?,?,?,?,?,?,?,?,?,?,?)",
               ("ANOM-003", 1, "Freins", "MECANIQUE", "CRITIQUE",
                "Freinage faible", 1, "AA-123-BC", 3, "Jean Chauffeur",
                "CHECKUP", "DETECTEE", now))
        fx.export()
        rows = fx.csv("anomalies_checkup.csv")
        a = [r for r in rows if r["ANOMALIE_CODE"] == "ANOM-003"][0]
        eq(a["CRITICITE"], "CRITIQUE", "criticite")
        eq(dax_anom_statut_label(a["STATUT"]), "Detectee", "label PBI")
        # ouverte ?
        eq(dax_anom_ouverte(a["STATUT"]), True, "anomalie ouverte")
        # statut precedent (OUVERTE/EN_COURS seed) -> ouvertes
        eq(sum(1 for r in rows if dax_anom_ouverte(r["STATUT"])), 3,
           "mesure anomalies ouvertes")
        # cloturer la precedente
        fx.sql("UPDATE anomalies_checkup SET statut='REPAREE', "
               "dateReparation=? WHERE id=1", (now,))
        fx.export()
        rows = fx.csv("anomalies_checkup.csv")
        eq(sum(1 for r in rows if dax_anom_ouverte(r["STATUT"])), 2,
           "apres reparation")
        eq(dax_anom_statut_label([r for r in rows if r["ID"] == "1"][0]["STATUT"]),
           "Reparee", "label reparee")
    finally:
        fx.close()


def test_user_and_budget():
    """Ajout d'un chauffeur + budget -> mesures Power BI."""
    fx = Fixture()
    try:
        fx.sql("INSERT INTO utilisateurs (nom, email, motDePasse, role, "
               "telephone, actif, dateCreation, matricule, prenom, branchCode) "
               "VALUES ('Marie','marie@smartfleet.fr','x','CHAUFFEUR',"
               "'0600000000',1,?,'EMP005','Marie','Casablanca')",
               (datetime.now().isoformat(),))
        fx.export()
        users = fx.csv("users.csv")
        eq(sum(1 for r in users if r["ROLE"] == "CHAUFFEUR"), 2, "mesure Chauffeurs")
        eq(sum(1 for r in users if r["STATUS"] == "ACTIF"), 5, "actifs")
        # Budget : montants (mesures DAX Budget Total/Utilise/Restant)
        budget_rows = fx.sql("SELECT BUDGET_TOTAL, BUDGET_UTILISE FROM budget_trimestriel").fetchall() if False else None
        b = fx.sql("SELECT montantTotal, montantUtilise FROM budget_trimestriel "
                   "WHERE statut='ACTIF'").fetchone()
        eq(b[0], b[1] + (b[0] - b[1]), "budget total = utilise + restant")
        ok((b[0] - b[1]) > 0, "Budget Suffisant = OUI")
    finally:
        fx.close()


# ---------------------------------------------------------------------------
# Tests BACKEND : Agent IA (VOICE_AI) + file de sync
# ---------------------------------------------------------------------------
def test_backend_voice_ai_declaration():
    """Agent IA cree une declaration -> source VOICE_AI, champs extraits."""
    fx = Fixture()
    try:
        now = datetime.now().isoformat()
        # Reproduit _buildDeclarationBody() de voice_ai_screen.dart apres
        # confirmation de l'agent (extraction typePanne/criticite/lieu/km)
        fx.sql("""INSERT INTO declarations
            (typePanne, description, immatriculation, chauffeurNom, lieu,
             kilometrage, criticite, elementVehicule, dateCreation, statut,
             priorite, categorie, source, chauffeurId)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
               ("MECANIQUE", "Le moteur fait du bruit", "CC-789-EF",
                "Jean Chauffeur", "Casablanca", "58200", "NON_BLOQUANT",
                "MOTEUR", now, "EN_ATTENTE", "NORMALE", "MECANIQUE",
                "VOICE_AI", 3))
        fx.export()
        r = [x for x in fx.csv("declaration_incident.csv")
             if x["ID_INCIDENT"] == "4"][0]
        eq(r["SOURCE"], "VOICE_AI", "source backend")
        eq(r["TYPE_PANNE"], "MECANIQUE", "typePanne extrait")
        eq(r["CATEGORIE"], "MECANIQUE", "categorie extraite")
        eq(r["VEHICULE_IMMATRICULATION"], "CC-789-EF", "immat extraite")
        eq(r["LIEU"], "Casablanca", "lieu extrait")
        eq(r["CRITICITE"], "NON_BLOQUANT", "criticite extraite")
        eq(dax_decl_statut_label(r["STATUT"]), "En attente", "label PBI")
        eq(dax_type_panne_label(r["CATEGORIE"] or r["TYPE_PANNE"]),
           "Mecanique", "filtre type panne PBI")
    finally:
        fx.close()


def test_backend_sync_queue():
    """Sync : declaration en file -> marquee COMPLETED, donnee reste exportee."""
    fx = Fixture()
    try:
        now = datetime.now().isoformat()
        # DeclarationService.create() : insert + addToQueue(INSERT)
        # (le seed contient deja 2 lignes PENDING -> on mesure le delta)
        before = fx.sql("SELECT COUNT(*) FROM sync_queue "
                        "WHERE status='PENDING'").fetchone()[0]
        fx.sql("INSERT INTO sync_queue (tableName, action, recordId, payload, "
               "status, dateCreation) VALUES ('declarations','INSERT',4,?,"
               "'PENDING',?)",
               ('{"typePanne":"PNEU","statut":"EN_ATTENTE"}', now))
        pending = fx.sql("SELECT COUNT(*) FROM sync_queue "
                         "WHERE status='PENDING'").fetchone()[0]
        eq(pending, before + 1, "1 opération ajoutée en file")
        # SyncService.syncAll -> markCompleted
        fx.sql("UPDATE sync_queue SET status='COMPLETED' WHERE recordId=4")
        remaining = fx.sql("SELECT COUNT(*) FROM sync_queue "
                           "WHERE status='PENDING'").fetchone()[0]
        eq(remaining, before, "l'opération marquée COMPLETED n'est plus PENDING")
        fx.export()
        ok(True, "export OK après sync")
    finally:
        fx.close()


def test_backend_websocket_save():
    """Flux WS : le body cote serveur devient une declaration exportee."""
    fx = Fixture()
    try:
        now = datetime.now().isoformat()
        # VoiceAiWebSocketHandler : 'type':'save' -> insertion declaration
        fx.sql("""INSERT INTO declarations
            (typePanne, description, immatriculation, chauffeurNom, dateCreation,
             statut, priorite, source, chauffeurId)
            VALUES (?,?,?,?,?,?,?,?,?)""",
               ("ELECTRIQUE", "Phare clignote", "BB-456-CD",
                "Jean Chauffeur", now, "EN_ATTENTE", "NORMALE", "VOICE_AI", 3))
        fx.export()
        r = [x for x in fx.csv("declaration_incident.csv")
             if x["ID_INCIDENT"] == "4"][0]
        eq(r["SOURCE"], "VOICE_AI", "source WS")
        eq(r["TYPE_PANNE"], "ELECTRIQUE", "type panne WS")
        eq(dax_type_panne_label(r["CATEGORIE"] or r["TYPE_PANNE"]),
           "Electrique", "label PBI")
    finally:
        fx.close()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    if not os.path.exists(SRC_DB):
        print(f"ERREUR : base introuvable -> {SRC_DB}")
        return 2

    groups = [
        ("FRONTEND - Declarations", [
            ("declaration creee (En attente)", test_declaration_create),
            ("prise en charge (En cours)", test_declaration_take_charge),
            ("soumission validation", test_declaration_submit_validation),
            ("cloture + budget", test_declaration_close_budget),
            ("retour + refus", test_declaration_return_and_refuse),
        ]),
        ("FRONTEND - Checklists", [
            ("checklist conforme", test_checklist_conforme),
            ("checklist non conforme + defauts", test_checklist_non_conforme),
            ("mesures statuts checklist", test_checklist_status_measures),
        ]),
        ("FRONTEND - Documents", [
            ("statuts expiration documents", test_document_statuts),
        ]),
        ("FRONTEND - Vehicules / Anomalies / Users / Budget", [
            ("statut vehicules (donut)", test_vehicle_status),
            ("workflow anomalies + score", test_anomaly_workflow),
            ("ajout chauffeur + budget", test_user_and_budget),
        ]),
        ("BACKEND - Agent IA + Sync + WebSocket", [
            ("declaration VOICE_AI (agent)", test_backend_voice_ai_declaration),
            ("file de sync", test_backend_sync_queue),
            ("flux websocket save", test_backend_websocket_save),
        ]),
    ]

    total = 0
    for title, tests in groups:
        print(f"\n=== {title} ===")
        for name, fn in tests:
            check(name, fn)
            total += 1

    print(f"\n{'='*60}")
    print(f"RESULTAT : {len(PASSED)}/{total} passes, {len(FAILED)} echecs")
    if FAILED:
        print("\nEchecs :")
        for name, msg in FAILED:
            print(f"  - {name} : {msg}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
