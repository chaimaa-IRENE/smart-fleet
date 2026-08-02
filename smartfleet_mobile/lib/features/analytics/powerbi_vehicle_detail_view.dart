import 'package:flutter/material.dart';
import 'powerbi_data.dart';
import 'powerbi_theme.dart';
import 'powerbi_widgets.dart';

class VehicleDetailView extends StatefulWidget {
  final DashboardData data;
  const VehicleDetailView({super.key, required this.data});

  @override
  State<VehicleDetailView> createState() => _VehicleDetailViewState();
}

class _VehicleDetailViewState extends State<VehicleDetailView> {
  String _search = '';
  String? _selectedVeh;
  bool _aiAnalysing = false;
  String? _aiResult;
  double? _aiScore;

  List<VehicleRow> get _filtered {
    final q = _search.trim().toLowerCase();
    final list = widget.data.vehicles.where((v) {
      if (q.isEmpty) return true;
      return (v.immatriculation.toLowerCase().contains(q)) ||
          (v.marque.toLowerCase().contains(q)) ||
          (v.chauffeurNom.toLowerCase().contains(q));
    }).toList();
    const order = {'IMMOBILISE': 0, 'BLOQUE': 1, 'MAINTENANCE': 2, 'ACTIF': 3};
    list.sort((a, b) {
      final oa = order[a.statut] ?? 99;
      final ob = order[b.statut] ?? 99;
      return oa.compareTo(ob);
    });
    return list;
  }

  VehicleRow? get _vehicle {
    if (_selectedVeh == null) return null;
    for (final v in widget.data.vehicles) {
      if (v.immatriculation == _selectedVeh) return v;
    }
    return null;
  }

  List<DeclarationRow> get _vehicleDeclarations {
    final v = _vehicle;
    if (v == null) return [];
    return widget.data.declarations.where((d) => d.vehicule == v.immatriculation).toList();
  }

  List<DocumentRow> get _vehicleDocs {
    final v = _vehicle;
    if (v == null) return [];
    return widget.data.documents.where((d) => d.vehicule == v.immatriculation).toList();
  }

  Color _statutColor(String s) => s == 'ACTIF'
      ? PbiColors.emerald
      : s == 'MAINTENANCE'
          ? PbiColors.amber
          : PbiColors.rose;

  Color _scoreColor(double v) => v >= 80 ? PbiColors.emerald : v >= 50 ? PbiColors.amber : PbiColors.rose;

  List<({String label, String value, String icon, Color color})> get _vehicleKpis {
    final v = _vehicle;
    if (v == null) return [];
    final estHeures = v.kilometrage > 0 ? (v.kilometrage / 60).round() : null;
    final estConsoVeh = v.carburant == 'Diesel' ? 9.5 : v.carburant == 'Essence' ? 11.2 : null;
    final decls = _vehicleDeclarations;
    final resolvedCount = decls.where((d) => d.statut == 'CLOTURE' || d.statut == 'RESOLU').length;
    final perfScore = v.anomalies > 0 ? ((resolvedCount / v.anomalies) * 100).round() : v.scoreIVMS;
    return [
      (label: 'IVMS', value: '${v.scoreIVMS.round()}%', icon: 'Shield', color: _scoreColor(v.scoreIVMS)),
      (label: 'Kilométrage', value: v.kilometrage > 0 ? '${formatNumber(v.kilometrage)} km' : '—', icon: 'Gauge', color: PbiColors.blue),
      (label: 'Heures moteur', value: estHeures != null ? '$estHeures' : '—', icon: 'Clock', color: PbiColors.blue),
      (label: 'Déclarations', value: '${v.anomalies}', icon: 'Activity', color: PbiColors.cyan),
      (label: 'Résolues', value: '$resolvedCount/${v.anomalies}', icon: 'Activity', color: PbiColors.emerald),
      (label: 'Consommation', value: estConsoVeh != null ? '${estConsoVeh.toStringAsFixed(1)} L/100km' : '—', icon: 'Fuel', color: PbiColors.emerald),
      (label: 'Performance', value: '${perfScore}%', icon: 'Activity', color: _scoreColor(perfScore.toDouble())),
    ];
  }

