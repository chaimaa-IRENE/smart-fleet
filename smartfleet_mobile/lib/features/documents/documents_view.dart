import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/document_service.dart';
import '../../widgets/status_badge.dart';

class DocumentsView extends StatefulWidget {
  const DocumentsView({super.key});

  @override
  State<DocumentsView> createState() => _DocumentsViewState();
}

class _DocumentsViewState extends State<DocumentsView> {
  final DocumentVehiculeService _svc = DocumentVehiculeService();
  List<Map<String, dynamic>> _docs = [];
  List<Map<String, dynamic>> _expired = [];
  List<Map<String, dynamic>> _expiring = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _docs = await _svc.getAll();
      _expired = await _svc.getExpired();
      _expiring = await _svc.getExpiringSoon(30);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documents réglementaires')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_expired.isNotEmpty)
                    Card(
                      color: AppTheme.danger.withValues(alpha: 0.1),
                      child: ListTile(
                        leading:
                            const Icon(Icons.error, color: AppTheme.danger),
                        title: Text('${_expired.length} document(s) expiré(s)'),
                        subtitle: const Text('Action requise'),
                      ),
                    ),
                  if (_expiring.isNotEmpty)
                    Card(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      child: ListTile(
                        leading:
                            const Icon(Icons.warning, color: AppTheme.warning),
                        title: Text(
                            '${_expiring.length} document(s) expirant bientôt',),
                        subtitle: const Text('Dans les 30 prochains jours'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ..._docs.map((d) => _buildDocCard(d)),
                ],
              ),
            ),
    );
  }

  Widget _buildDocCard(Map<String, dynamic> d) {
    final statut = _svc.getStatutDocument(d);
    return Card(
      child: ListTile(
        leading: Icon(
          _typeIcon(d['typeDocument'] as String? ?? ''),
          color: _statutColor(statut),
        ),
        title:
            Text('${d['typeDocument'] ?? ''} - ${d['immatriculation'] ?? ''}'),
        subtitle: Text('Exp: ${d['dateExpiration'] ?? 'N/A'}'),
        trailing: StatusBadge(status: statut),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'ASSURANCE':
        return Icons.security;
      case 'ONSSA':
        return Icons.verified;
      case 'VISITE_TECHNIQUE':
        return Icons.build;
      case 'CARTE_GRISE':
        return Icons.card_membership;
      case 'METROLOGIQUE':
        return Icons.scale;
      default:
        return Icons.description;
    }
  }

  Color _statutColor(String statut) {
    switch (statut) {
      case 'EXPIRE':
        return AppTheme.danger;
      case 'BIENTOT_EXPIRE':
        return AppTheme.warning;
      case 'VALIDE':
        return AppTheme.success;
      default:
        return AppTheme.textSecondary;
    }
  }

  void _showAddDialog() {
    final vehiculeIdCtrl = TextEditingController();
    final immatCtrl = TextEditingController();
    final numeroCtrl = TextEditingController();
    final dateExpCtrl = TextEditingController();
    String typeDoc = 'ASSURANCE';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau document'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: typeDoc,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                      value: 'ASSURANCE', child: Text('Assurance'),),
                  DropdownMenuItem(value: 'ONSSA', child: Text('ONSSA')),
                  DropdownMenuItem(
                      value: 'VISITE_TECHNIQUE',
                      child: Text('Visite technique'),),
                  DropdownMenuItem(
                      value: 'CARTE_GRISE', child: Text('Carte grise'),),
                  DropdownMenuItem(
                      value: 'METROLOGIQUE', child: Text('Métrologique'),),
                ],
                onChanged: (v) => typeDoc = v ?? 'ASSURANCE',
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: vehiculeIdCtrl,
                  decoration: const InputDecoration(labelText: 'ID Véhicule'),
                  keyboardType: TextInputType.number,),
              const SizedBox(height: 8),
              TextField(
                  controller: immatCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Immatriculation'),),
              const SizedBox(height: 8),
              TextField(
                  controller: numeroCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Numéro document'),),
              const SizedBox(height: 8),
              TextField(
                  controller: dateExpCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Date expiration (AAAA-MM-JJ)',),),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),),
          ElevatedButton(
            onPressed: () async {
              await _svc.create({
                'vehiculeId': int.tryParse(vehiculeIdCtrl.text) ?? 0,
                'immatriculation': immatCtrl.text,
                'typeDocument': typeDoc,
                'numeroDocument': numeroCtrl.text,
                'dateExpiration':
                    dateExpCtrl.text.isNotEmpty ? dateExpCtrl.text : null,
                'estDisponible': 1,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
