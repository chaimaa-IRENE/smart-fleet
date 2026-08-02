import 'package:flutter/material.dart';
import 'powerbi_data.dart';
import 'powerbi_theme.dart';
import 'powerbi_widgets.dart';

class AnomalyAnalysisView extends StatefulWidget {
  final DashboardData data;
  const AnomalyAnalysisView({super.key, required this.data});

  @override
  State<AnomalyAnalysisView> createState() => _AnomalyAnalysisViewState();
}

class _AnomalyAnalysisViewState extends State<AnomalyAnalysisView> {
  String _search = '';
  String _tab = 'ouvertes';

  List<MapEntry<String, num>> _entries(Map<String, dynamic>? map) {
    return (map ?? {}).entries.map((e) => MapEntry(e.key, (e.value as num?)?.toDouble() ?? 0)).toList();
  }

  List<DeclarationRow> get _filteredDeclarations {
    var items = widget.data.declarations;
    if (_tab == 'ouvertes') {
      items = items.where((d) =>
          d.statut != 'CLOTURE' && d.statut != 'RESOLU' && d.statut != 'ANNULE').toList();
    }
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((d) =>
        d.numeroDemande.toLowerCase().contains(q) ||
        d.vehicule.toLowerCase().contains(q) ||
        d.chauffeur.toLowerCase().contains(q) ||
        d.typePanne.toLowerCase().contains(q) ||
        d.element.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final kpis = data.kpis;
    final charts = data.charts;

    final mttr = (kpis['mttr'] as num?)?.toDouble() ?? 0;
    final tpmi = mttr > 0 ? (100 - (mttr / 48) * 100).round().clamp(0, 100) : 0;
    final gaugeColor = tpmi >= 80 ? PbiColors.emerald : tpmi >= 50 ? PbiColors.amber : PbiColors.rose;

    final categorieChart = _entries(charts['declarationsParCategorie'] as Map<String, dynamic>?)
        .isNotEmpty
        ? _entries(charts['declarationsParCategorie'] as Map<String, dynamic>?)
        : _entries(charts['declarationsParCriticite'] as Map<String, dynamic>?);
    final criticiteChart = _entries(charts['declarationsParCriticite'] as Map<String, dynamic>?);
    final sourceChart = _entries(charts['anomaliesParSource'] as Map<String, dynamic>?);
    final statutChart = _entries(charts['declarationsParStatut'] as Map<String, dynamic>?);
    final elementChart = _entries(charts['anomaliesParElement'] as Map<String, dynamic>?)
      ..sort((a, b) => b.value.compareTo(a.value));

    final pdrGroups = <String, double>{};
    for (final d in data.declarations) {
      if (d.cout > 0) {
        pdrGroups[d.typePanne] = (pdrGroups[d.typePanne] ?? 0) + d.cout;
      }
    }
    var pdrChart = pdrGroups.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (pdrChart.isNotEmpty) {
      pdrChart = pdrChart.take(10).map((e) => MapEntry(e.key, e.value.roundToDouble())).toList();
    } else {
      final byCount = <String, num>{};
      for (final d in data.declarations) {
        byCount[d.typePanne] = (byCount[d.typePanne] ?? 0) + 1;
      }
      pdrChart = byCount.entries
          .map((e) => MapEntry(e.key, e.value.toDouble()))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      pdrChart = pdrChart.take(10).toList();
    }

    final evolution = (charts['evolutionMensuelle'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final kpiRow = <({String label, String value, String icon, Color color})>[
      (label: 'Temps moyen réparation', value: '${mttr.round()}h', icon: 'Clock', color: PbiColors.amber),
      (label: 'Anomalies totales', value: '${kpis['anomaliesOuvertes'] ?? 0}', icon: 'AlertTriangle', color: PbiColors.rose),
      (label: 'Tickets ouverts', value: '${kpis['ticketsOuverts'] ?? 0}', icon: 'Wrench', color: PbiColors.amber),
      (label: 'Taux résolution', value: '${kpis['slaCompliance'] ?? 0}%', icon: 'CheckCircle', color: PbiColors.emerald),
      (label: 'Déclarations', value: '${kpis['totalDeclarations'] ?? 0}', icon: 'FileText', color: PbiColors.blue),
      (label: 'Taux conformité checkup', value: '${kpis['txCheckupConformite'] ?? 0}%', icon: 'Shield', color: PbiColors.cyan),
      (label: 'MTBF', value: '${kpis['mtbf'] ?? 0}j', icon: 'Activity', color: PbiColors.violet),
      (label: 'SLA', value: '${kpis['slaCompliance'] ?? 0}%', icon: 'TrendingUp', color: PbiColors.indigo),
    ];

    final filtered = _filteredDeclarations;

    Widget kpiCard(({String label, String value, String icon, Color color}) k) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x991E293B), Color(0x991A2436)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x0DFFFFFF)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: k.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
              child: Center(child: pbiIcon(k.icon, size: 19, color: k.color)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(k.value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(height: 2),
                  Text(k.label,
                      style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget tpmiGauge() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth.clamp(0.0, 160.0).toDouble();
          return SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _TpmiPainter(tpmi: tpmi, color: gaugeColor),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$tpmi%', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Text('TPMI', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PbiKpiGrid(children: kpiRow.map(kpiCard).toList()),
        const SizedBox(height: 14),
        PbiStackRow(
          children: [
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'Taux réparation première intervention', icon: 'Wrench', iconColor: PbiColors.amber),
                  Center(child: tpmi > 0 ? tpmiGauge() : const PbiEmptyState(icon: 'anomaly', message: 'Aucune donnée')),
                ],
              ),
            ),
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'Par catégorie', icon: 'FileText', iconColor: PbiColors.blue),
                  PbiDonut(
                    data: categorieChart.map((e) => MapEntry(e.key, e.value.toDouble())).toList(),
                    colorFor: (i) => chartColor(i),
                    centerValue: categorieChart.fold<num>(0, (s, e) => s + e.value).toDouble(),
                    centerLabel: '',
                    height: 230,
                    innerRadius: 38,
                    outerRadius: 58,
                  ),
                ],
              ),
            ),
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'Par gravité', icon: 'AlertTriangle', iconColor: PbiColors.rose),
                  PbiDonut(
                    data: criticiteChart.map((e) => MapEntry(e.key, e.value.toDouble())).toList(),
                    colorFor: (i) => chartColor(i),
                    centerValue: criticiteChart.fold<num>(0, (s, e) => s + e.value).toDouble(),
                    centerLabel: '',
                    height: 230,
                    innerRadius: 38,
                    outerRadius: 58,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PbiStackRow(
          children: [
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'Par source', icon: 'Zap', iconColor: PbiColors.amber),
                  PbiDonut(
                    data: sourceChart.map((e) => MapEntry(e.key, e.value.toDouble())).toList(),
                    colorFor: (i) => chartColor(i),
                    centerValue: sourceChart.fold<num>(0, (s, e) => s + e.value).toDouble(),
                    centerLabel: '',
                    height: 230,
                    innerRadius: 38,
                    outerRadius: 58,
                  ),
                ],
              ),
            ),
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'Évolution anomalies & réparations', icon: 'Activity', iconColor: PbiColors.violet),
                  PbiComposedChart(
                    data: evolution,
                    bars: [(key: 'anomalies', name: 'Anomalies', color: PbiColors.rose, width: null, barRadius: 6, barWidth: 12)],
                    lines: [
                      (key: 'resolues', name: 'Résolues', color: PbiColors.emerald, width: 2.5),
                      (key: 'critiques', name: 'Critiques', color: PbiColors.amber, width: 2),
                    ],
                    height: 240,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PbiStackRow(
          children: [
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'Répartition par élément', icon: 'Truck', iconColor: PbiColors.cyan),
                  if (elementChart.isEmpty)
                    const PbiEmptyState(icon: 'anomaly', message: 'Aucune donnée')
                  else
                    SizedBox(
                      height: (elementChart.length * 36 + 20).clamp(0, 300).toDouble(),
                      child: PbiBarChart(
                        data: elementChart.map((e) => {'name': e.key, 'value': e.value}).toList(),
                        dataKey: 'value',
                        name: 'Valeur',
                        color: PbiColors.blue,
                        height: (elementChart.length * 36 + 20).clamp(0, 300).toDouble(),
                        vertical: true,
                        barRadius: 4,
                      ),
                    ),
                ],
              ),
            ),
            PbiCard(
              child: Column(
                children: [
                  const CardHeader(title: 'PDR consommés', icon: 'DollarSign', iconColor: PbiColors.emerald),
                  if (pdrChart.isEmpty)
                    const PbiEmptyState(icon: 'document', message: 'Aucune donnée')
                  else
                    SizedBox(
                      height: (pdrChart.length * 36 + 20).clamp(0, 300).toDouble(),
                      child: PbiBarChart(
                        data: pdrChart.map((e) => {'name': e.key, 'value': e.value}).toList(),
                        dataKey: 'value',
                        name: 'Coût',
                        color: PbiColors.emerald,
                        height: (pdrChart.length * 36 + 20).clamp(0, 300).toDouble(),
                        vertical: true,
                        barRadius: 4,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PbiCard(
          child: Column(
            children: [
              const CardHeader(title: 'Répartition par statut', icon: 'Activity', iconColor: PbiColors.violet),
              PbiDonut(
                data: statutChart.map((e) => MapEntry(e.key, e.value.toDouble())).toList(),
                colorFor: (i) => chartColor(i),
                centerValue: statutChart.fold<num>(0, (s, e) => s + e.value).toDouble(),
                centerLabel: '',
                height: 240,
                innerRadius: 38,
                outerRadius: 58,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x991E293B), Color(0x991A2436)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x0DFFFFFF)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabBar = Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(child: _tabButton('ouvertes', 'Anomalies ouvertes')),
                    Expanded(child: _tabButton('historique', 'Historique')),
                  ],
                ),
              );
              final searchField = TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(fontSize: 11, color: Color(0xFFE5E7EB)),
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    prefixIcon: const Icon(Icons.search, size: 14, color: Color(0xFF9CA3AF)),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0x333B82F6)),
                    ),
                  ),
              );
              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tabBar,
                    const SizedBox(height: 8),
                    searchField,
                  ],
                );
              }
              return Row(
                children: [
                  Flexible(child: tabBar),
                  const SizedBox(width: 10),
                  Expanded(child: searchField),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        PbiTable(
          headers: const [
            ('N° Demande', PbiAlign.left),
            ('Véhicule', PbiAlign.left),
            ('Chauffeur', PbiAlign.left),
            ('Type Panne', PbiAlign.left),
            ('Élément', PbiAlign.left),
            ('Criticité', PbiAlign.center),
            ('Statut', PbiAlign.center),
            ('Date', PbiAlign.center),
            ('Coût', PbiAlign.right),
          ],
          maxHeight: 380,
          rowHeight: 38,
          rows: [
            for (final d in filtered.take(50))
              [
                Text(d.numeroDemande.isNotEmpty ? d.numeroDemande : '—', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontFamily: 'monospace')),
                Text(d.vehicule, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFE5E7EB), fontFamily: 'monospace')),
                Text(d.chauffeur, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)), overflow: TextOverflow.ellipsis),
                Text(d.typePanne, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFFE5E7EB)), overflow: TextOverflow.ellipsis),
                Text(d.element.isNotEmpty ? d.element : '—', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)), overflow: TextOverflow.ellipsis),
                PbiStatusBadge(
                  label: d.criticite,
                  color: (d.criticite == 'CRITIQUE' || d.criticite == 'BLOQUANT')
                      ? PbiColors.rose
                      : d.criticite == 'MAJEURE'
                          ? PbiColors.amber
                          : PbiColors.blue,
                ),
                PbiStatusBadge(
                  label: d.statut,
                  color: (d.statut == 'CLOTURE' || d.statut == 'RESOLU')
                      ? PbiColors.emerald
                      : d.statut == 'ANNULE'
                          ? PbiColors.slate
                          : PbiColors.amber,
                ),
                Text(
                  d.date.contains('T') ? d.date.split('T').first : (d.date.isNotEmpty ? d.date : '—'),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                ),
                Text(
                  d.cout > 0 ? '${formatNumber(d.cout.round())} DH' : '—',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE5E7EB)),
                ),
              ],
          ],
          empty: const PbiEmptyState(icon: 'anomaly', message: 'Aucune anomalie trouvée'),
        ),
      ],
    );
  }

  Widget _tabButton(String key, String label) {
    final active = _tab == key;
    return InkWell(
      onTap: () => setState(() => _tab = key),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0x333B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: active ? const Color(0xFF60A5FA) : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}

class _TpmiPainter extends CustomPainter {
  final int tpmi;
  final Color color;

  _TpmiPainter({required this.tpmi, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = 68.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = const Color(0x10FFFFFF);
    canvas.drawArc(rect, 0, 3.14159 * 2, false, track);
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -3.14159 / 2, (tpmi / 100) * 3.14159 * 2, false, progress);
  }

  @override
  bool shouldRepaint(covariant _TpmiPainter oldDelegate) =>
      oldDelegate.tpmi != tpmi || oldDelegate.color != color;
}
