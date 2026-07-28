import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../database/dao/budget_dao.dart';

class BudgetView extends StatefulWidget {
  const BudgetView({super.key});

  @override
  State<BudgetView> createState() => _BudgetViewState();
}

class _BudgetViewState extends State<BudgetView> {
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _byProvider = [];
  final BudgetDao _dao = BudgetDao();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _budgets = await _dao.getAll();
      if (_budgets.isNotEmpty) {
        _byProvider = await _dao.getByProvider(_budgets.first['id'] as int);
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Translations.t('budget.title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._budgets.map((b) => _buildBudgetCard(b)),
        const SizedBox(height: 24),
        if (_byProvider.isNotEmpty) ...[
          const Text(
            'Par prestataire',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: _byProvider.asMap().entries.map((e) {
                  final total = (e.value['total'] as num).toDouble();
                  return PieChartSectionData(
                    value: total,
                    title:
                        '${e.value['prestataire']}\n${total.toStringAsFixed(0)}€',
                    color: AppColors
                        .chartColors[e.key % AppColors.chartColors.length],
                    radius: 60,
                    titleStyle:
                        const TextStyle(fontSize: 10, color: Colors.white),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBudgetCard(Map<String, dynamic> budget) {
    final total = (budget['montantTotal'] as num?)?.toDouble() ?? 0;
    final utilise = (budget['montantUtilise'] as num?)?.toDouble() ?? 0;
    final restant = total - utilise;
    final percent = total > 0 ? (utilise / total) * 100 : 0.0;
    final statut = budget['statut'] as String? ?? 'ACTIF';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  budget['periode'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _StatusBadge(status: statut),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _LabelValue(
                  label: Translations.t('budget.total'),
                  value: '${total.toStringAsFixed(0)} €',
                ),
                const Spacer(),
                _LabelValue(
                  label: Translations.t('budget.used'),
                  value: '${utilise.toStringAsFixed(0)} €',
                ),
                const Spacer(),
                _LabelValue(
                  label: Translations.t('budget.remaining'),
                  value: '${restant.toStringAsFixed(0)} €',
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                color: percent > 80
                    ? AppTheme.danger
                    : percent > 60
                        ? AppTheme.warning
                        : AppTheme.success,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${percent.toStringAsFixed(1)}% utilisé',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;
  const _LabelValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppTheme.textSecondary),),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final isActive = status == 'ACTIF';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.success.withValues(alpha: 0.1)
            : AppTheme.textSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Actif' : 'Inactif',
        style: TextStyle(
          color: isActive ? AppTheme.success : AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
