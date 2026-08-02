import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'powerbi_data.dart';
import 'powerbi_theme.dart';
import 'powerbi_widgets.dart';

class DriverPerformanceView extends StatefulWidget {
  final DashboardData data;
  const DriverPerformanceView({super.key, required this.data});

  @override
  State<DriverPerformanceView> createState() => _DriverPerformanceViewState();
}

class _DriverPerformanceViewState extends State<DriverPerformanceView> {
  String _search = '';
  String? _selectedDriver;

  List<DriverRow> get _sortedDrivers {
    final list = [...widget.data.drivers]..sort((a, b) => b.score.compareTo(a.score));
    return list;
  }

  List<DriverRow> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _sortedDrivers;
    return _sortedDrivers.where((d) => d.nom.toLowerCase().contains(q)).toList();
  }

  DriverRow? get _driver {
    if (_selectedDriver == null) return null;
    for (final d in widget.data.drivers) {
      if (d.nom == _selectedDriver) return d;
    }
    return null;
  }

  List<DeclarationRow> get _driverDeclarations {
    final dr = _driver;
    if (dr == null) return [];
    return widget.data.declarations.where((d) => d.chauffeur == dr.nom).toList();
  }

  Color _scoreColor(num s) => s >= 80 ? PbiColors.emerald : s >= 50 ? PbiColors.amber : PbiColors.rose;

  @override
  Widget build(BuildContext context) {
    final dr = _driver;
    final decls = _driverDeclarations;
    final monthly = _monthlyData(decls);
    final gravity = _gravityData(decls);
    final pdrTypePanne = _pdrTypePanne(decls);
    final anomaliesVehicule = _anomaliesVehicule(decls);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSidebar(),
        const SizedBox(height: 12),
        if (dr == null)
          const PbiEmptyState(icon: 'truck', title: 'Sélectionnez un chauffeur', message: 'Cliquez sur un nom pour voir sa fiche de performance')
        else ...[
          _buildCarte(dr),
          const SizedBox(height: 12),
          _buildKpiRow(dr),
          const SizedBox(height: 12),
          _buildProgress(dr),
          const SizedBox(height: 12),
          _buildClassement(),
          if (decls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildEvolutionRow(monthly, gravity),
            const SizedBox(height: 12),
            _buildPdrRow(pdrTypePanne, anomaliesVehicule),
          ],
        ],
      ],
    );
  }

  List<Map<String, dynamic>> _monthlyData(List<DeclarationRow> decls) {
    final groups = <String, double>{};
    for (final d in decls) {
      final month = d.date.isNotEmpty ? (d.date.length >= 7 ? d.date.substring(0, 7) : d.date) : 'inconnu';
      groups[month] = (groups[month] ?? 0) + 1;
    }
    final keys = groups.keys.toList()..sort();
    return keys.map((k) => {'mois': k, 'déclarations': groups[k]!}).toList();
  }

  List<MapEntry<String, num>> _gravityData(List<DeclarationRow> decls) {
    final groups = <String, double>{};
    for (final d in decls) {
      final key = d.criticite.isNotEmpty ? d.criticite : 'INCONNU';
      groups[key] = (groups[key] ?? 0) + 1;
    }
    return groups.entries.map((e) => MapEntry(e.key, e.value)).toList();
  }

  List<MapEntry<String, num>> _pdrTypePanne(List<DeclarationRow> decls) {
    final groups = <String, double>{};
    for (final d in decls) {
      if (d.typePanne.isNotEmpty && d.cout > 0) {
        groups[d.typePanne] = (groups[d.typePanne] ?? 0) + d.cout;
      }
    }
    final list = groups.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.take(8).toList();
  }

  List<MapEntry<String, num>> _anomaliesVehicule(List<DeclarationRow> decls) {
    final groups = <String, double>{};
    for (final d in decls) {
      if (d.vehicule.isNotEmpty) {
        groups[d.vehicule] = (groups[d.vehicule] ?? 0) + 1;
      }
    }
    final list = groups.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.take(8).toList();
  }

  Widget _buildSidebar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE61E293B), Color(0xE61A2436)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              pbiIcon('Users', size: 14, color: PbiColors.blue),
              const SizedBox(width: 6),
              Text(
                'Chauffeurs (${widget.data.drivers.length})',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE5E7EB), letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(fontSize: 11, color: Color(0xFFE5E7EB)),
            decoration: InputDecoration(
              hintText: 'Nom du chauffeur...',
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
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final d in _filtered.take(30))
                  InkWell(
                    onTap: () => setState(() => _selectedDriver = d.nom),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: _selectedDriver == d.nom ? const Color(0x263B82F6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedDriver == d.nom ? const Color(0x333B82F6) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: _selectedDriver == d.nom
                                  ? const Color(0x333B82F6)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: pbiIcon('User', size: 14, color: _scoreColor(d.score))),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.nom,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE5E7EB)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${d.anomalies} anomalies · ${d.checkups} check-ups',
                                  style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF)),
                                ),
                              ],
                            ),
                          ),
                          PbiStatusBadge(label: '${d.score}', color: _scoreColor(d.score)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarte(DriverRow dr) {
    final badge = dr.score >= 80
        ? ('Excellent', PbiColors.emerald)
        : dr.score >= 50
            ? ('Moyen', PbiColors.amber)
            : ('Critique', PbiColors.rose);
    final info = <(String, String, String)>[
      ('Award', dr.matricule.isNotEmpty ? dr.matricule : '—', dr.matricule),
      ('Mail', dr.email.isNotEmpty ? dr.email : '—', dr.email),
      ('Phone', dr.phone.isNotEmpty ? dr.phone : '—', dr.phone),
      ('MapPin', dr.branchCode.isNotEmpty ? dr.branchCode : '—', dr.branchCode),
      ('Calendar', 'Date embauche: —', 'embauche'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE61E293B), Color(0xE61A2436)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [PbiColors.violet, Color(0xFF9333EA)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Color(0x338B5CF6), blurRadius: 20)],
            ),
            child: Center(child: pbiIcon('User', size: 30, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dr.nom,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PbiStatusBadge(label: badge.$1, color: badge.$2, border: true),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final i in info)
                      InkWell(
                        onTap: null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0x800F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              pbiIcon(i.$1, size: 11, color: const Color(0xFF9CA3AF)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  i.$2,
                                  style: const TextStyle(fontSize: 9, color: Color(0xFFD1D5DB)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              Text('${dr.score}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _scoreColor(dr.score))),
              const Text(
                'Score Global',
                style: TextStyle(fontSize: 8, color: Color(0xFF9CA3AF), letterSpacing: 0.6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow(DriverRow dr) {
    final kpis = <({String label, String value, String icon, Color color})>[
      (label: 'Score', value: '${dr.score}', icon: 'Star', color: _scoreColor(dr.score)),
      (label: 'Check-ups', value: '${dr.checkupsOK}/${dr.checkups}', icon: 'CheckCircle', color: PbiColors.emerald),
      (label: 'Anomalies', value: '${dr.anomalies}', icon: 'AlertTriangle', color: PbiColors.rose),
      (label: 'Conformité', value: '${dr.tauxConformite}%', icon: 'Trophy', color: PbiColors.blue),
      (label: 'Résolution', value: '${dr.tauxResolution}%', icon: 'TrendingUp', color: PbiColors.violet),
    ];
    return PbiKpiGrid(
      gap: 8,
      children: [
        for (final k in kpis)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xE61E293B), Color(0xE61A2436)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x0DFFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    pbiIcon(k.icon, size: 13, color: k.color),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(k.label, style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(k.value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProgress(DriverRow dr) {
    final bars = <(String, int)>[
      ('Taux de conformité', dr.tauxConformite),
      ('Taux de résolution', dr.tauxResolution),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE61E293B), Color(0xE61A2436)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Row(
        children: [
          for (final b in bars) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.$1,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${b.$2}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _scoreColor(b.$2))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  PbiProgressBar(value: b.$2.clamp(0, 100).toDouble(), color: _scoreColor(b.$2), height: 10),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildClassement() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE61E293B), Color(0xE61A2436)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pbiSectionTitle('Trophy', 'Classement des chauffeurs', PbiColors.amber),
          PbiTable(
            headers: const [
              ('#', PbiAlign.left),
              ('Nom', PbiAlign.left),
              ('Score', PbiAlign.center),
              ('Anomalies', PbiAlign.center),
              ('Check-ups', PbiAlign.center),
              ('Conformité', PbiAlign.center),
              ('Résolution', PbiAlign.center),
            ],
            maxHeight: 256,
            rowHeight: 36,
            rows: [
              for (final (i, d) in _sortedDrivers.indexed)
                [
                  Text(
                    i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF9CA3AF)),
                  ),
                  Text(
                    d.nom,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: d.nom == _selectedDriver ? const Color(0xFF93C5FD) : const Color(0xFFE5E7EB),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  PbiStatusBadge(label: '${d.score}', color: _scoreColor(d.score)),
                  Text('${d.anomalies}', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                  Text('${d.checkupsOK}/${d.checkups}', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                  Text('${d.tauxConformite}%', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                  Text('${d.tauxResolution}%', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEvolutionRow(List<Map<String, dynamic>> monthly, List<MapEntry<String, num>> gravity) {
    return PbiStackRow(
      children: [
        PbiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                pbiSectionTitle('Activity', 'Évolution mensuelle', PbiColors.blue),
                SizedBox(
                  height: 190,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: Color(0x0DFFFFFF), strokeWidth: 1, dashArray: [3, 3]),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (v, meta) => Text(
                              v.toInt().toString(),
                              style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 18,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= monthly.length) return const SizedBox.shrink();
                              final mois = monthly[i]['mois'] as String? ?? '';
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  mois.length >= 7 ? mois.substring(2) : mois,
                                  style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: const Color(0xF21E293B),
                          getTooltipItems: (spots) => [
                            for (final s in spots)
                              LineTooltipItem(
                                'déclarations: ${s.y.round()}',
                                const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE5E7EB)),
                              ),
                          ],
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (int i = 0; i < monthly.length; i++)
                              FlSpot(i.toDouble(), (monthly[i]['déclarations'] as num?)?.toDouble() ?? 0),
                          ],
                          color: PbiColors.blue,
                          barWidth: 2,
                          isCurved: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                              radius: 3,
                              color: PbiColors.blue,
                              strokeWidth: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        PbiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              pbiSectionTitle('BarChart3', 'Répartition par gravité', PbiColors.amber),
              if (gravity.isEmpty)
                const PbiEmptyState(icon: 'anomaly', message: 'Aucune donnée')
              else
                SizedBox(
                  height: 190,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 34,
                      sections: [
                        for (final (i, e) in gravity.indexed)
                          PieChartSectionData(
                            value: e.value.toDouble(),
                            color: chartColor(i),
                            radius: 50,
                            title: '${e.key} ${gravity.fold<double>(0, (s, x) => s + x.value.toDouble()) > 0 ? (e.value / gravity.fold<double>(0, (s, x) => s + x.value.toDouble()) * 100).round() : 0}%',
                            titleStyle: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                            showTitle: true,
                          ),
                      ],
                      pieTouchData: PieTouchData(enabled: false),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPdrRow(List<MapEntry<String, num>> pdrTypePanne, List<MapEntry<String, num>> anomaliesVehicule) {
    return PbiStackRow(
      children: [
        PbiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              pbiSectionTitle('Zap', 'PDR par type panne', const Color(0xFFA78BFA)),
                SizedBox(
                  height: 190,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: Color(0x0DFFFFFF), strokeWidth: 1, dashArray: [3, 3]),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 18,
                            getTitlesWidget: (v, meta) => Text(
                              v.toInt().toString(),
                              style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                            ),
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 80,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= pdrTypePanne.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  pdrTypePanne[i].key,
                                  style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: const Color(0xF21E293B),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                            '${rod.toY.round()} DH',
                            const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE5E7EB)),
                          ),
                        ),
                      ),
                      barGroups: [
                        for (int i = 0; i < pdrTypePanne.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: pdrTypePanne[i].value.toDouble(),
                                color: PbiColors.violet,
                                width: 12,
                                borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        PbiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              pbiSectionTitle('Activity', 'Anomalies par véhicule', PbiColors.emerald),
                SizedBox(
                  height: 190,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: Color(0x0DFFFFFF), strokeWidth: 1, dashArray: [3, 3]),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (v, meta) => Text(
                              v.toInt().toString(),
                              style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= anomaliesVehicule.length) return const SizedBox.shrink();
                              return Transform.rotate(
                                angle: -0.35,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    anomaliesVehicule[i].key,
                                    style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: const Color(0xF21E293B),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                            '${rod.toY.round()}',
                            const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE5E7EB)),
                          ),
                        ),
                      ),
                      barGroups: [
                        for (int i = 0; i < anomaliesVehicule.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: anomaliesVehicule[i].value.toDouble(),
                                color: PbiColors.emerald,
                                width: 12,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
