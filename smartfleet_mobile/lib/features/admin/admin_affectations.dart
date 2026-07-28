import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/vehicle_service.dart';
import '../../services/user_service.dart';

class AdminAffectations extends StatefulWidget {
  const AdminAffectations({super.key});

  @override
  State<AdminAffectations> createState() => _AdminAffectationsState();
}

class _AdminAffectationsState extends State<AdminAffectations> {
  final VehicleService _vehicleSvc = VehicleService();
  final UserService _userSvc = UserService();
  List<Map<String, dynamic>> _vehicules = [];
  List<Map<String, dynamic>> _chauffeurs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await _vehicleSvc.getAll();
      final users = await _userSvc.getAll();
      if (mounted) {
        setState(() {
          _vehicules = all;
          _chauffeurs = users.where((u) => u['role'] == 'CHAUFFEUR').toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assignChauffeur(int vehiculeId, int? chauffeurId, String? chauffeurNom) async {
    try {
      await _vehicleSvc.update(vehiculeId, {
        'chauffeurId': chauffeurId,
        'chauffeurNom': chauffeurNom,
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chauffeurId != null ? 'Chauffeur $chauffeurNom affecté' : 'Chauffeur désaffecté'),
            backgroundColor: chauffeurId != null ? AppTheme.success : AppTheme.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nonAssignes = _vehicules.where((v) => v['chauffeurId'] == null).length;
    final assignes = _vehicules.length - nonAssignes;

    return Scaffold(
      appBar: AppBar(title: const Text('Affectations Chauffeur-Camion')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: AppTheme.primary.withValues(alpha: 0.08),
                child: Row(children: [
                  Expanded(
                    child: Row(children: [
                      _statBadge('Total', '${_vehicules.length}', Icons.directions_car, AppTheme.primary),
                      const SizedBox(width: 8),
                      _statBadge('Assignés', '$assignes', Icons.person, AppTheme.success),
                      const SizedBox(width: 8),
                      _statBadge('Libres', '$nonAssignes', Icons.person_off, AppTheme.warning),
                    ]),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: AppTheme.primary.withValues(alpha: 0.04),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(                      child: Text("1 chauffeur peut avoir plusieurs camions. 1 camion ne peut appartenir qu'à un seul chauffeur.", style: TextStyle(fontSize: 11, color: AppTheme.primary))),
                ]),
              ),
              Expanded(
                child: _vehicules.isEmpty
                    ? const Center(child: Text('Aucun véhicule'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _vehicules.length,
                          itemBuilder: (_, i) {
                            final v = _vehicules[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(children: [
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('${v['truckNumber'] ?? v['immatriculation']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text(v['immatriculation'] as String? ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        Icon(Icons.person, size: 14, color: v['chauffeurNom'] != null ? AppTheme.primary : Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          v['chauffeurNom'] as String? ?? 'Non assigné',
                                          style: TextStyle(fontWeight: v['chauffeurNom'] != null ? FontWeight.w600 : FontWeight.normal, color: v['chauffeurNom'] != null ? AppTheme.primary : Colors.grey, fontStyle: v['chauffeurNom'] != null ? FontStyle.normal : FontStyle.italic, fontSize: 13),
                                        ),
                                      ]),
                                    ]),
                                  ),
                                  if (v['chauffeurId'] != null)
                                    TextButton(
                                      onPressed: () => _assignChauffeur(v['id'] as int, null, null),
                                      child: const Text('Désaffecter', style: TextStyle(fontSize: 11, color: AppTheme.danger)),
                                    ),
                                  SizedBox(
                                    width: 160,
                                    child: DropdownButtonFormField<int?>(
                                      value: v['chauffeurId'] as int?,
                                      isExpanded: true,
                                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
                                      items: [
                                        const DropdownMenuItem<int?>(value: null, child: Text('-- Aucun --', style: TextStyle(fontSize: 12))),
                                        ..._chauffeurs.map((c) => DropdownMenuItem<int?>(value: c['id'] as int, child: Text('${c['prenom'] ?? ''} ${c['nom'] ?? ''}', style: const TextStyle(fontSize: 12)))),
                                      ],
                                      onChanged: (chauffeurId) {
                                        if (chauffeurId == null) {
                                          _assignChauffeur(v['id'] as int, null, null);
                                        } else {
                                          final ch = _chauffeurs.firstWhere((c) => c['id'] == chauffeurId);
                                          _assignChauffeur(v['id'] as int, chauffeurId, '${ch['prenom'] ?? ''} ${ch['nom'] ?? ''}'.trim());
                                        }
                                      },
                                    ),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ]),
    );
  }

  Widget _statBadge(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: color)),
        ]),
      ),
    );
  }
}
