import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  static Database? _database;

  DatabaseHelper._();

  factory DatabaseHelper() => _instance;

  static void resetForTesting() {
    _database = null;
  }

  static Future<void> closeForTesting() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smartfleet.db');

    return await openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createVersion2Tables(db);
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE checklist_sessions ADD COLUMN statut TEXT DEFAULT "PENDING"',);
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS biometric_devices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId INTEGER NOT NULL,
          deviceId TEXT NOT NULL,
          deviceName TEXT,
          platform TEXT,
          biometricEnabled INTEGER NOT NULL DEFAULT 1,
          lastUsed TEXT,
          dateCreated TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (userId) REFERENCES utilisateurs(id)
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE checklist_items ADD COLUMN defauts TEXT DEFAULT NULL');
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE utilisateurs ADD COLUMN matricule TEXT');
        await db.execute('ALTER TABLE utilisateurs ADD COLUMN prenom TEXT');
        await db.execute('ALTER TABLE utilisateurs ADD COLUMN branchCode TEXT');

        await db.execute('ALTER TABLE vehicules ADD COLUMN vehicleId TEXT');
        await db.execute('ALTER TABLE vehicules ADD COLUMN truckNumber TEXT');
        await db.execute('ALTER TABLE vehicules ADD COLUMN carburant TEXT');
        await db.execute('ALTER TABLE vehicules ADD COLUMN agence TEXT');
        await db.execute('ALTER TABLE vehicules ADD COLUMN chauffeurNom TEXT');
        await db.execute('ALTER TABLE vehicules ADD COLUMN dateAffectation TEXT');
        await db.execute('ALTER TABLE vehicules ADD COLUMN notes TEXT');
        await db.execute('ALTER TABLE vehicules ADD COLUMN archived INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE vehicules ADD COLUMN archivedAt TEXT');
        await db.execute('ALTER TABLE vehicules ADD COLUMN archivedBy TEXT');
        await db.execute('ALTER TABLE vehicules ADD COLUMN geotabId TEXT');
        await db.execute('ALTER TABLE vehicules ADD COLUMN niveauCarburant REAL');
        await db.execute('ALTER TABLE vehicules ADD COLUMN dernierePositionDate TEXT');
        await db.execute('ALTER TABLE vehicules ADD COLUMN moteurAllume INTEGER DEFAULT 0');

        await db.execute('ALTER TABLE checklist_sessions ADD COLUMN chauffeurNom TEXT');
        await db.execute('ALTER TABLE checklist_sessions ADD COLUMN chauffeurMatricule TEXT');
        await db.execute('ALTER TABLE checklist_sessions ADD COLUMN commentaireGeneral TEXT');
        await db.execute('ALTER TABLE checklist_sessions ADD COLUMN messageAlerteArabe TEXT');
        await db.execute('ALTER TABLE checklist_sessions ADD COLUMN postRepair INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE checklist_sessions ADD COLUMN reparationsJson TEXT');
        await db.execute('ALTER TABLE checklist_sessions ADD COLUMN validePar TEXT');
        await db.execute('ALTER TABLE checklist_sessions ADD COLUMN dateValidation TEXT');
        await db.execute('ALTER TABLE checklist_sessions ADD COLUMN motifRefus TEXT');

        await db.execute('ALTER TABLE checkups ADD COLUMN vehiculeTruckNumber TEXT');
        await db.execute('ALTER TABLE checkups ADD COLUMN documentsDisponibles TEXT');
        await db.execute('ALTER TABLE checkups ADD COLUMN createdBy TEXT');
        await db.execute('ALTER TABLE checkups ADD COLUMN createdAt TEXT');
        await db.execute('ALTER TABLE checkups ADD COLUMN updatedAt TEXT');

        await db.execute('ALTER TABLE checkup_details ADD COLUMN criticite TEXT');
        await db.execute('ALTER TABLE checkup_details ADD COLUMN statut TEXT');

        await db.execute('ALTER TABLE anomalies_checkup ADD COLUMN checkupCode TEXT');
        await db.execute('ALTER TABLE anomalies_checkup ADD COLUMN taskId INTEGER');
        await db.execute('ALTER TABLE anomalies_checkup ADD COLUMN datePriseEnCharge TEXT');
        await db.execute('ALTER TABLE anomalies_checkup ADD COLUMN dateReparation TEXT');
        await db.execute('ALTER TABLE anomalies_checkup ADD COLUMN dateValidation TEXT');
        await db.execute('ALTER TABLE anomalies_checkup ADD COLUMN reparePar TEXT');
        await db.execute('ALTER TABLE anomalies_checkup ADD COLUMN validePar TEXT');
        await db.execute('ALTER TABLE anomalies_checkup ADD COLUMN createdAt TEXT');
        await db.execute('ALTER TABLE anomalies_checkup ADD COLUMN updatedAt TEXT');

        await db.execute('ALTER TABLE documents_vehicule ADD COLUMN importePar TEXT');
        await db.execute('ALTER TABLE documents_vehicule ADD COLUMN createdAt TEXT');
        await db.execute('ALTER TABLE documents_vehicule ADD COLUMN updatedAt TEXT');
        await db.execute('ALTER TABLE documents_vehicule ADD COLUMN archivedAt TEXT');
        await db.execute('ALTER TABLE documents_vehicule ADD COLUMN archivedBy TEXT');

        await db.execute('ALTER TABLE tickets_maintenance ADD COLUMN tourneeId TEXT');
        await db.execute('ALTER TABLE tickets_maintenance ADD COLUMN element TEXT');
        await db.execute('ALTER TABLE tickets_maintenance ADD COLUMN criticite TEXT');
        await db.execute('ALTER TABLE tickets_maintenance ADD COLUMN affectation TEXT');
        await db.execute('ALTER TABLE tickets_maintenance ADD COLUMN actionsRealisees TEXT');
        await db.execute('ALTER TABLE tickets_maintenance ADD COLUMN dateModification TEXT');
        await db.execute('ALTER TABLE tickets_maintenance ADD COLUMN creePar TEXT');
        await db.execute('ALTER TABLE tickets_maintenance ADD COLUMN modifiePar TEXT');

        await db.execute('ALTER TABLE fleet_alerts ADD COLUMN chauffeurNom TEXT');
        await db.execute('ALTER TABLE fleet_alerts ADD COLUMN checklistId INTEGER');
        await db.execute('ALTER TABLE fleet_alerts ADD COLUMN documentId INTEGER');
        await db.execute('ALTER TABLE fleet_alerts ADD COLUMN actionRequise TEXT');

        await db.execute('ALTER TABLE vehicle_blockings ADD COLUMN alerteId INTEGER');

        await db.execute('ALTER TABLE tournees ADD COLUMN chauffeurNom TEXT');
        await db.execute('ALTER TABLE tournees ADD COLUMN nombreArrets INTEGER');
        await db.execute('ALTER TABLE tournees ADD COLUMN itineraire TEXT');
        await db.execute('ALTER TABLE tournees ADD COLUMN dateModification TEXT');

        await db.execute('ALTER TABLE departs_historique ADD COLUMN numeroDepart TEXT');
        await db.execute('ALTER TABLE departs_historique ADD COLUMN chauffeurNom TEXT');
        await db.execute('ALTER TABLE departs_historique ADD COLUMN chauffeurMatricule TEXT');
        await db.execute('ALTER TABLE departs_historique ADD COLUMN heureDepart TEXT');
        await db.execute('ALTER TABLE departs_historique ADD COLUMN timestampDepart TEXT');
        await db.execute('ALTER TABLE departs_historique ADD COLUMN resultatControle TEXT');
        await db.execute('ALTER TABLE departs_historique ADD COLUMN statutVehicule TEXT');
        await db.execute('ALTER TABLE departs_historique ADD COLUMN gpsCity TEXT');
        await db.execute('ALTER TABLE departs_historique ADD COLUMN deleted INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE departs_historique ADD COLUMN dateSuppression TEXT');
        await db.execute('ALTER TABLE departs_historique ADD COLUMN supprimePar TEXT');
        await db.execute('ALTER TABLE departs_historique ADD COLUMN dateCreation TEXT');

        await db.execute('ALTER TABLE budget_trimestriel ADD COLUMN dateDebutPeriode TEXT');
        await db.execute('ALTER TABLE budget_trimestriel ADD COLUMN dateFinPeriode TEXT');
        await db.execute('ALTER TABLE budget_trimestriel ADD COLUMN annee INTEGER');
        await db.execute('ALTER TABLE budget_trimestriel ADD COLUMN trimestre INTEGER');
        await db.execute('ALTER TABLE budget_trimestriel ADD COLUMN actif INTEGER DEFAULT 1');
      } catch (_) {
      }
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE declarations ADD COLUMN vehiculeId INTEGER');
      await db.execute('ALTER TABLE declarations ADD COLUMN vehiculeMarque TEXT');
      await db.execute('ALTER TABLE declarations ADD COLUMN vehiculeModele TEXT');
      await db.execute('ALTER TABLE declarations ADD COLUMN vehiculeType TEXT');
      await db.execute('ALTER TABLE declarations ADD COLUMN elementVehicule TEXT');
      await db.execute('ALTER TABLE declarations ADD COLUMN detailElement TEXT');
      await db.execute('ALTER TABLE declarations ADD COLUMN categorie TEXT');
      await db.execute('ALTER TABLE declarations ADD COLUMN video TEXT');
      await db.execute('ALTER TABLE declarations ADD COLUMN withVideo INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE declarations ADD COLUMN numeroDemande TEXT');
      await db.execute('ALTER TABLE declarations ADD COLUMN kilometrage INTEGER');
      await db.execute('ALTER TABLE declarations ADD COLUMN lieu TEXT');
      await db.execute('ALTER TABLE declarations ADD COLUMN dateReparation TEXT');
      await db.execute('ALTER TABLE declarations ADD COLUMN dureeReparation INTEGER');
      await db.execute('ALTER TABLE declarations ADD COLUMN etat TEXT');
      await db.execute('ALTER TABLE declarations ADD COLUMN actionsRealisees TEXT');
      await db.execute('ALTER TABLE declarations ADD COLUMN piecesNecessaires TEXT');
      await db.execute('ALTER TABLE declarations ADD COLUMN qualification TEXT');
      await db.execute('ALTER TABLE declarations ADD COLUMN contratBonCommande TEXT');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE declarations ADD COLUMN criticite TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createAllTables(db);
    await _seedDefaultData(db);
  }

  Future<void> _createAllTables(Database db) async {
    await db.execute('''
      CREATE TABLE utilisateurs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        motDePasse TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'CHAUFFEUR',
        telephone TEXT,
        actif INTEGER NOT NULL DEFAULT 1,
        photoUrl TEXT,
        dateCreation TEXT NOT NULL DEFAULT (datetime('now')),
        matricule TEXT, prenom TEXT, branchCode TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE vehicules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        immatriculation TEXT UNIQUE NOT NULL,
        marque TEXT, modele TEXT, annee INTEGER,
        statut TEXT DEFAULT 'ACTIF', kilometrage INTEGER DEFAULT 0,
        type TEXT, chauffeurId INTEGER,
        branche TEXT, conforme INTEGER DEFAULT 1,
        derniereLatitude REAL, derniereLongitude REAL,
        derniereVitesse REAL, derniereIgnition INTEGER DEFAULT 0,
        dateCreation TEXT NOT NULL DEFAULT (datetime('now')),
        vehicleId TEXT, truckNumber TEXT, carburant TEXT, agence TEXT,
        chauffeurNom TEXT, dateAffectation TEXT, notes TEXT,
        archived INTEGER DEFAULT 0, archivedAt TEXT, archivedBy TEXT,
        geotabId TEXT, niveauCarburant REAL, dernierePositionDate TEXT,
        moteurAllume INTEGER DEFAULT 0,
        FOREIGN KEY (chauffeurId) REFERENCES utilisateurs(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE declarations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        typePanne TEXT NOT NULL, description TEXT,
        statut TEXT NOT NULL DEFAULT 'EN_ATTENTE',
        priorite TEXT DEFAULT 'NORMALE', criticite TEXT, source TEXT DEFAULT 'MANUEL',
        dateCreation TEXT NOT NULL DEFAULT (datetime('now')),
        dateCloture TEXT, immatriculation TEXT NOT NULL,
        chauffeurId INTEGER NOT NULL, chauffeurNom TEXT,
        prestataireId INTEGER, prestataireNom TEXT,
        coutEstime REAL DEFAULT 0, coutReel REAL DEFAULT 0,
        latitude REAL, longitude REAL,
        withPhoto INTEGER DEFAULT 0,
        solution TEXT, motifRejet TEXT,
        syncStatus TEXT DEFAULT 'SYNCED',
        vehiculeId INTEGER, vehiculeMarque TEXT, vehiculeModele TEXT, vehiculeType TEXT,
        elementVehicule TEXT, detailElement TEXT, categorie TEXT,
        video TEXT, withVideo INTEGER DEFAULT 0,
        numeroDemande TEXT, kilometrage INTEGER, lieu TEXT,
        dateReparation TEXT, dureeReparation INTEGER,
        etat TEXT, actionsRealisees TEXT, piecesNecessaires TEXT,
        qualification TEXT, contratBonCommande TEXT,
        FOREIGN KEY (chauffeurId) REFERENCES utilisateurs(id),
        FOREIGN KEY (immatriculation) REFERENCES vehicules(immatriculation)
      )
    ''');
    await db.execute('''
      CREATE TABLE budget_trimestriel (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        periode TEXT NOT NULL, montantTotal REAL NOT NULL DEFAULT 0,
        montantUtilise REAL NOT NULL DEFAULT 0,
        statut TEXT DEFAULT 'ACTIF',
        dateCreation TEXT NOT NULL DEFAULT (datetime('now')),
        syncStatus TEXT DEFAULT 'SYNCED',
        dateDebutPeriode TEXT, dateFinPeriode TEXT,
        annee INTEGER, trimestre INTEGER, actif INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE checklist_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehiculeId INTEGER NOT NULL, immatriculation TEXT NOT NULL,
        chauffeurId INTEGER NOT NULL,
        date TEXT NOT NULL DEFAULT (datetime('now')),
        conforme INTEGER NOT NULL DEFAULT 1, statut TEXT DEFAULT 'PENDING', signature TEXT,
        tourneeId INTEGER, feedback TEXT,
        syncStatus TEXT DEFAULT 'SYNCED',
        chauffeurNom TEXT, chauffeurMatricule TEXT, commentaireGeneral TEXT,
        messageAlerteArabe TEXT, postRepair INTEGER DEFAULT 0,
        reparationsJson TEXT, validePar TEXT, dateValidation TEXT, motifRefus TEXT,
        FOREIGN KEY (vehiculeId) REFERENCES vehicules(id),
        FOREIGN KEY (chauffeurId) REFERENCES utilisateurs(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE checklist_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER NOT NULL, nom TEXT NOT NULL,
        categorie TEXT NOT NULL, obligatoire INTEGER NOT NULL DEFAULT 0,
        value INTEGER, commentaire TEXT, defauts TEXT,
        FOREIGN KEY (sessionId) REFERENCES checklist_sessions(id)
      )
    ''');
    await _createVersion2Tables(db);
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT, tableName TEXT NOT NULL,
        action TEXT NOT NULL, recordId INTEGER, payload TEXT,
        dateCreation TEXT NOT NULL DEFAULT (datetime('now')),
        status TEXT DEFAULT 'PENDING'
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS biometric_devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        deviceId TEXT NOT NULL,
        deviceName TEXT,
        platform TEXT,
        biometricEnabled INTEGER NOT NULL DEFAULT 1,
        lastUsed TEXT,
        dateCreated TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (userId) REFERENCES utilisateurs(id)
      )
    ''');
  }

  Future<void> _createVersion2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tournees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero TEXT UNIQUE NOT NULL, chauffeurId INTEGER NOT NULL,
        vehiculeId INTEGER NOT NULL, immatriculation TEXT,
        statut TEXT DEFAULT 'PLANIFIEE',
        dateDebut TEXT, dateFin TEXT,
        distancePrevue REAL DEFAULT 0, distanceReelle REAL DEFAULT 0,
        site TEXT, branche TEXT,
        notes TEXT, dateCreation TEXT NOT NULL DEFAULT (datetime('now')),
        chauffeurNom TEXT, nombreArrets INTEGER, itineraire TEXT, dateModification TEXT,
        FOREIGN KEY (chauffeurId) REFERENCES utilisateurs(id),
        FOREIGN KEY (vehiculeId) REFERENCES vehicules(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checkups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE, vehiculeId INTEGER NOT NULL,
        immatriculation TEXT, chauffeurId INTEGER,
        chauffeurNom TEXT, kilometrage REAL,
        conforme INTEGER DEFAULT 1,
        dateCheckup TEXT NOT NULL DEFAULT (datetime('now')),
        statut TEXT DEFAULT 'TERMINE', notes TEXT,
        vehiculeTruckNumber TEXT, documentsDisponibles TEXT,
        createdBy TEXT, createdAt TEXT, updatedAt TEXT,
        FOREIGN KEY (vehiculeId) REFERENCES vehicules(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checkup_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        checkupId INTEGER NOT NULL, element TEXT NOT NULL,
        categorie TEXT, conforme INTEGER DEFAULT 1,
        observation TEXT, photoUrl TEXT,
        criticite TEXT, statut TEXT,
        FOREIGN KEY (checkupId) REFERENCES checkups(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS anomalies_checkup (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE, checkupId INTEGER,
        element TEXT, categorie TEXT,
        criticite TEXT DEFAULT 'MOYENNE',
        description TEXT, observation TEXT,
        vehiculeId INTEGER, immatriculation TEXT,
        chauffeurId INTEGER, chauffeurNom TEXT,
        photoUrl TEXT, source TEXT DEFAULT 'CHECKUP',
        statut TEXT DEFAULT 'OUVERTE',
        dateCreation TEXT NOT NULL DEFAULT (datetime('now')),
        dateResolution TEXT, assignedTo TEXT,
        resolutionNotes TEXT,
        checkupCode TEXT, taskId INTEGER,
        datePriseEnCharge TEXT, dateReparation TEXT, dateValidation TEXT,
        reparePar TEXT, validePar TEXT, createdAt TEXT, updatedAt TEXT,
        FOREIGN KEY (checkupId) REFERENCES checkups(id),
        FOREIGN KEY (vehiculeId) REFERENCES vehicules(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS documents_vehicule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehiculeId INTEGER NOT NULL, immatriculation TEXT,
        typeDocument TEXT NOT NULL, numeroDocument TEXT,
        dateEmission TEXT, dateExpiration TEXT,
        fichierUrl TEXT, estDisponible INTEGER DEFAULT 1,
        notes TEXT, archived INTEGER DEFAULT 0,
        importePar TEXT, createdAt TEXT, updatedAt TEXT,
        archivedAt TEXT, archivedBy TEXT,
        FOREIGN KEY (vehiculeId) REFERENCES vehicules(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tickets_maintenance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero TEXT UNIQUE NOT NULL, vehiculeId INTEGER NOT NULL,
        immatriculation TEXT, typePanne TEXT,
        description TEXT, statut TEXT DEFAULT 'OUVERT',
        priorite TEXT DEFAULT 'NORMALE',
        declarePar INTEGER, declareParNom TEXT,
        assigneA TEXT, technicien TEXT,
        dateCreation TEXT NOT NULL DEFAULT (datetime('now')),
        dateDebut TEXT, dateFin TEXT,
        coutEstime REAL DEFAULT 0, coutReel REAL DEFAULT 0,
        pieces TEXT, notes TEXT,
        tourneeId TEXT, element TEXT, criticite TEXT,
        affectation TEXT, actionsRealisees TEXT,
        dateModification TEXT, creePar TEXT, modifiePar TEXT,
        FOREIGN KEY (vehiculeId) REFERENCES vehicules(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS interventions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticketId INTEGER NOT NULL, technicien TEXT,
        typeIntervention TEXT, description TEXT,
        statut TEXT DEFAULT 'EN_ATTENTE',
        dateDebut TEXT, dateFin TEXT,
        coutMainOeuvre REAL DEFAULT 0, coutPieces REAL DEFAULT 0,
        notes TEXT,
        FOREIGN KEY (ticketId) REFERENCES tickets_maintenance(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fleet_alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehiculeId INTEGER, immatriculation TEXT,
        type TEXT NOT NULL, criticite TEXT DEFAULT 'MOYENNE',
        message TEXT, statut TEXT DEFAULT 'ACTIVE',
        dateCreation TEXT NOT NULL DEFAULT (datetime('now')),
        dateResolution TEXT, resoluPar TEXT,
        chauffeurNom TEXT, checklistId INTEGER,
        documentId INTEGER, actionRequise TEXT,
        FOREIGN KEY (vehiculeId) REFERENCES vehicules(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vehicle_blockings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehiculeId INTEGER NOT NULL, immatriculation TEXT,
        raison TEXT NOT NULL, niveau TEXT DEFAULT 'IMMEDIAT',
        bloquePar INTEGER, bloqueLe TEXT NOT NULL DEFAULT (datetime('now')),
        debloquePar INTEGER, debloqueLe TEXT, actif INTEGER DEFAULT 1,
        alerteId INTEGER,
        FOREIGN KEY (vehiculeId) REFERENCES vehicules(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS qr_codes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL, vehiculeId INTEGER NOT NULL,
        immatriculation TEXT, actif INTEGER DEFAULT 1,
        dateCreation TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (vehiculeId) REFERENCES vehicules(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tracking_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        immatriculation TEXT NOT NULL, latitude REAL NOT NULL,
        longitude REAL NOT NULL, vitesse REAL DEFAULT 0,
        angle REAL DEFAULT 0, ignition INTEGER DEFAULT 0,
        dateTracking TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER, action TEXT NOT NULL,
        entite TEXT, entiteId INTEGER,
        details TEXT, dateAction TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS departs_historique (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        checklistId INTEGER, chauffeurId INTEGER,
        vehiculeId INTEGER, immatriculation TEXT,
        tourneeId INTEGER, dateDepart TEXT NOT NULL DEFAULT (datetime('now')),
        site TEXT, branche TEXT,
        gpsLatitude REAL, gpsLongitude REAL,
        numeroDepart TEXT, chauffeurNom TEXT, chauffeurMatricule TEXT,
        heureDepart TEXT, timestampDepart TEXT,
        resultatControle TEXT, statutVehicule TEXT, gpsCity TEXT,
        deleted INTEGER DEFAULT 0, dateSuppression TEXT,
        supprimePar TEXT, dateCreation TEXT,
        FOREIGN KEY (checklistId) REFERENCES checklist_sessions(id),
        FOREIGN KEY (chauffeurId) REFERENCES utilisateurs(id)
      )
    ''');
  }

  Future<void> _seedDefaultData(Database db) async {
    await db.insert('utilisateurs', {
      'nom': 'Admin',
      'email': 'admin@smartfleet.fr',
      'motDePasse': 'admin123',
      'role': 'ADMIN',
      'actif': 1,
    });
    await db.insert('utilisateurs', {
      'nom': 'RS Support',
      'email': 'rs_support@smartfleet.fr',
      'motDePasse': 'support123',
      'role': 'RS',
      'actif': 1,
    });
    await db.insert('utilisateurs', {
      'nom': 'Jean Chauffeur',
      'email': 'jean@smartfleet.fr',
      'motDePasse': 'chauffeur123',
      'role': 'CHAUFFEUR',
      'actif': 1,
    });
    await db.insert('utilisateurs', {
      'nom': 'Presta 1',
      'email': 'presta@smartfleet.fr',
      'motDePasse': 'presta123',
      'role': 'PRESTATAIRE',
      'actif': 1,
    });
    await db.insert('vehicules', {
      'immatriculation': 'AA-123-BC',
      'marque': 'Renault',
      'modele': 'Master',
      'annee': 2020,
      'kilometrage': 45000,
      'chauffeurId': 3,
    });
    await db.insert('vehicules', {
      'immatriculation': 'BB-456-CD',
      'marque': 'Mercedes',
      'modele': 'Sprinter',
      'annee': 2021,
      'kilometrage': 32000,
      'chauffeurId': 3,
    });
    await db.insert('vehicules', {
      'immatriculation': 'CC-789-EF',
      'marque': 'Iveco',
      'modele': 'Daily',
      'annee': 2019,
      'kilometrage': 58000,
    });
    await db.insert('budget_trimestriel', {
      'periode': '2026-Q2',
      'montantTotal': 50000,
      'montantUtilise': 12350,
      'statut': 'ACTIF',
    });
    await db.insert('budget_trimestriel', {
      'periode': '2026-Q3',
      'montantTotal': 55000,
      'montantUtilise': 5400,
      'statut': 'ACTIF',
    });

    await db.insert('documents_vehicule', {
      'vehiculeId': 1,
      'immatriculation': 'AA-123-BC',
      'typeDocument': 'ASSURANCE',
      'numeroDocument': 'ASS-2025-001',
      'dateEmission': '2025-01-01',
      'dateExpiration': '2025-12-01',
      'estDisponible': 1,
    });
    await db.insert('documents_vehicule', {
      'vehiculeId': 1,
      'immatriculation': 'AA-123-BC',
      'typeDocument': 'CARTE_GRISE',
      'numeroDocument': 'CG-2020-123',
      'dateEmission': '2020-03-15',
      'dateExpiration': '2027-06-15',
      'estDisponible': 1,
    });
    await db.insert('documents_vehicule', {
      'vehiculeId': 1,
      'immatriculation': 'AA-123-BC',
      'typeDocument': 'VISITE_TECHNIQUE',
      'numeroDocument': 'VT-2026-045',
      'dateEmission': '2026-01-01',
      'dateExpiration': '2026-08-01',
      'estDisponible': 1,
    });

    await db.insert('declarations', {
      'typePanne': 'FREIN',
      'description': 'Pedale molle, freinage inefficace',
      'statut': 'EN_ATTENTE',
      'priorite': 'URGENT',
      'source': 'MANUEL',
      'immatriculation': 'AA-123-BC',
      'chauffeurId': 3,
      'chauffeurNom': 'Jean Chauffeur',
      'coutEstime': 350.0,
    });
    await db.insert('declarations', {
      'typePanne': 'PNEU',
      'description': 'Pneu avant droit usé',
      'statut': 'CLOTURE',
      'priorite': 'NORMALE',
      'source': 'MANUEL',
      'immatriculation': 'BB-456-CD',
      'chauffeurId': 3,
      'chauffeurNom': 'Jean Chauffeur',
      'coutEstime': 200.0,
      'coutReel': 180.0,
      'dateCloture': '2026-06-15T14:30:00',
    });
    await db.insert('declarations', {
      'typePanne': 'MOTEUR',
      'description': 'Surconsommation d huile',
      'statut': 'PRISE_EN_CHARGE',
      'priorite': 'NORMALE',
      'source': 'MANUEL',
      'immatriculation': 'CC-789-EF',
      'chauffeurId': 3,
      'chauffeurNom': 'Jean Chauffeur',
      'prestataireId': 4,
      'prestataireNom': 'Presta 1',
      'coutEstime': 800.0,
    });

    await db.insert('tournees', {
      'numero': 'TOUR-001',
      'chauffeurId': 3,
      'vehiculeId': 1,
      'immatriculation': 'AA-123-BC',
      'statut': 'PLANIFIEE',
      'dateDebut': '2026-07-03T08:00:00',
      'site': 'Casablanca',
      'branche': 'Nord',
      'distancePrevue': 120.0,
    });
    await db.insert('tournees', {
      'numero': 'TOUR-002',
      'chauffeurId': 3,
      'vehiculeId': 2,
      'immatriculation': 'BB-456-CD',
      'statut': 'EN_COURS',
      'dateDebut': '2026-07-02T07:30:00',
      'site': 'Rabat',
      'branche': 'Sud',
      'distancePrevue': 85.0,
      'distanceReelle': 45.0,
    });

    await db.insert('checkups', {
      'code': 'CHP-001',
      'vehiculeId': 2,
      'immatriculation': 'BB-456-CD',
      'chauffeurId': 3,
      'chauffeurNom': 'Jean Chauffeur',
      'kilometrage': 32000,
      'conforme': 1,
      'statut': 'TERMINE',
      'dateCheckup': '2026-06-28T09:00:00',
    });
    await db.insert('checkups', {
      'code': 'CHP-002',
      'vehiculeId': 3,
      'immatriculation': 'CC-789-EF',
      'chauffeurId': 3,
      'chauffeurNom': 'Jean Chauffeur',
      'kilometrage': 58000,
      'conforme': 0,
      'statut': 'TERMINE',
      'dateCheckup': '2026-06-20T10:00:00',
      'notes': 'Freins non conformes',
    });

    await db.insert('anomalies_checkup', {
      'code': 'ANOM-001',
      'checkupId': 2,
      'element': 'Freins',
      'categorie': 'FREINAGE',
      'criticite': 'HAUTE',
      'description': 'Freins non conformes',
      'vehiculeId': 3,
      'immatriculation': 'CC-789-EF',
      'chauffeurId': 3,
      'chauffeurNom': 'Jean Chauffeur',
      'source': 'CHECKUP',
      'statut': 'OUVERTE',
    });
    await db.insert('anomalies_checkup', {
      'code': 'ANOM-002',
      'checkupId': 2,
      'element': 'Pneus arriere',
      'categorie': 'PNEUS',
      'criticite': 'MOYENNE',
      'description': 'Usure excessive pneus arriere',
      'vehiculeId': 3,
      'immatriculation': 'CC-789-EF',
      'chauffeurId': 3,
      'chauffeurNom': 'Jean Chauffeur',
      'source': 'CHECKUP',
      'statut': 'EN_COURS',
    });

    await db.insert('tickets_maintenance', {
      'numero': 'TKT-001',
      'vehiculeId': 1,
      'immatriculation': 'AA-123-BC',
      'typePanne': 'FREIN',
      'description': 'Pedale de frein molle',
      'statut': 'OUVERT',
      'priorite': 'URGENT',
      'declarePar': 3,
      'declareParNom': 'Jean Chauffeur',
      'coutEstime': 350.0,
    });
    await db.insert('tickets_maintenance', {
      'numero': 'TKT-002',
      'vehiculeId': 3,
      'immatriculation': 'CC-789-EF',
      'typePanne': 'MOTEUR',
      'description': 'Surconsommation huile moteur',
      'statut': 'EN_COURS',
      'priorite': 'NORMALE',
      'declarePar': 3,
      'declareParNom': 'Jean Chauffeur',
      'assigneA': 'Presta 1',
      'technicien': 'Technicien 1',
      'dateDebut': '2026-07-01T08:00:00',
      'coutEstime': 800.0,
    });

    await db.insert('fleet_alerts', {
      'vehiculeId': 1,
      'immatriculation': 'AA-123-BC',
      'type': 'DOCUMENT_EXPIRE',
      'criticite': 'CRITIQUE',
      'message': 'Document ASSURANCE expiré pour AA-123-BC',
      'statut': 'ACTIVE',
    });

    await db.insert('qr_codes', {
      'code': 'QR-1234567890',
      'vehiculeId': 1,
      'immatriculation': 'AA-123-BC',
      'actif': 1,
    });

    await db.insert('tracking_history', {
      'immatriculation': 'BB-456-CD',
      'latitude': 33.5731,
      'longitude': -7.5898,
      'vitesse': 45.0,
      'ignition': 1,
      'dateTracking': '2026-07-02T07:30:00',
    });
    await db.insert('tracking_history', {
      'immatriculation': 'BB-456-CD',
      'latitude': 33.8731,
      'longitude': -7.7898,
      'vitesse': 65.0,
      'ignition': 1,
      'dateTracking': '2026-07-02T08:30:00',
    });
    await db.insert('tracking_history', {
      'immatriculation': 'BB-456-CD',
      'latitude': 34.0200,
      'longitude': -6.8500,
      'vitesse': 0.0,
      'ignition': 0,
      'dateTracking': '2026-07-02T10:00:00',
    });
  }
}