  List<Map<String, dynamic>> get _monthlyData {
    final groups = <String, Map<String, dynamic>>{};
    for (final d in _vehicleDeclarations) {
      if (d.date.isEmpty) continue;
      final month = d.date.length >= 7 ? d.date.substring(0, 7) : d.date;
      final g = groups.putIfAbsent(month, () => {'mois': month, 'anomalies': 0, 'resolues': 0});
      g['anomalies'] = (g['anomalies'] as int) + 1;
      if (d.statut == 'CLOTURE' || d.statut == 'RESOLU') {
        g['resolues'] = (g['resolues'] as int) + 1;
      }
    }
    final keys = groups.keys.toList()..sort();
    return keys.map((k) => groups[k]!).toList();
  }

  List<DeclarationRow> get _lastAnomalies {
    final list = _vehicleDeclarations.where((d) => d.date.isNotEmpty).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list.take(10).toList();
  }

  double get _predictiveScore {
    final v = _vehicle;
    if (v == null) return 0;
    final total = _vehicleDeclarations.length;
    final resolved = _vehicleDeclarations.where((d) => d.statut == 'CLOTURE' || d.statut == 'RESOLU').length;
    final historyScore = total > 0 ? (resolved / total) * 100 : 100.0;
    final docScore = v.documents > 0 ? (v.documentsValides / v.documents) * 100 : 0.0;
    return (historyScore * 0.4 + docScore * 0.25 + (v.scoreIVMS) * 0.2 + (v.scoreIVMS) * 0.15).round().toDouble();
  }

  List<({String label, double value, String weight, Color color})> get _componentScores {
    final v = _vehicle;
    if (v == null) return [];
    final total = _vehicleDeclarations.length;
    final resolved = _vehicleDeclarations.where((d) => d.statut == 'CLOTURE' || d.statut == 'RESOLU').length;
    return [
      (label: 'Historique', value: (total > 0 ? (resolved / total) * 100 : 100).round().toDouble(), weight: '40%', color: PbiColors.blue),
      (label: 'Documents', value: (v.documents > 0 ? (v.documentsValides / v.documents) * 100 : 0).round().toDouble(), weight: '25%', color: PbiColors.amber),
      (label: 'Check-ups', value: v.scoreIVMS, weight: '20%', color: PbiColors.cyan),
      (label: 'Conducteur', value: (v.scoreIVMS * 0.8 + 20).round().toDouble(), weight: '15%', color: PbiColors.violet),
    ];
  }

