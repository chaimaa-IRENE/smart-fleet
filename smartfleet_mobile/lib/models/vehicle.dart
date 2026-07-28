class Vehicle {
  final int id;
  final String immatriculation;
  final String? marque;
  final String? modele;
  final int? annee;
  final String? statut;
  final int? kilometrage;
  final String? type;
  final int? chauffeurId;
  final String? chauffeurNom;

  Vehicle({
    required this.id,
    required this.immatriculation,
    this.marque,
    this.modele,
    this.annee,
    this.statut,
    this.kilometrage,
    this.type,
    this.chauffeurId,
    this.chauffeurNom,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as int? ?? 0,
        immatriculation: json['immatriculation'] as String? ??
            json['immat'] as String? ??
            '',
        marque: json['marque'] as String?,
        modele: json['modele'] as String?,
        annee: json['annee'] as int?,
        statut: json['statut'] as String?,
        kilometrage: json['kilometrage'] as int?,
        type: json['type'] as String?,
        chauffeurId: json['chauffeurId'] as int?,
        chauffeurNom: json['chauffeurNom'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'immatriculation': immatriculation,
        'marque': marque,
        'modele': modele,
        'annee': annee,
        'statut': statut,
        'kilometrage': kilometrage,
        'type': type,
      };
}
