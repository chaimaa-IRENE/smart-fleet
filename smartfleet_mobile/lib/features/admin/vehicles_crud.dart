import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../services/vehicle_service.dart';
import '../../widgets/status_badge.dart';
import '../../features/common/error_screen.dart';

class VehiclesCrud extends StatefulWidget {
  const VehiclesCrud({super.key});

  @override
  State<VehiclesCrud> createState() => _VehiclesCrudState();
}

class _VehiclesCrudState extends State<VehiclesCrud> {
  final VehicleService _svc = VehicleService();
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _statutFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _vehicles = await _svc.getAll();
      _applyFilter();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilter() {
    setState(() {
      _filtered = _vehicles.where((v) {
        final q = _search.toLowerCase();
        if (q.isNotEmpty) {
          final immat = (v['immatriculation'] as String? ?? '').toLowerCase();
          final marque = (v['marque'] as String? ?? '').toLowerCase();
          final chNom = (v['chauffeurNom'] as String? ?? '').toLowerCase();
          final truckNum = (v['truckNumber'] as String? ?? '').toLowerCase();
          if (!immat.contains(q) && !marque.contains(q) && !chNom.contains(q) && !truckNum.contains(q)) {
            return false;
          }
        }
        if (_statutFilter.isNotEmpty && v['statut'] != _statutFilter) return false;
        return true;
      }).toList();
    });
  }

