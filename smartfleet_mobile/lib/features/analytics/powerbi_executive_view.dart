import 'package:flutter/material.dart';
import 'powerbi_data.dart';
import 'powerbi_theme.dart';
import 'powerbi_widgets.dart';

class ExecutiveDashboardView extends StatefulWidget {
  final DashboardData data;
  const ExecutiveDashboardView({super.key, required this.data});

  @override
  State<ExecutiveDashboardView> createState() => _ExecutiveDashboardViewState();
}

class _ExecutiveDashboardViewState extends State<ExecutiveDashboardView> {
  bool _aiGenerating = false;
  String? _aiReport;

  List<MapEntry<String, num>> _entries(Map<String, dynamic>? map) {
    return (map ?? {}).entries.map((e) => MapEntry(e.key, (e.value as num?)?.toDouble() ?? 0)).toList();
  }

  void _handleGenerateReport() {
    setState(() {
      _aiGenerating = true;
      _aiReport = null;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final kpis = widget.data.kpis;
      final report = '**Synthèse Flotte:** ${kpis['totalVehicules'] ?? 0} véhicules, '
          '${kpis['totalDeclarations'] ?? 0} déclarations, taux de résolution '
          '${kpis['tauxResolution'] ?? 0}%, ${kpis['tauxUtilisation'] ?? 0}% utilisation.';
      setState(() {
        _aiReport = report;
        _aiGenerating = false;
      });
      _showAiReportDialog();
    });
  }

