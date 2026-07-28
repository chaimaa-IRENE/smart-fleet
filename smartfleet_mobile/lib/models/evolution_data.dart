class EvolutionData {
  final String mois;
  final double coutTotal;
  final int nombrePannes;
  final Map<String, double> coutParType;
  final Map<String, double> coutParPrestataire;

  EvolutionData({
    required this.mois,
    this.coutTotal = 0,
    this.nombrePannes = 0,
    this.coutParType = const {},
    this.coutParPrestataire = const {},
  });

  factory EvolutionData.fromJson(Map<String, dynamic> json) => EvolutionData(
        mois: json['mois'] as String? ?? '',
        coutTotal: (json['coutTotal'] as num?)?.toDouble() ?? 0,
        nombrePannes: json['nombrePannes'] as int? ?? 0,
        coutParType: (json['coutParType'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            {},
        coutParPrestataire:
            (json['coutParPrestataire'] as Map<String, dynamic>?)
                    ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
                {},
      );
}

class VehicleEvolution {
  final String immatriculation;
  final List<EvolutionData> evolution;
  final List<String> moisDisponibles;

  VehicleEvolution({
    required this.immatriculation,
    this.evolution = const [],
    this.moisDisponibles = const [],
  });

  factory VehicleEvolution.fromJson(Map<String, dynamic> json) =>
      VehicleEvolution(
        immatriculation: json['immatriculation'] as String? ?? '',
        evolution: (json['evolution'] as List<dynamic>?)
                ?.map((e) => EvolutionData.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        moisDisponibles: (json['moisDisponibles'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}

class KpiData {
  final double coutMoyenParPanne;
  final double panneParVehicule;
  final double dureeMoyenneReparation;
  final double topPanne;

  KpiData({
    this.coutMoyenParPanne = 0,
    this.panneParVehicule = 0,
    this.dureeMoyenneReparation = 0,
    this.topPanne = 0,
  });

  factory KpiData.fromJson(Map<String, dynamic> json) => KpiData(
        coutMoyenParPanne: (json['coutMoyenParPanne'] as num?)?.toDouble() ?? 0,
        panneParVehicule: (json['panneParVehicule'] as num?)?.toDouble() ?? 0,
        dureeMoyenneReparation:
            (json['dureeMoyenneReparation'] as num?)?.toDouble() ?? 0,
        topPanne: (json['topPanne'] as num?)?.toDouble() ?? 0,
      );
}

class HeatmapCell {
  final String jour;
  final String heure;
  final double valeur;

  HeatmapCell({
    required this.jour,
    required this.heure,
    this.valeur = 0,
  });

  factory HeatmapCell.fromJson(Map<String, dynamic> json) => HeatmapCell(
        jour: json['jour'] as String? ?? '',
        heure: json['heure'] as String? ?? '',
        valeur: (json['valeur'] as num?)?.toDouble() ?? 0,
      );
}

class HeatmapData {
  final List<String> jours;
  final List<String> heures;
  final List<List<double>> valeurs;

  HeatmapData({
    this.jours = const [],
    this.heures = const [],
    this.valeurs = const [],
  });

  factory HeatmapData.fromJson(Map<String, dynamic> json) => HeatmapData(
        jours: (json['jours'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        heures: (json['heures'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        valeurs: (json['valeurs'] as List<dynamic>?)
                ?.map(
                  (row) => (row as List<dynamic>)
                      .map((v) => (v as num).toDouble())
                      .toList(),
                )
                .toList() ??
            [],
      );
}