  void _showVehicleDialog({Map<String, dynamic>? vehicle}) {
    final immatCtrl = TextEditingController(text: vehicle?['immatriculation'] ?? '');
    final truckCtrl = TextEditingController(text: vehicle?['truckNumber'] ?? '');
    final marqueCtrl = TextEditingController(text: vehicle?['marque'] ?? '');
    final modeleCtrl = TextEditingController(text: vehicle?['modele'] ?? '');
    final anneeCtrl = TextEditingController(text: vehicle?['annee']?.toString() ?? '');
    final kmCtrl = TextEditingController(text: vehicle?['kilometrage']?.toString() ?? '');
    final agenceCtrl = TextEditingController(text: vehicle?['agence'] ?? '');
    final chNomCtrl = TextEditingController(text: vehicle?['chauffeurNom'] ?? '');
    final tourneeCtrl = TextEditingController(text: vehicle?['tournee'] ?? '');
    final vehicleIdCtrl = TextEditingController(text: vehicle?['vehicleId']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: vehicle?['notes'] ?? '');
    String type = vehicle?['type'] ?? 'CAMION';
    String statut = vehicle?['statut'] ?? 'DISPONIBLE';
    String carburant = vehicle?['carburant'] ?? 'Diesel';
    bool conforme = vehicle?['conforme'] == 1 || vehicle?['conforme'] == true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(vehicle != null ? 'Modifier ${vehicle['immatriculation']}' : 'Nouveau véhicule'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: immatCtrl, decoration: const InputDecoration(labelText: 'Immatriculation *')),
              const SizedBox(height: 8),
              TextField(controller: truckCtrl, decoration: const InputDecoration(labelText: 'N° Camion')),
              const SizedBox(height: 8),
              TextField(controller: marqueCtrl, decoration: const InputDecoration(labelText: 'Marque')),
              const SizedBox(height: 8),
              TextField(controller: modeleCtrl, decoration: const InputDecoration(labelText: 'Modèle')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: anneeCtrl, decoration: const InputDecoration(labelText: 'Année'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: kmCtrl, decoration: const InputDecoration(labelText: 'Km'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 8),
              TextField(controller: agenceCtrl, decoration: const InputDecoration(labelText: 'Agence')),
              const SizedBox(height: 8),
              TextField(controller: chNomCtrl, decoration: const InputDecoration(labelText: 'Chauffeur')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: carburant,
                decoration: const InputDecoration(labelText: 'Carburant'),
                items: const [
                  DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
                  DropdownMenuItem(value: 'Essence', child: Text('Essence')),
                  DropdownMenuItem(value: 'Electrique', child: Text('Electrique')),
                  DropdownMenuItem(value: 'GPL', child: Text('GPL')),
                ],
                onChanged: (v) => setDState(() => carburant = v ?? 'Diesel'),
              ),
              const SizedBox(height: 8),
              TextField(controller: tourneeCtrl, decoration: const InputDecoration(labelText: 'Tournée')),
              const SizedBox(height: 8),
              TextField(controller: vehicleIdCtrl, decoration: const InputDecoration(labelText: 'Véhicule ID'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'CAMION', child: Text('Camion')),
                  DropdownMenuItem(value: 'UTILITAIRE', child: Text('Utilitaire')),
                  DropdownMenuItem(value: 'FOURGON', child: Text('Fourgon')),
                  DropdownMenuItem(value: 'TRACTEUR', child: Text('Tracteur')),
                ],
                onChanged: (v) => setDState(() => type = v ?? 'CAMION'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: statut,
                decoration: const InputDecoration(labelText: 'Statut'),
                items: const [
                  DropdownMenuItem(value: 'DISPONIBLE', child: Text('Disponible')),
                  DropdownMenuItem(value: 'BLOQUE', child: Text('Bloqué')),
                  DropdownMenuItem(value: 'EN_MAINTENANCE', child: Text('En maintenance')),
                ],
                onChanged: (v) => setDState(() => statut = v ?? 'DISPONIBLE'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Conforme'),
                value: conforme,
                onChanged: (v) => setDState(() => conforme = v ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(Translations.t('common.cancel'))),
            ElevatedButton(onPressed: () async {
              if (immatCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Immatriculation requise')));
                return;
              }
              final data = <String, dynamic>{
                'immatriculation': immatCtrl.text.trim(),
                'truckNumber': truckCtrl.text.trim(),
                'marque': marqueCtrl.text.trim(),
                'modele': modeleCtrl.text.trim(),
                'annee': int.tryParse(anneeCtrl.text),
                'kilometrage': int.tryParse(kmCtrl.text),
                'type': type,
                'statut': statut,
                'conforme': conforme ? 1 : 0,
                'agence': agenceCtrl.text.trim(),
                'chauffeurNom': chNomCtrl.text.trim(),
                'carburant': carburant,
                'tournee': tourneeCtrl.text.trim(),
                'vehicleId': int.tryParse(vehicleIdCtrl.text),
                'notes': notesCtrl.text.trim(),
              };
              if (vehicle != null) {
                await _svc.update(vehicle['id'] as int, data);
              } else {
                await _svc.create(data);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }, child: Text(Translations.t('common.save'))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _vehicles.length;
    final dispo = _vehicles.where((v) => v['statut'] == 'DISPONIBLE').length;
    final bloque = _vehicles.where((v) => v['statut'] == 'BLOQUE').length;
    final nonConf = _vehicles.where((v) => v['conforme'] != 1).length;

    return Scaffold(
      appBar: AppBar(title: Text(Translations.t('nav.vehicles'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showVehicleDialog(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorScreen(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Row(children: [
                        Expanded(child: _kpiCard('Total', '$total', Icons.directions_car, AppTheme.primary)),
                        const SizedBox(width: 8),
                        Expanded(child: _kpiCard('Dispo', '$dispo', Icons.check_circle, AppTheme.success)),
                        const SizedBox(width: 8),
                        Expanded(child: _kpiCard('Bloqués', '$bloque', Icons.block, AppTheme.danger)),
                        const SizedBox(width: 8),
                        Expanded(child: _kpiCard('Non conf.', '$nonConf', Icons.warning, AppTheme.warning)),
                      ]),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher par immat, marque, chauffeur...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onChanged: (v) { _search = v; _applyFilter(); },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _filterChip('Tous', '', AppTheme.primary),
                            _filterChip('Disponible', 'DISPONIBLE', AppTheme.success),
                            _filterChip('Bloqué', 'BLOQUE', AppTheme.danger),
                            _filterChip('En maintenance', 'EN_MAINTENANCE', AppTheme.warning),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_filtered.isEmpty)
                        const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Aucun véhicule')))
                      else
                        ..._filtered.map((v) => _buildVehicleCard(v)),
                    ],
                  ),
                ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ]),
      ),
    );
  }

  Widget _filterChip(String label, String value, Color color) {
    final active = _statutFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: active ? Colors.white : null)),
        selected: active,
        onSelected: (_) { setState(() => _statutFilter = value); _applyFilter(); },
        selectedColor: color,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> v) {
    final immat = v['immatriculation'] as String? ?? '';
    final marque = v['marque'] as String? ?? '';
    final modele = v['modele'] as String? ?? '';
    final statut = v['statut'] as String? ?? 'DISPONIBLE';
    final chNom = v['chauffeurNom'] as String?;
    final conforme = v['conforme'] == 1 || v['conforme'] == true;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          child: Icon(conforme ? Icons.check_circle : Icons.warning, color: conforme ? AppTheme.success : AppTheme.warning),
        ),
        title: Text(immat, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace')),
        subtitle: Text('$marque $modele${chNom != null ? '  •  $chNom' : ''}', style: const TextStyle(fontSize: 12)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.expand_more, size: 20, color: Colors.grey),
          const SizedBox(width: 2),
          if (conforme) Icon(Icons.verified, size: 16, color: AppTheme.success) else Icon(Icons.gpp_bad, size: 16, color: AppTheme.danger),
          const SizedBox(width: 4),
          StatusBadge(status: statut),
          IconButton(
            icon: Icon(Icons.edit, size: 20, color: AppTheme.primary),
            onPressed: () => _showVehicleDialog(vehicle: v),
          ),
          PopupMenuButton(
            itemBuilder: (_) => [
              PopupMenuItem(value: 'DISPONIBLE', child: const Text('Disponible')),
              PopupMenuItem(value: 'BLOQUE', child: const Text('Bloquer')),
              PopupMenuItem(value: 'EN_MAINTENANCE', child: const Text('En maintenance')),
              if (!conforme) PopupMenuItem(value: 'conforme', child: const Text('Marquer conforme')),
              const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: AppTheme.danger))),
            ],
            onSelected: (value) async {
              if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirmation'),
                    content: Text('Supprimer le véhicule $immat ?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer', style: TextStyle(color: AppTheme.danger))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _svc.delete(v['id'] as int);
                  _load();
                }
                return;
              }
              if (value == 'conforme') {
                await _svc.update(v['id'] as int, {'conforme': 1});
              } else {
                await _svc.update(v['id'] as int, {'statut': value});
              }
              _load();
            },
          ),
        ]),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _detailRow('Marque', v['marque'] as String? ?? '', 'Modèle', v['modele'] as String? ?? ''),
              const SizedBox(height: 4),
              _detailRow('Année', v['annee']?.toString() ?? '', 'Carburant', v['carburant'] as String? ?? ''),
              const SizedBox(height: 4),
              _detailRow('Véhicule ID', v['vehicleId']?.toString() ?? '', 'Tournée', v['tournee'] as String? ?? ''),
              if ((v['notes'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Text('Notes: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  Expanded(child: Text(v['notes'] as String? ?? '', style: const TextStyle(fontSize: 12))),
                ]),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label1, String val1, String label2, String val2) {
    return Row(children: [
      Expanded(child: Text('$label1: $val1', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
      const SizedBox(width: 8),
      Expanded(child: Text('$label2: $val2', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
    ]);
  }
}