  void _showAiReportDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: PbiColors.violet),
            SizedBox(width: 8),
            Text('Rapport IA',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(_aiReport ?? '',
              style: const TextStyle(fontSize: 12, color: Color(0xFFD1D5DB))),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer', style: TextStyle(color: Color(0xFF60A5FA))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final kpis = data.kpis;
    final charts = data.charts;

    final sourceChart = _entries(charts['anomaliesParSource'] as Map<String, dynamic>?);
    final marqueChart = _entries(charts['vehiculesParMarque'] as Map<String, dynamic>?);
    final typePanneChart = _entries(charts['declarationsParTypePanne'] as Map<String, dynamic>?);
    final qualifChart = _entries(charts['declarationsParQualification'] as Map<String, dynamic>?);
    final prestataireChart = _entries(charts['interventionsParPrestataire'] as Map<String, dynamic>?);
    final documentTypeChart = _entries(charts['documentsParType'] as Map<String, dynamic>?);

    final statutChart = <MapEntry<String, double>>[
      MapEntry('En Service', (kpis['enService'] as num?)?.toDouble() ?? 0),
      MapEntry('À l\'Arrêt', (kpis['aArret'] as num?)?.toDouble() ?? 0),
      MapEntry('Maintenance', (kpis['enMaintenance'] as num?)?.toDouble() ?? 0),
      MapEntry('Bloqués', (kpis['bloques'] as num?)?.toDouble() ?? 0),
    ];

    final avgIVMS = data.vehicles.isEmpty
        ? 0
        : (data.vehicles.fold<double>(0, (s, v) => s + v.scoreIVMS) / data.vehicles.length).round();

    final kpiList = <({String label, String sub, dynamic value, String icon, Color color, String suffix, int decimals})>[
      (label: 'Total Véhicules', sub: 'Parc total', value: kpis['totalVehicules'] ?? 0, icon: 'Truck', color: PbiColors.blue, suffix: '', decimals: 0),
      (label: 'En Service', sub: '${kpis['tauxUtilisation'] ?? 0}% utilisation', value: kpis['enService'] ?? 0, icon: 'CheckCircle', color: PbiColors.emerald, suffix: '', decimals: 0),
      (label: 'À l\'Arrêt', sub: 'Véhicules bloqués', value: kpis['aArret'] ?? 0, icon: 'XCircle', color: PbiColors.rose, suffix: '', decimals: 0),
      (label: 'En Maintenance', sub: 'En atelier', value: kpis['enMaintenance'] ?? 0, icon: 'Wrench', color: PbiColors.amber, suffix: '', decimals: 0),
      (label: 'Anomalies Ouvertes', sub: 'Non résolues', value: kpis['anomaliesOuvertes'] ?? 0, icon: 'AlertTriangle', color: PbiColors.rose, suffix: '', decimals: 0),
      (label: 'Check-ups (30j)', sub: 'Réalisés', value: kpis['totalCheckups30j'] ?? 0, icon: 'Shield', color: PbiColors.cyan, suffix: '', decimals: 0),
      (label: 'Kilométrage Total', sub: 'Milliers km', value: ((kpis['totalKm'] as num?)?.toDouble() ?? 0) / 1000, icon: 'Gauge', color: PbiColors.indigo, suffix: 'k', decimals: 0),
      (label: 'IVMS', sub: 'Score fonctionnel', value: avgIVMS, icon: 'Activity', color: PbiColors.violet, suffix: '%', decimals: 0),
      (label: 'Taux Utilisation', sub: 'Parc actif', value: kpis['tauxUtilisation'] ?? 0, icon: 'TrendingUp', color: PbiColors.emerald, suffix: '%', decimals: 0),
      (label: 'Conso Moyenne', sub: 'L/100km', value: kpis['consoMoyenne'] ?? 0, icon: 'Fuel', color: PbiColors.amber, suffix: '', decimals: 1),
      (label: 'Vitesse Moyenne', sub: 'km/h', value: kpis['vitesseMoyenne'] ?? 0, icon: 'Zap', color: PbiColors.blue, suffix: '', decimals: 1),
      (label: 'SLA', sub: 'Conformité', value: kpis['slaCompliance'] ?? 0, icon: 'Shield', color: PbiColors.violet, suffix: '%', decimals: 0),
      (label: 'Score Global Flotte', sub: 'Performance', value: avgIVMS, icon: 'Trophy', color: PbiColors.emerald, suffix: '%', decimals: 0),
      if (kpis['totalPrestataires'] != null)
        (label: 'Prestataires', sub: 'Prestataires actifs', value: kpis['totalPrestataires'] ?? 0, icon: 'Building2', color: PbiColors.blue, suffix: '', decimals: 0),
      if (kpis['totalInterventions'] != null)
        (label: 'Interventions', sub: 'Total', value: kpis['totalInterventions'] ?? 0, icon: 'Wrench', color: PbiColors.cyan, suffix: '', decimals: 0),
      if (kpis['interventionsEnCours'] != null)
        (label: 'En Cours', sub: 'Interventions', value: kpis['interventionsEnCours'] ?? 0, icon: 'Timer', color: PbiColors.amber, suffix: '', decimals: 0),
      if (kpis['interventionsTerminees'] != null)
        (label: 'Terminées', sub: 'Interventions', value: kpis['interventionsTerminees'] ?? 0, icon: 'BadgeCheck', color: PbiColors.emerald, suffix: '', decimals: 0),
      if (kpis['interventionsEnRetard'] != null)
        (label: 'En Retard', sub: 'Interventions', value: kpis['interventionsEnRetard'] ?? 0, icon: 'AlertTriangle', color: PbiColors.rose, suffix: '', decimals: 0),
      if (kpis['budgetConsomme'] != null)
        (label: 'Budget Utilisé', sub: 'DH', value: (kpis['budgetConsomme'] as num?)?.toDouble() ?? 0, icon: 'Wallet', color: PbiColors.amber, suffix: ' DH', decimals: 0),
      if (kpis['budgetRestant'] != null)
        (label: 'Budget Restant', sub: 'DH', value: (kpis['budgetRestant'] as num?)?.toDouble() ?? 0, icon: 'Wallet', color: PbiColors.emerald, suffix: ' DH', decimals: 0),
      if (kpis['coutTotalMaintenance'] != null)
        (label: 'Coût Maintenance', sub: 'DH', value: (kpis['coutTotalMaintenance'] as num?)?.toDouble() ?? 0, icon: 'Wallet', color: PbiColors.rose, suffix: ' DH', decimals: 0),
      if (kpis['documentsExpires'] != null)
        (label: 'Docs Expirés', sub: 'Documents', value: kpis['documentsExpires'] ?? 0, icon: 'FileText', color: PbiColors.rose, suffix: '', decimals: 0),
      if (kpis['documentsBientotExpire'] != null)
        (label: 'Docs < 30j', sub: 'Expiration', value: kpis['documentsBientotExpire'] ?? 0, icon: 'FileText', color: PbiColors.amber, suffix: '', decimals: 0),
      if (kpis['tauxDisponibilite'] != null)
        (label: 'Disponibilité', sub: 'Flotte', value: kpis['tauxDisponibilite'] ?? 0, icon: 'Activity', color: PbiColors.emerald, suffix: '%', decimals: 0),
      if (kpis['declarationsAujourdhui'] != null)
        (label: 'Déclarations Ajd', sub: 'Aujourd\'hui', value: kpis['declarationsAujourdhui'] ?? 0, icon: 'AlertTriangle', color: PbiColors.blue, suffix: '', decimals: 0),
      if (kpis['declarationsCeMois'] != null)
        (label: 'Déclarations/Mois', sub: 'Ce mois', value: kpis['declarationsCeMois'] ?? 0, icon: 'AlertTriangle', color: PbiColors.violet, suffix: '', decimals: 0),
    ];

    final totalAnomaliesSource = sourceChart.fold<num>(0, (s, e) => s + e.value).toDouble();

    final evolution = (charts['evolutionMensuelle'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    Map<String, dynamic>? monthlyComp;
    if (evolution.length >= 2) {
      final cur = evolution.last;
      final prev = evolution[evolution.length - 2];
      monthlyComp = {
        'curMonth': cur['mois'],
        'prevMonth': prev['mois'],
        'anomalies': (cur['anomalies'] as num?)?.toDouble() ?? 0,
        'anomaliesPrev': (prev['anomalies'] as num?)?.toDouble() ?? 0,
        'resolues': (cur['resolues'] as num?)?.toDouble() ?? 0,
        'resoluesPrev': (prev['resolues'] as num?)?.toDouble() ?? 0,
        'checkups': (cur['checkups'] as num?)?.toDouble() ?? 0,
        'checkupsPrev': (prev['checkups'] as num?)?.toDouble() ?? 0,
        'tickets': (cur['tickets'] as num?)?.toDouble() ?? 0,
        'ticketsPrev': (prev['tickets'] as num?)?.toDouble() ?? 0,
      };
    }

    Widget kpiCard(({String label, String sub, dynamic value, String icon, Color color, String suffix, int decimals}) k) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E293B), Color(0xFF1A2436)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x0FFFFFFF)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: k.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
              child: Center(child: pbiIcon(k.icon, size: 16, color: k.color)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: PbiAnimatedCounter(value: (k.value as num).toDouble(), suffix: k.suffix, decimals: k.decimals),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    k.sub,
                    style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget statusBadge(String s) {
      final c = s == 'ACTIF' ? PbiColors.emerald : s == 'MAINTENANCE' ? PbiColors.amber : PbiColors.rose;
      return PbiStatusBadge(label: s, color: c, border: true);
    }

    Widget scoreText(num v) {
      final c = (v >= 80) ? PbiColors.emerald : (v >= 50) ? PbiColors.amber : PbiColors.rose;
      return Text('$v%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c));
    }

    final sortedVehiclesIvms = data.vehicles
        .where((v) => v.scoreIVMS > 0)
        .toList()
      ..sort((a, b) => b.scoreIVMS.compareTo(a.scoreIVMS));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: _aiGenerating ? null : _handleGenerateReport,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x1A8B5CF6), Color(0x1A3B82F6)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x338B5CF6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  pbiIcon('Sparkles', size: 14, color: PbiColors.violet),
                  const SizedBox(width: 6),
                  const Text(
                    'Générer Rapport IA',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFA78BFA)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        PbiKpiGrid(children: kpiList.map(kpiCard).toList()),
        const SizedBox(height: 16),
        PbiStackRow(
          children: [
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'Répartition anomalies par source', icon: 'AlertTriangle', iconColor: PbiColors.rose),
                  PbiDonut(
                    data: sourceChart.map((e) => MapEntry(e.key, e.value.toDouble())).toList(),
                    colorFor: (i) => chartColor(i),
                    centerValue: totalAnomaliesSource,
                    centerLabel: 'Total',
                    height: 260,
                    innerRadius: 42,
                    outerRadius: 60,
                  ),
                ],
              ),
            ),
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'Répartition véhicules par statut', icon: 'Truck', iconColor: PbiColors.blue),
                  PbiDonut(
                    data: statutChart,
                    colorFor: (i) => statutChart[i].key == 'En Service'
                        ? PbiColors.emerald
                        : statutChart[i].key == 'À l\'Arrêt'
                            ? PbiColors.rose
                            : statutChart[i].key == 'Maintenance'
                                ? PbiColors.amber
                                : PbiColors.slate,
                    centerValue: (kpis['totalVehicules'] as num?)?.toDouble() ?? 0,
                    centerLabel: 'Véhicules',
                    height: 260,
                    innerRadius: 42,
                    outerRadius: 60,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Column(
          children: [
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'Taux d\'utilisation', icon: 'Activity', iconColor: PbiColors.emerald),
                  Center(child: PbiGauge(value: (kpis['tauxUtilisation'] as num?)?.toDouble() ?? 0, label: 'Taux d\'utilisation', size: 180)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: PbiMiniStat(
                          label: 'En service',
                          value: (kpis['enService'] ?? 0).toString(),
                          valueColor: PbiColors.emerald,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PbiMiniStat(
                          label: 'À l\'arrêt',
                          value: (kpis['aArret'] ?? 0).toString(),
                          valueColor: PbiColors.rose,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'Histogramme anomalies ouvertes', icon: 'BarChart3', iconColor: PbiColors.rose),
                  PbiBarChart(
                    data: evolution,
                    dataKey: 'anomalies',
                    name: 'Anomalies',
                    color: PbiColors.rose,
                    height: 200,
                    tooltipBackground: const Color(0xF20F172A),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'Comparaison mensuelle', icon: 'TrendingUp', iconColor: PbiColors.violet),
                  if (monthlyComp == null)
                    const PbiEmptyState(icon: 'truck', title: 'Prêt à démarrer', message: 'Pas de comparaison')
                  else ...[
                    for (final item in [
                      ('Anomalies', monthlyComp['anomalies'] as double, monthlyComp['anomaliesPrev'] as double),
                      ('Résolues', monthlyComp['resolues'] as double, monthlyComp['resoluesPrev'] as double),
                      ('Check-ups', monthlyComp['checkups'] as double, monthlyComp['checkupsPrev'] as double),
                      ('Tickets', monthlyComp['tickets'] as double, monthlyComp['ticketsPrev'] as double),
                    ]) ...[
                      _comparisonRow(item.$1, item.$2, item.$3, monthlyComp['prevMonth'] as String),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (data.budgetAnalysis.isNotEmpty) ...[
          PbiCard(
            child: Column(
              children: [
                const CardHeader(title: 'Budget vs Réel', icon: 'Wallet', iconColor: PbiColors.amber),
                PbiComposedChart(
                  data: data.budgetAnalysis
                      .map((b) => {'mois': b['mois'], 'budget': (b['budget'] as num?)?.toDouble() ?? 0, 'cout': (b['cout'] as num?)?.toDouble() ?? 0})
                      .toList(),
                  bars: [
                    (key: 'budget', name: 'Budget', color: PbiColors.emerald, width: null, barRadius: null, barWidth: 12),
                    (key: 'cout', name: 'Coût réel', color: PbiColors.rose, width: null, barRadius: null, barWidth: 12),
                  ],
                  lines: const [],
                  height: 220,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        PbiCard(
          child: Column(
            children: [
              const CardHeader(title: 'Évolution mensuelle', icon: 'Activity', iconColor: PbiColors.violet),
              PbiComposedChart(
                data: evolution,
                bars: [
                  (key: 'anomalies', name: 'Anomalies', color: PbiColors.rose, width: null, barRadius: 6, barWidth: 12),
                ],
                lines: [
                  (key: 'resolues', name: 'Résolues', color: PbiColors.emerald, width: 2.5),
                  (key: 'checkups', name: 'Check-ups', color: PbiColors.blue, width: 2),
                  (key: 'tickets', name: 'Tickets', color: PbiColors.amber, width: 2),
                ],
                height: 250,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        PbiStackRow(
          children: [
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'Répartition par marque', icon: 'Truck', iconColor: PbiColors.indigo),
                  _progressList(marqueChart),
                ],
              ),
            ),
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'Types d\'incident', icon: 'AlertTriangle', iconColor: PbiColors.amber),
                  _progressList(typePanneChart, colored: true),
                ],
              ),
            ),
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'Qualification', icon: 'FileText', iconColor: PbiColors.cyan),
                  if (qualifChart.isEmpty)
                    const PbiEmptyState(icon: 'document', message: 'Aucune donnée')
                  else
                    for (final (i, item) in qualifChart.indexed) ...[
                      _qualificationItem(item, i),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (documentTypeChart.isNotEmpty) ...[
          PbiCard(
            child: Column(
              children: [
                const CardHeader(title: 'Documents par type', icon: 'FileText', iconColor: PbiColors.blue),
                _progressList(documentTypeChart),
                const SizedBox(height: 10),
                if (data.documentStats != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: PbiMiniStat(
                          label: 'Valides',
                          value: '${data.documentStats!['valides'] ?? 0}',
                          valueColor: PbiColors.emerald,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PbiMiniStat(
                          label: 'Expirés',
                          value: '${data.documentStats!['expires'] ?? 0}',
                          valueColor: PbiColors.rose,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PbiMiniStat(
                          label: '< 30j',
                          value: '${data.documentStats!['bientotExpires'] ?? 0}',
                          valueColor: PbiColors.amber,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (data.aiInsights.isNotEmpty) ...[
          PbiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardHeader(title: 'Analyses IA', icon: 'BrainCircuit', iconColor: PbiColors.violet),
                for (final insight in data.aiInsights.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0x800F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0x0DFFFFFF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${insight['message'] ?? ''}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFD1D5DB)),
                          ),
                          if (insight['tendance'] != null || insight['recommandation'] != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (insight['tendance'] != null)
                                  Text(
                                    insight['tendance'] == 'hausse'
                                        ? '↑ Hausse'
                                        : insight['tendance'] == 'baisse'
                                            ? '↓ Baisse'
                                            : '→ Stable',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: insight['tendance'] == 'hausse'
                                          ? PbiColors.rose
                                          : insight['tendance'] == 'baisse'
                                              ? PbiColors.emerald
                                              : PbiColors.slate,
                                    ),
                                  ),
                                if (insight['tendance'] != null && insight['recommandation'] != null)
                                  const SizedBox(width: 10),
                                if (insight['recommandation'] != null)
                                  Expanded(
                                    child: Text(
                                      '${insight['recommandation']}',
                                      style: const TextStyle(fontSize: 9, color: Color(0xFFA78BFA)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (prestataireChart.isNotEmpty) ...[
          PbiCard(
            child: Column(
              children: [
                const CardHeader(title: 'Interventions par prestataire', icon: 'Building2', iconColor: PbiColors.amber),
                _progressList(prestataireChart, colored: true),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        PbiCard(
          child: Column(
            children: [
              const CardHeader(title: 'Aperçu véhicules', icon: 'Truck', iconColor: PbiColors.blue),
              PbiTable(
                headers: const [
                  ('Immatriculation', PbiAlign.left),
                  ('Marque', PbiAlign.left),
                  ('Statut', PbiAlign.center),
                  ('Km', PbiAlign.right),
                  ('Chauffeur', PbiAlign.left),
                  ('IVMS', PbiAlign.right),
                ],
                rows: [
                  for (final v in data.vehicles.take(20))
                    [
                      Text(v.immatriculation, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFE5E7EB), fontFamily: 'monospace')),
                      Text(v.marque, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                      statusBadge(v.statut),
                      Text(v.kilometrage > 0 ? formatNumber(v.kilometrage) : '-', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                      Text(v.chauffeurNom.isNotEmpty ? v.chauffeurNom : '-', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)), overflow: TextOverflow.ellipsis),
                      scoreText(v.scoreIVMS),
                    ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        PbiStackRow(
          children: [
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'TOP 10 Véhicules — Score IVMS', icon: 'Trophy', iconColor: PbiColors.emerald),
                  PbiTable(
                    headers: const [
                      ('#', PbiAlign.left),
                      ('Véhicule', PbiAlign.left),
                      ('Marque', PbiAlign.left),
                      ('Statut', PbiAlign.center),
                      ('Score', PbiAlign.right),
                    ],
                    rows: [
                      for (final (i, v) in sortedVehiclesIvms.take(10).indexed)
                        [
                          Text((i + 1).toString().padLeft(2, '0'), style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontFamily: 'monospace')),
                          Text(v.immatriculation, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFE5E7EB), fontFamily: 'monospace')),
                          Text(v.marque, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                          statusBadge(v.statut),
                          scoreText(v.scoreIVMS),
                        ],
                    ],
                  ),
                ],
              ),
            ),
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'TOP 10 Chauffeurs', icon: 'Users', iconColor: PbiColors.blue),
                  PbiTable(
                    headers: const [
                      ('#', PbiAlign.left),
                      ('Nom', PbiAlign.left),
                      ('Conformité', PbiAlign.center),
                      ('Anomalies', PbiAlign.center),
                      ('Score', PbiAlign.right),
                    ],
                    rows: [
                      for (final (i, d) in data.drivers.take(10).indexed)
                        [
                          Text((i + 1).toString().padLeft(2, '0'), style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontFamily: 'monospace')),
                          Text(d.nom, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFE5E7EB)), overflow: TextOverflow.ellipsis),
                          Text(
                            '${d.tauxConformite}%',
                            style: TextStyle(fontSize: 10, color: d.tauxConformite >= 80 ? PbiColors.emerald : PbiColors.amber),
                          ),
                          Text('${d.anomalies}', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                          Text('${d.score}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PbiColors.ivms(d.score.toDouble()))),
                        ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (data.alerts.isNotEmpty) ...[
          PbiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardHeader(title: 'Alertes actives', icon: 'Bell', iconColor: PbiColors.rose),
                for (final a in data.alerts.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        _pulsingDot(a.severite == 'HAUTE'
                            ? PbiColors.rose
                            : a.severite == 'MOYENNE'
                                ? PbiColors.amber
                                : PbiColors.blue),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: Text(a.type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF))),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(a.message, style: const TextStyle(fontSize: 10, color: Color(0xFFE5E7EB)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        PbiStatusBadge(
                          label: a.severite,
                          color: a.severite == 'HAUTE'
                              ? PbiColors.rose
                              : a.severite == 'MOYENNE'
                                  ? PbiColors.amber
                                  : PbiColors.blue,
                          border: true,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _comparisonRow(String label, double cur, double prev, String prevMonth) {
    final delta = cur - prev;
    final pctChange = prev > 0 ? ((delta / prev) * 100).round() : 0;
    final isUp = delta > 0;
    final isDown = delta < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x800F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text('$prevMonth: ', style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
          Text('${prev.round()}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFD1D5DB))),
          const SizedBox(width: 10),
          Text('${cur.round()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD1D5DB))),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isUp || isDown) pbiIcon(isUp ? 'TrendingUp' : 'TrendingDown', size: 10, color: isUp ? PbiColors.rose : PbiColors.emerald),
              const SizedBox(width: 2),
              Text(
                delta == 0 ? '-' : '${isUp ? '+' : ''}$pctChange%',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isUp ? PbiColors.rose : isDown ? PbiColors.emerald : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressList(List<MapEntry<String, num>> chart, {bool colored = false}) {
    if (chart.isEmpty) return const PbiEmptyState(icon: 'truck', message: 'Aucune donnée');
    final sorted = [...chart]..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<num>(0, (s, e) => s + e.value).toDouble();
    return Column(
      children: [
        for (final (i, item) in sorted.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.key, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${item.value.round()} ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colored ? chartColor(i) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    Text(
                      '(${total > 0 ? (item.value / total * 100).round() : 0}%)',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                PbiProgressBar(value: total > 0 ? item.value / total * 100 : 0, color: chartColor(i), height: 8),
              ],
            ),
          ),
      ],
    );
  }

  Widget _qualificationItem(MapEntry<String, num> item, int i) {
    final total = _qualifTotal(item);
    final c = item.key == 'PREVENTIVE'
        ? PbiColors.blue
        : item.key == 'CURATIVE'
            ? PbiColors.amber
            : PbiColors.slate;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x800F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(item.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE5E7EB))),
              const Spacer(),
              Text('${item.value.round()}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c)),
            ],
          ),
          const SizedBox(height: 8),
          PbiProgressBar(value: total > 0 ? item.value / total * 100 : 0, color: c, height: 10),
          const SizedBox(height: 4),
          Text('${total > 0 ? (item.value / total * 100).round() : 0}% du total', style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  double _qualifTotal(MapEntry<String, num> item) {
    final charts = widget.data.charts;
    final qualifChart = _entries(charts['declarationsParQualification'] as Map<String, dynamic>?);
    return qualifChart.fold<num>(0, (s, e) => s + e.value).toDouble();
  }

  Widget _pulsingDot(Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 2),
      builder: (context, v, child) => Opacity(
        opacity: 1 - v,
        child: child,
      ),
      child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    );
  }
}
