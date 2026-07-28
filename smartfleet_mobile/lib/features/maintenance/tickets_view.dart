import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/ticket_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/kpi_card.dart';

class TicketsView extends StatefulWidget {
  const TicketsView({super.key});

  @override
  State<TicketsView> createState() => _TicketsViewState();
}

class _TicketsViewState extends State<TicketsView> {
  final TicketMaintenanceService _svc = TicketMaintenanceService();
  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _filterStatut;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _tickets = await _svc.getAll(statut: _filterStatut);
      _stats = await _svc.getStats();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets maintenance'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              setState(() => _filterStatut = v);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('Tous')),
              PopupMenuItem(value: 'OUVERT', child: Text('Ouverts')),
              PopupMenuItem(value: 'AFFECTE', child: Text('Affectés')),
              PopupMenuItem(value: 'EN_COURS', child: Text('En cours')),
              PopupMenuItem(value: 'CLOTURE', child: Text('Clôturés')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: KpiCard(
                              title: 'Total',
                              value: '${_stats['total'] ?? 0}',
                              icon: Icons.build,
                              color: AppTheme.primary,),),
                      const SizedBox(width: 8),
                      Expanded(
                          child: KpiCard(
                              title: 'Ouverts',
                              value: '${_stats['ouverts'] ?? 0}',
                              icon: Icons.error_outline,
                              color: AppTheme.danger,),),
                      const SizedBox(width: 8),
                      Expanded(
                          child: KpiCard(
                              title: 'Clôturés',
                              value: '${_stats['clotures'] ?? 0}',
                              icon: Icons.task_alt,
                              color: AppTheme.success,),),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._tickets.map((t) => _buildTicketCard(t)),
                ],
              ),
            ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> t) {
    final statut = t['statut'] as String? ?? 'OUVERT';
    return Card(
      child: ExpansionTile(
        leading: Icon(
          Icons.build_circle,
          color: statut == 'CLOTURE'
              ? AppTheme.success
              : statut == 'EN_COURS'
                  ? AppTheme.accent
                  : AppTheme.warning,
        ),
        title: Text('${t['numero'] ?? ''} - ${t['immatriculation'] ?? ''}'),
        subtitle: Text('${t['typePanne'] ?? ''} • ${t['description'] ?? ''}'),
        trailing: StatusBadge(status: statut),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Technicien: ${t['technicien'] ?? 'Non assigné'}'),
                Text(
                    'Coût estimé: ${(t['coutEstime'] ?? 0).toStringAsFixed(0)} €',),
                if (t['notes'] != null) Text('Notes: ${t['notes']}'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    if (statut == 'OUVERT')
                      ElevatedButton.icon(
                        onPressed: () => _assigner(t['id'] as int),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Assigner'),
                      ),
                    if (statut == 'AFFECTE')
                      ElevatedButton.icon(
                        onPressed: () => _demarrer(t['id'] as int),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Démarrer'),
                      ),
                    if (statut == 'EN_COURS')
                      ElevatedButton.icon(
                        onPressed: () => _terminer(t['id'] as int),
                        icon: const Icon(Icons.check),
                        label: const Text('Terminer'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assigner(int id) async {
    await _svc.assigner(id, 'Technicien auto');
    _load();
  }

  Future<void> _demarrer(int id) async {
    await _svc.demarrer(id);
    _load();
  }

  Future<void> _terminer(int id) async {
    await _svc.terminer(id);
    _load();
  }

  void _showCreateDialog() {
    final immatCtrl = TextEditingController();
    final vehiculeIdCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String typePanne = 'MOTEUR';
    String priorite = 'NORMALE';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau ticket'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              DropdownButtonFormField<String>(
                initialValue: typePanne,
                decoration: const InputDecoration(labelText: 'Type panne'),
                items: const [
                  DropdownMenuItem(value: 'MOTEUR', child: Text('Moteur')),
                  DropdownMenuItem(value: 'FREIN', child: Text('Frein')),
                  DropdownMenuItem(value: 'PNEU', child: Text('Pneu')),
                  DropdownMenuItem(
                      value: 'ELECTRIQUE', child: Text('Électrique'),),
                  DropdownMenuItem(
                      value: 'CARROSSERIE', child: Text('Carrosserie'),),
                  DropdownMenuItem(value: 'AUTRE', child: Text('Autre')),
                ],
                onChanged: (v) => typePanne = v ?? 'AUTRE',
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: priorite,
                decoration: const InputDecoration(labelText: 'Priorité'),
                items: const [
                  DropdownMenuItem(value: 'NORMALE', child: Text('Normale')),
                  DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                ],
                onChanged: (v) => priorite = v ?? 'NORMALE',
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,),
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
                'typePanne': typePanne,
                'priorite': priorite,
                'description': descCtrl.text,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }
}
