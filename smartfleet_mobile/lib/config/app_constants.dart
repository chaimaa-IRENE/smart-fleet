class AppConstants {
  static const String appName = 'SmartFleet';
  static const String appNameAr = 'أسطول ذكي';
  static const String dbVersion = '3';
  static const String syncIntervalSeconds = '30';

  static const List<String> roles = [
    'ADMIN',
    'RS',
    'SL',
    'RPF',
    'DRL',
    'CHAUFFEUR',
    'PRESTATAIRE',
    'MAINTENANCE',
  ];

  static const Map<String, String> roleLabels = {
    'ADMIN': 'Administrateur',
    'RS': 'Responsable Service',
    'SL': 'Superviseur Logistique',
    'RPF': 'Responsable Parc & Flotte',
    'DRL': 'Direction Logistique',
    'CHAUFFEUR': 'Chauffeur',
    'PRESTATAIRE': 'Prestataire',
    'MAINTENANCE': 'Maintenance',
  };

  static const List<String> declarationStatuses = [
    'EN_ATTENTE',
    'PRISE_EN_CHARGE',
    'EN_COURS',
    'EN_VALIDATION',
    'TRAITE',
    'CLOTURE',
    'RETOURNEE',
    'REJETEE',
    'REFUSE',
  ];

  static const Map<String, String> declarationStatusLabels = {
    'EN_ATTENTE': 'En attente',
    'PRISE_EN_CHARGE': 'Prise en charge',
    'EN_COURS': 'En cours',
    'EN_VALIDATION': 'En validation',
    'TRAITE': 'Traité',
    'CLOTURE': 'Clôturée',
    'RETOURNEE': 'Retournée',
    'REJETEE': 'Rejetée',
    'REFUSE': 'Refusée',
  };

  static const List<String> ticketStatuses = [
    'OUVERT',
    'AFFECTE',
    'EN_COURS',
    'CLOTURE',
  ];

  static const Map<String, String> ticketStatusLabels = {
    'OUVERT': 'Ouvert',
    'AFFECTE': 'Affecté',
    'EN_COURS': 'En cours',
    'CLOTURE': 'Clôturé',
  };

  static const List<String> anomalieStatuses = [
    'OUVERTE',
    'EN_COURS',
    'RESOLUE',
  ];

  static const Map<String, String> anomalieStatusLabels = {
    'OUVERTE': 'Ouverte',
    'EN_COURS': 'En cours',
    'RESOLUE': 'Résolue',
  };

  static const List<String> checklistStatuts = [
    'PENDING',
    'COMPLETE',
    'REPAIRE',
    'VALIDATED',
    'REJECTED',
  ];

  static const Map<String, String> checklistStatutLabels = {
    'PENDING': 'En attente',
    'COMPLETE': 'Terminé',
    'REPAIRE': 'À réparer',
    'VALIDATED': 'Validé',
    'REJECTED': 'Rejeté',
  };

  static const List<String> typePannes = [
    'MECANIQUE',
    'ELECTRIQUE',
    'CAISSE',
    'CABINE',
    'SECURITE',
    'AUTRES',
  ];

  static const Map<String, String> typePanneLabels = {
    'MECANIQUE': 'Mécanique',
    'ELECTRIQUE': 'Électrique',
    'CAISSE': 'Caisse',
    'CABINE': 'Cabine',
    'SECURITE': 'Sécurité',
    'AUTRES': 'Autres',
  };

  static const List<String> declarationCriticites = ['BLOQUANT', 'URGENT', 'NON_BLOQUANT', 'SECURITE'];

  static const Map<String, String> declarationCriticiteLabels = {
    'BLOQUANT': 'Bloquant',
    'URGENT': 'Urgent',
    'NON_BLOQUANT': 'Non bloquant',
    'SECURITE': 'Sécurité',
  };

  static const List<String> priorites = ['NORMALE', 'URGENT', 'CRITIQUE'];

  static const List<String> elementVehicules = [
    'CABINE', 'CAISSE', 'ECLAIRAGE', 'FROID', 'MECANIQUE', 'PAPIER_ACCESSOIRE',
  ];

  static const Map<String, String> elementVehiculeLabels = {
    'CABINE': 'Cabine',
    'CAISSE': 'Caisse',
    'ECLAIRAGE': 'Éclairage',
    'FROID': 'Froid',
    'MECANIQUE': 'Mécanique',
    'PAPIER_ACCESSOIRE': 'Papier/Accessoire',
  };

  static const List<String> detailElements = [
    'KLAXON', 'PLANCHER', 'PANNEAUX', 'PLAFOND', 'FACE_AVANT',
    'PONTS', 'ETANCHEITE', 'LANIERE_ARRIERE', 'LANIERE_LATERALE',
    'MARCH_PIED', 'HAYON', 'POIGNEE_INOX', 'BARRES_PARE_CYCLISTE',
    'BANDES_REFLECHISSANTES', 'TROIS_POINTS_APPUI',
  ];

  static const Map<String, String> detailElementLabels = {
    'KLAXON': 'Klaxon',
    'PLANCHER': 'Plancher',
    'PANNEAUX': 'Panneaux',
    'PLAFOND': 'Plafond',
    'FACE_AVANT': 'Face avant',
    'PONTS': 'Ponts',
    'ETANCHEITE': 'Étanchéité',
    'LANIERE_ARRIERE': 'Lanière arrière',
    'LANIERE_LATERALE': 'Lanière latérale',
    'MARCH_PIED': 'Marchpied',
    'HAYON': 'Hayon',
    'POIGNEE_INOX': 'Poignée inox',
    'BARRES_PARE_CYCLISTE': 'Barres pare-cycliste',
    'BANDES_REFLECHISSANTES': 'Bandos réfléchissantes',
    'TROIS_POINTS_APPUI': "Trois points d'appui",
  };

  static const List<String> categoriesDecla = [
    'MECANIQUE', 'SECURITE', 'QUALITE', 'VISIBILITE', 'DOCUMENTATION_LEGALE', 'EXTERIEUR',
  ];

  static const Map<String, String> categorieDeclaLabels = {
    'MECANIQUE': 'Mécanique',
    'SECURITE': 'Sécurité',
    'QUALITE': 'Qualité',
    'VISIBILITE': 'Visibilité',
    'DOCUMENTATION_LEGALE': 'Doc. légale',
    'EXTERIEUR': 'Extérieur',
  };

  static const List<String> sourcesDeclaration = [
    'MANUEL', 'FICHE_ALERTE', 'MAINTENANCE_CURATIVE',
    'MAINT_PREV_MENSUELLE', 'MAINT_PREV_HEBDOMADAIRE',
    'MAINT_PREV_TRIMESTRIELLE', 'PANNE_MARCHE', 'INCIDENT_MARCHE',
  ];

  static const List<String> documentTypes = [
    'ASSURANCE',
    'CARTE_GRISE',
    'VISITE_TECHNIQUE',
    'VIGNETTE',
    'CONTRAT',
    'AUTRE',
  ];

  static const Map<String, String> documentTypeLabels = {
    'ASSURANCE': 'Assurance',
    'CARTE_GRISE': 'Carte grise',
    'VISITE_TECHNIQUE': 'Visite technique',
    'VIGNETTE': 'Vignette',
    'CONTRAT': 'Contrat',
    'AUTRE': 'Autre',
  };

  static const List<String> criticites = [
    'FAIBLE',
    'MOYENNE',
    'HAUTE',
    'CRITIQUE',
  ];

  static const Map<String, String> criticiteLabels = {
    'FAIBLE': 'Faible',
    'MOYENNE': 'Moyenne',
    'HAUTE': 'Haute',
    'CRITIQUE': 'Critique',
  };

  static const List<String> contratBonCommandeOptions = ['CONTRAT', 'DEVIS'];

  static const Map<String, String> contratBonCommandeLabels = {
    'CONTRAT': 'Contrat',
    'DEVIS': 'Devis',
  };

  static const List<String> deviseOptions = ['EUR', 'MAD', 'USD', 'GBP', 'CHF', 'CAD'];

  static const Map<String, String> deviseLabels = {
    'EUR': 'Euro (€)',
    'MAD': 'Dirham (MAD)',
    'USD': 'Dollar (\$)',
    'GBP': 'Livre (£)',
    'CHF': 'Franc suisse (CHF)',
    'CAD': 'Dollar canadien (CAD)',
  };

  static const List<String> etatReparationOptions = [
    'TRAITE',
    'NON_TRAITE',
    'EN_ATTENTE',
    'REPARE',
  ];

  static const Map<String, String> etatReparationLabels = {
    'TRAITE': 'Traité',
    'NON_TRAITE': 'Non traité',
    'EN_ATTENTE': 'En attente',
    'REPARE': 'Réparé',
  };

  static List<String> statusForRole(String role) {
    switch (role) {
      case 'ADMIN':
        return ['/admin'];
      case 'RS':
      case 'RPF':
      case 'DRL':
        return ['/rs'];
      case 'SL':
        return ['/sl'];
      case 'CHAUFFEUR':
        return ['/chauffeur'];
      case 'PRESTATAIRE':
      case 'MAINTENANCE':
        return ['/prestataire'];
      default:
        return ['/login'];
    }
  }
}
