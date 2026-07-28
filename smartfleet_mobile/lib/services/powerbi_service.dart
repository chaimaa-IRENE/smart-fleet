import '../database/dao/declaration_dao.dart';
import '../database/dao/vehicle_dao.dart';

class PowerBiService {
  final DeclarationDao _declarationDao = DeclarationDao();
  final VehicleDao _vehicleDao = VehicleDao();

  Future<Map<String, dynamic>> getVehicleEvolution(
    String immat, {
    String? mois1,
    String? mois2,
  }) async {
    final vehicle = await _vehicleDao.getByImmat(immat);
    final evolution =
        await _declarationDao.getEvolution(immat, mois1: mois1, mois2: mois2);
    final moisRows = await _declarationDao.getAvailableMonths(immat);

    return {
      'immatriculation': immat,
      'marque': vehicle?['marque'] ?? '',
      'modele': vehicle?['modele'] ?? '',
      'evolution': evolution,
      'moisDisponibles': moisRows.map((r) => r['mois'] as String).toList(),
    };
  }

  Future<List<String>> getAvailableMonths(String immat) async {
    final rows = await _declarationDao.getAvailableMonths(immat);
    return rows.map((r) => r['mois'] as String).toList();
  }

  Future<Map<String, dynamic>> getKpiData(
    String immat, {
    String? mois1,
    String? mois2,
  }) async {
    final evolution =
        await _declarationDao.getEvolution(immat, mois1: mois1, mois2: mois2);
    double coutTotal = 0;
    int panneCount = 0;
    double maxCout = 0;
    String topPanne = '';

    final typeCounts = <String, int>{};
    final typeCosts = <String, double>{};

    for (var row in evolution) {
      coutTotal += (row['coutTotal'] as num).toDouble();
      panneCount += row['nombrePannes'] as int;
    }

    final allDeclarations = await _declarationDao.getByVehicle(immat);
    for (var d in allDeclarations) {
      final type = d['typePanne'] as String? ?? 'AUTRE';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      typeCosts[type] =
          (typeCosts[type] ?? 0) + ((d['coutReel'] as num?)?.toDouble() ?? 0);

      if ((typeCosts[type] ?? 0) > maxCout) {
        maxCout = typeCosts[type] ?? 0;
        topPanne = type;
      }
    }

    final vehicleCount = await _vehicleDao.count();

    return {
      'coutMoyenParPanne': panneCount > 0 ? coutTotal / panneCount : 0,
      'panneParVehicule': vehicleCount > 0 ? panneCount / vehicleCount : 0,
      'dureeMoyenneReparation': 0,
      'topPanne': topPanne,
      'typeCounts': typeCounts,
      'typeCosts': typeCosts,
    };
  }

  Future<Map<String, dynamic>> getHeatmap(
    String immat, {
    String? mois,
  }) async {
    final declarations = await _declarationDao.getByVehicle(immat);
    final jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final heures =
        List.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00');
    final valeurs = List.generate(7, (_) => List.generate(24, (_) => 0.0));

    for (var d in declarations) {
      if (mois != null) {
        final dateMois = (d['dateCreation'] as String?) ?? '';
        if (!dateMois.startsWith(mois)) continue;
      }
      try {
        final dateStr = d['dateCreation'] as String? ?? '';
        if (dateStr.length >= 16) {
          final dt = DateTime.parse(dateStr.substring(0, 16));
          final jourIdx = dt.weekday - 1;
          final heureIdx = dt.hour;
          if (jourIdx >= 0 && jourIdx < 7 && heureIdx >= 0 && heureIdx < 24) {
            valeurs[jourIdx][heureIdx] += 1;
          }
        }
      } catch (_) {}
    }

    return {
      'jours': jours,
      'heures': heures,
      'valeurs': valeurs,
    };
  }

  Future<Map<String, dynamic>> getOverview() async {
    final allDecs = await _declarationDao.getAll();
    final total = allDecs.length;
    final coutTotal = allDecs.fold<double>(
      0,
      (sum, d) => sum + ((d['coutReel'] as num?)?.toDouble() ?? 0),
    );
    final enAttente = allDecs.where((d) => d['statut'] == 'EN_ATTENTE').length;
    final enCours = allDecs
        .where((d) =>
            d['statut'] == 'PRISE_EN_CHARGE' || d['statut'] == 'EN_COURS',)
        .length;
    final cloture = allDecs.where((d) => d['statut'] == 'CLOTURE').length;

    return {
      'totalDeclarations': total,
      'coutTotal': coutTotal,
      'enAttente': enAttente,
      'enCours': enCours,
      'cloture': cloture,
    };
  }
}
