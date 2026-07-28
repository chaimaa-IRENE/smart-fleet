import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/app_sizes.dart';
import '../../database/dao/depart_dao.dart';
import '../../widgets/danone_app_bar.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/premium/premium_kpi_card.dart';
import '../../widgets/premium/premium_status_badge.dart';

class DepartHistoryView extends StatefulWidget {
  final int? chauffeurId;
  const DepartHistoryView({super.key, this.chauffeurId});

  @override
  State<DepartHistoryView> createState() => _DepartHistoryViewState();
}

class _DepartHistoryViewState extends State<DepartHistoryView> {
  final DepartDao _dao = DepartDao();
  List<Map<String, dynamic>> _departs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _departs = widget.chauffeurId != null
          ? await _dao.getByChauffeur(widget.chauffeurId!)
          : await _dao.getAll();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aujourdHui = _departs.where((d) {
      final date = d['dateDepart'] as String? ?? '';
      return date.startsWith(DateTime.now().toIso8601String().substring(0, 10));
    }).length;
    final valides = _departs.where((d) => d['valide'] == true).length;

    return Scaffold(
      appBar: DanoneAppBar(title: 'Historique Départs'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                children: [
                  Row(
                    children: [
                      Expanded(child: PremiumKpiCard(
                        title: 'Total départs', value: '${_departs.length}',
                        icon: Icons.departure_board, color: AppTheme.primary,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: PremiumKpiCard(
                        title: 'Aujourd\'hui', value: '$aujourdHui',
                        icon: Icons.today, color: AppTheme.accent,
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: PremiumKpiCard(
                        title: 'Validés', value: '$valides',
                        icon: Icons.check_circle, color: AppTheme.success,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: PremiumKpiCard(
                        title: 'En cours', value: '${_departs.length - valides}',
                        icon: Icons.pending, color: AppTheme.warning,
                      )),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Départs',
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      )),
                  const SizedBox(height: 12),
                  if (_departs.isEmpty)
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.departure_board, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            Text('Aucun départ enregistré',
                                style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._departs.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildDepartCard(d),
                    )),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildDepartCard(Map<String, dynamic> d) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final immat = d['immatriculation'] as String? ?? 'N/C';
    final date = d['dateDepart'] as String? ?? '';
    final retour = d['dateRetour'] as String? ?? '';
    final type = d['typeDepart'] as String? ?? '';
    final valide = d['valide'] == true;
    final commentaire = d['commentaire'] as String?;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (valide ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  valide ? Icons.check_circle : Icons.pending,
                  color: valide ? AppTheme.success : AppTheme.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(immat,
                        style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        )),
                    if (type.isNotEmpty)
                      Text(type,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              PremiumStatusBadge(
                label: valide ? 'Validé' : 'En attente',
                status: valide ? 'VALIDEE' : 'EN_ATTENTE',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.login, size: 14, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(date.length >= 10 ? date.substring(0, 10) : date,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.6))),
              if (retour.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(Icons.logout, size: 14, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text(retour.length >= 10 ? retour.substring(0, 10) : retour,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.6))),
              ],
            ],
          ),
          if (commentaire != null && commentaire.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(commentaire,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}
