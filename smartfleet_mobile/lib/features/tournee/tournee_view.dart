import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/tournee_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/kpi_card.dart';

class TourneeView extends StatefulWidget {
  const TourneeView({super.key});

  @override
  State<TourneeView> createState() => _TourneeViewState();
}

class _TourneeViewState extends State<TourneeView> {
  final TourneeService _svc = TourneeService();
  List<Map<String, dynamic>> _tournees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = context.read<AuthProvider>().userId;
      if (userId != null) {
        _tournees = await _svc.getByChauffeur(userId);
      } else {
        _tournees = await _svc.getAll();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final planifiees =
        _tournees.where((t) => t['statut'] == 'PLANIFIEE').length;
    final enCours = _tournees.where((t) => t['statut'] == 'EN_COURS').length;
    final terminees = _tournees.where((t) => t['statut'] == 'TERMINEE').length;

    return Scaffold(
      appBar: AppBar(title: const Text('Tournées')),
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
                          title: 'Planifiées',
                          value: '$planifiees',
                          icon: Icons.schedule,
                          color: AppTheme.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: KpiCard(
                          title: 'En cours',
                          value: '$enCours',
                          icon: Icons.play_circle,
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: KpiCard(
                          title: 'Terminées',
                          value: '$terminees',
                          icon: Icons.check_circle,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._tournees.map((t) => _buildTourneeCard(t)),
                ],
              ),
            ),
    );
  }

  Widget _buildTourneeCard(Map<String, dynamic> t) {
    final statut = t['statut'] as String? ?? 'PLANIFIEE';
    return Card(
      child: ListTile(
        leading: Icon(
          statut == 'TERMINEE'
              ? Icons.flag
              : statut == 'EN_COURS'
                  ? Icons.local_shipping
                  : Icons.schedule,
          color: statut == 'TERMINEE'
              ? AppTheme.success
              : statut == 'EN_COURS'
                  ? AppTheme.accent
                  : AppTheme.warning,
        ),
        title: Text('${t['numero'] ?? ''} - ${t['immatriculation'] ?? ''}'),
        subtitle: Text(
            'Site: ${t['site'] ?? ''} • ${t['dateDebut'] ?? 'Non démarrée'}',),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge(status: statut),
            if (statut == 'PLANIFIEE')
              IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _demarrer(t['id'] as int),),
            if (statut == 'EN_COURS')
              IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: () => _terminer(t['id'] as int),),
          ],
        ),
      ),
    );
  }

  Future<void> _demarrer(int id) async {
    await _svc.demarrer(id);
    _load();
  }

  Future<void> _terminer(int id) async {
    await _svc.terminer(id);
    _load();
  }
}
