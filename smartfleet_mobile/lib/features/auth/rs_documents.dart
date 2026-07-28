import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/vehicle_service.dart';
import '../../database/dao/document_dao.dart';

const _docTypes = ['ASSURANCE', 'ONSSA', 'VISITE_TECHNIQUE', 'CARTE_GRISE', 'METROLOGIQUE'];
const _docLabels = {
  'ASSURANCE': 'Assurance',
  'ONSSA': 'ONSSA',
  'VISITE_TECHNIQUE': 'Visite Technique',
  'CARTE_GRISE': 'Carte Grise',
  'METROLOGIQUE': 'Métrologique',
};
const _docIcons = {
  'ASSURANCE': Icons.shield,
  'ONSSA': Icons.description,
  'VISITE_TECHNIQUE': Icons.build,
  'CARTE_GRISE': Icons.assignment,
  'METROLOGIQUE': Icons.speed,
};

class RsDocuments extends StatefulWidget {
  const RsDocuments({super.key});

  @override
  State<RsDocuments> createState() => _RsDocumentsState();
}

class _RsDocumentsState extends State<RsDocuments> {
  final VehicleService _vSvc = VehicleService();
  final DocumentVehiculeDao _docDao = DocumentVehiculeDao();
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;
  String _search = '';
  Map<String, dynamic>? _selectedV;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_vSvc.getAll(), _docDao.getAll()]);
      if (mounted) {
        setState(() {
          _vehicles = results[0];
          _documents = results[1];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _getDoc(String immat, String type) {
    try {
      return _documents.firstWhere((d) => d['immatriculation'] == immat && d['typeDocument'] == type);
    } catch (_) {
      return null;
    }
  }

  String _docStatus(String? dateStr) {
    if (dateStr == null) return 'absent';
    try {
      final days = DateTime.parse(dateStr).difference(DateTime.now()).inDays;
      if (days < 0) return 'expire';
      if (days < 30) return 'bientot';
      return 'valide';
    } catch (_) {
      return 'absent';
    }
  }

  Color _statusColor(String status) {
    switch (status) { case 'valide': return AppTheme.success; case 'bientot': return AppTheme.warning; case 'expire': return AppTheme.danger; default: return Colors.grey; }
  }

  Future<void> _importDocument() async {
    if (_selectedV == null) return;
    final immat = _selectedV!['immatriculation'] as String;
    await showDialog(
      context: context,
      builder: (ctx) {
        String type = 'ASSURANCE';
        final numCtrl = TextEditingController();
        final propCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setDState) => AlertDialog(
            title: const Text('Importer un document'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Véhicule: $immat', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type', isDense: true),
                items: _docTypes.map((t) => DropdownMenuItem(value: t, child: Text(_docLabels[t] ?? t))).toList(),
                onChanged: (v) => setDState(() => type = v ?? 'ASSURANCE'),
              ),
              const SizedBox(height: 8),
              TextField(controller: numCtrl, decoration: const InputDecoration(labelText: 'N° document', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: propCtrl, decoration: const InputDecoration(labelText: 'Propriétaire', isDense: true)),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton(onPressed: () async {
                await _docDao.insert({
                  'vehiculeId': _selectedV!['id'],
                  'immatriculation': immat,
                  'typeDocument': type,
                  'numeroDocument': numCtrl.text.trim(),
                  'dateExpiration': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
                  'importePar': 'RS',
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              }, child: const Text('Importer')),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _vehicles.where((v) {
      if (_search.isEmpty) return true;
      return (v['immatriculation'] as String? ?? '').toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Documents légaux')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(hintText: 'Rechercher par immatriculation...', prefixIcon: const Icon(Icons.search, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Aucun véhicule'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final v = filtered[i];
                            final immat = v['immatriculation'] as String? ?? '';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedV = v);
                                  _importDocument();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(children: [
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(immat, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                        const SizedBox(height: 6),
                                        Wrap(spacing: 6, runSpacing: 6, children: _docTypes.map((dt) {
                                          final doc = _getDoc(immat, dt);
                                          final status = _docStatus(doc?['dateExpiration'] as String?);
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                                              Icon(_docIcons[dt], size: 12, color: _statusColor(status)),
                                              const SizedBox(width: 4),
                                              Text('${_docLabels[dt] ?? dt}', style: TextStyle(fontSize: 9, color: _statusColor(status), fontWeight: FontWeight.w600)),
                                            ]),
                                          );
                                        }).toList()),
                                      ]),
                                    ),
                                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                                  ]),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey[100], border: Border(top: BorderSide(color: Colors.grey[300]!))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _legend(AppTheme.success, 'Valide'),
                  const SizedBox(width: 16),
                  _legend(AppTheme.warning, 'Expire bientôt'),
                  const SizedBox(width: 16),
                  _legend(AppTheme.danger, 'Expiré'),
                  const SizedBox(width: 16),
                  _legend(Colors.grey, 'Absent'),
                ]),
              ),
            ]),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: color)),
    ]);
  }
}