  void _handleAiAnalyze() {
    if (_vehicle == null) return;
    setState(() {
      _aiAnalysing = true;
      _aiResult = null;
      _aiScore = null;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _aiScore = _predictiveScore;
        _aiResult = '⚠️ Analyse IA momentanément indisponible. Score calculé localement.';
        _aiAnalysing = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = _vehicle;
    final widgets = <Widget>[
      _buildSidebar(),
      const SizedBox(height: 12),
      if (v == null)
        const PbiEmptyState(icon: 'truck', title: 'Sélectionnez un véhicule', message: 'Cliquez sur un camion pour voir sa fiche détaillée')
      else ...[
        _buildFiche(v),
        const SizedBox(height: 12),
        _buildKpiRow(),
        const SizedBox(height: 12),
        _buildScores(),
        const SizedBox(height: 12),
        _buildSantePredictive(),
        const SizedBox(height: 12),
        _buildEvolutionRow(),
        if (_vehicleDocs.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildDocumentation(),
        ],
      ],
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widgets);
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
              pbiIcon('Truck', size: 14, color: PbiColors.blue),
              const SizedBox(width: 6),
              Text(
                'Parc (${widget.data.vehicles.length})',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE5E7EB), letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (val) => setState(() => _search = val),
            style: const TextStyle(fontSize: 11, color: Color(0xFFE5E7EB)),
            decoration: InputDecoration(
              hintText: 'Immatriculation, marque...',
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
                for (final veh in _filtered)
                  InkWell(
                    onTap: () => setState(() => _selectedVeh = veh.immatriculation),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: _selectedVeh == veh.immatriculation ? const Color(0x263B82F6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedVeh == veh.immatriculation ? const Color(0x333B82F6) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: _selectedVeh == veh.immatriculation
                                  ? const Color(0x333B82F6)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: pbiIcon('Truck', size: 14, color: _statutColor(veh.statut))),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  veh.immatriculation,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFE5E7EB),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(
                                  '${veh.marque} ${veh.modele} · ${veh.chauffeurNom.isNotEmpty ? veh.chauffeurNom : '—'}',
                                  style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (veh.documents > 0 && veh.documentsValides < veh.documents)
                            pbiIcon('AlertTriangle', size: 12, color: PbiColors.amber),
                          const SizedBox(width: 6),
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: _statutColor(veh.statut), shape: BoxShape.circle)),
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

  Widget _fieldBox(String label, String value, {bool badge = false, String badgeValue = ''}) {
    final badgeColor = badge
        ? (badgeValue == 'ACTIF'
            ? PbiColors.emerald
            : badgeValue == 'MAINTENANCE'
                ? PbiColors.amber
                : PbiColors.rose)
        : PbiColors.rose;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x800F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF), letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          if (badge)
            PbiStatusBadge(label: badgeValue, color: badgeColor)
          else
            Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE5E7EB)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildFiche(VehicleRow v) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [PbiColors.blue, PbiColors.indigo],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: pbiIcon('Truck', size: 28, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            v.immatriculation.isNotEmpty ? v.immatriculation : 'Véhicule #${v.id}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PbiStatusBadge(
                          label: v.statut,
                          color: v.statut == 'ACTIF'
                              ? PbiColors.emerald
                              : v.statut == 'MAINTENANCE'
                                  ? PbiColors.amber
                                  : PbiColors.rose,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${v.marque} ${v.modele} · ${v.type} · ${v.annee.round()}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(width: 150, child: _fieldBox('N° Châssis (VIN)', v.numeroOrdre.isNotEmpty ? v.numeroOrdre : '—')),
              SizedBox(width: 150, child: _fieldBox('Immatriculation', v.immatriculation)),
              SizedBox(width: 150, child: _fieldBox('Marque', v.marque)),
              SizedBox(width: 150, child: _fieldBox('Modèle', v.modele)),
              SizedBox(width: 150, child: _fieldBox('Type / Catégorie', v.type)),
              SizedBox(width: 150, child: _fieldBox('Agence', v.agence)),
              SizedBox(width: 150, child: _fieldBox('Ville', v.agence.isNotEmpty ? v.agence : (v.type.isNotEmpty ? v.type : '—'))),
              SizedBox(width: 150, child: _fieldBox('Carburant', v.carburant.isNotEmpty ? v.carburant : '—')),
              SizedBox(width: 150, child: _fieldBox('Kilométrage', v.kilometrage > 0 ? '${formatNumber(v.kilometrage)} km' : '—')),
              SizedBox(width: 150, child: _fieldBox('Anomalies', '${v.anomalies} déclarations')),
              SizedBox(width: 150, child: _fieldBox('Statut', '', badge: true, badgeValue: v.statut)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w < 480 ? 3 : w < 900 ? 5 : 7;
        final cardW = (w - 8.0 * (cols - 1)) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in _vehicleKpis)
              SizedBox(
                width: cardW,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: k.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Center(child: pbiIcon(k.icon, size: 15, color: k.color)),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(k.value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      Text(k.label,
                          style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildScores() {
    final v = _vehicle!;
    final bars = <({String label, double value})>[
      (
        label: 'Sécurité',
        value: v.scoreIVMS >= 60
            ? (v.scoreIVMS + 10).clamp(0, 100)
            : (v.scoreIVMS - 10).clamp(0, 100),
      ),
      (label: 'Qualité', value: v.scoreIVMS),
      (label: 'Documentaire', value: v.documents > 0 ? ((v.documentsValides / v.documents) * 100).round().toDouble() : 0),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pbiSectionTitle('Activity', 'Scores', PbiColors.blue),
          Column(
            children: [
              for (final b in bars) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x800F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x0DFFFFFF)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(b.label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                          const Spacer(),
                          Text(
                            '${b.value.round()}%',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _scoreColor(b.value)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      PbiProgressBar(value: b.value.clamp(0, 100), color: _scoreColor(b.value), height: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSantePredictive() {
    final score = _predictiveScore;
    final riskLabel = score >= 80
        ? 'Risque Faible'
        : score >= 60
            ? 'Risque Moyen'
            : score >= 40
                ? 'Risque Élevé'
                : 'Risque Critique';
    final riskColor = score >= 80
        ? PbiColors.emerald
        : score >= 60
            ? PbiColors.amber
            : score >= 40
                ? const Color(0xFFF97316)
                : PbiColors.rose;
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  pbiIcon('BrainCircuit', size: 14, color: PbiColors.violet),
                  const SizedBox(width: 6),
                  const Text(
                    'Santé Prédictive',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE5E7EB), letterSpacing: 0.6),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PbiStatusBadge(label: riskLabel, color: riskColor),
                  InkWell(
                    onTap: _aiAnalysing ? null : _handleAiAnalyze,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: PbiColors.violet.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PbiColors.violet.withValues(alpha: 0.20)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          pbiIcon('Sparkles', size: 11, color: PbiColors.violet),
                          const SizedBox(width: 4),
                          Text(
                            _aiAnalysing ? 'Analyse...' : 'Analyser IA',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: PbiColors.violet.withValues(alpha: _aiAnalysing ? 0.5 : 1),
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
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PbiGauge(value: _aiScore ?? score, label: 'Score Santé', size: 100),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    for (final cs in _componentScores)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0x800F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0x0DFFFFFF)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(cs.label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                                  const Spacer(),
                                  Text('${cs.value.round()}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.color)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              PbiProgressBar(value: cs.value, color: cs.color, height: 6),
                              const SizedBox(height: 2),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Poids: ${cs.weight}', style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF))),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_aiResult != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PbiColors.violet.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PbiColors.violet.withValues(alpha: 0.10)),
              ),
              child: Text(_aiResult!, style: const TextStyle(fontSize: 11, color: Color(0xFFD1D5DB))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvolutionRow() {
    final monthly = _monthlyData;
    final last = _lastAnomalies;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
              pbiSectionTitle('Activity', 'Évolution anomalies vs réparations', PbiColors.blue),
              if (monthly.isEmpty)
                const PbiEmptyState(icon: 'anomaly', message: 'Aucune donnée disponible')
              else
                PbiComposedChart(
                  data: monthly,
                  bars: [(key: 'anomalies', name: 'Anomalies', color: PbiColors.rose, width: null, barRadius: 3, barWidth: 12)],
                  lines: [(key: 'resolues', name: 'Réparations', color: PbiColors.emerald, width: 2)],
                  height: 190,
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
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
              pbiSectionTitle('AlertTriangle', 'Dernières anomalies', PbiColors.rose),
              if (last.isEmpty)
                const PbiEmptyState(icon: 'anomaly', message: 'Aucune anomalie')
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 190),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final d in last)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: const Color(0x800F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0x0DFFFFFF)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusColor(d.criticite),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                d.date.contains('T') ? d.date.split('T').first : d.date,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  d.typePanne.isNotEmpty ? d.typePanne : d.element,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFFD1D5DB)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              PbiStatusBadge(
                                label: d.criticite,
                                color: d.criticite == 'CRITIQUE'
                                    ? PbiColors.rose
                                    : d.criticite == 'MAJEURE'
                                        ? PbiColors.amber
                                        : PbiColors.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                d.statut,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: (d.statut == 'CLOTURE' || d.statut == 'RESOLU')
                                      ? PbiColors.emerald
                                      : PbiColors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentation() {
    final docs = _vehicleDocs;
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
          pbiSectionTitle('FileText', 'Documents (${docs.length})', PbiColors.blue),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cols = w < 480 ? 1 : 2;
              final cardW = (w - 8.0 * (cols - 1)) / cols;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in docs)
                    SizedBox(
                      width: cardW,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0x800F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x0DFFFFFF)),
                        ),
                        child: _docCard(d),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _docCard(DocumentRow d) {
    final jrs = d.joursRestants;
    final sc = jrs < 0
        ? PbiColors.rose
        : jrs <= 30
            ? PbiColors.amber
            : PbiColors.emerald;
    final progress = (jrs / 365 * 100).clamp(0.0, 100.0);
    final statusText = jrs < 0 ? 'Expiré (${jrs.abs()}j)' : jrs <= 30 ? '$jrs j restants' : 'Valide';
    final date = d.dateExpiration.contains('T') ? d.dateExpiration.split('T').first : d.dateExpiration;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(d.type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE5E7EB)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            PbiStatusBadge(label: statusText, color: sc),
          ],
        ),
        const SizedBox(height: 6),
        PbiProgressBar(value: progress, color: sc, height: 6),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(date.isNotEmpty ? date : '—', style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
            const Spacer(),
            Text(
              jrs > 0 ? '$jrs j' : 'Expiré',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: sc),
            ),
          ],
        ),
      ],
    );
  }
}
