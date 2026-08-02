import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/anomalie_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/alert_service.dart';
import '../../services/export_service.dart';
import '../../database/dao/budget_dao.dart';
import '../../database/dao/document_dao.dart';
import '../../widgets/danone_app_bar.dart';
import 'rs_anomalies.dart';
import 'rs_declarations.dart';
import 'rs_documents.dart';
import '../analytics/powerbi_view.dart';
import 'package:fl_chart/fl_chart.dart';

const _anomalieStatutLabels = {
  'DETECTEE': 'Détectée',
  'EN_REPARATION': 'En réparation',
  'REPAREE': 'Réparée',
  'NON_REPAREE': 'Non réparable',
  'VALIDEE': 'Validée',
  'ANNULEE': 'Annulée',
};
const _anomalieStatutColors = {
  'DETECTEE': AppTheme.danger,
  'EN_REPARATION': AppTheme.warning,
  'REPAREE': Colors.blue,
  'NON_REPAREE': Colors.orange,
  'VALIDEE': AppTheme.success,
  'ANNULEE': Colors.grey,
};

String _fmtDate(dynamic d) {
  if (d == null) return '-';
  if (d is String) {
    if (d.length >= 16) return d.substring(0, 16).replaceAll('T', ' ');
    if (d.length >= 10) return d.substring(0, 10);
    return d;
  }
  return '$d';
}

String _toDateStr(dynamic d) {
  if (d == null) return '';
  if (d is String) return d.length >= 10 ? d.substring(0, 10) : d;
  return '$d';
}

IconData _docTypeIcon(String type) {
  switch (type) {
    case 'ASSURANCE': return Icons.shield;
    case 'ONSSA': return Icons.verified_user;
    case 'VISITE_TECHNIQUE': return Icons.car_repair;
    case 'CARTE_GRISE': return Icons.assignment;
    case 'METROLOGIQUE': return Icons.calendar_today;
    default: return Icons.description;
  }
}

class _PieData {
  final String label;
  final int value;
  final Color color;
  _PieData(this.label, this.value, this.color);
}

class RsDashboard extends StatefulWidget {
  const RsDashboard({super.key});

  @override
  State<RsDashboard> createState() => _RsDashboardState();
}

class _RsDashboardState extends State<RsDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Timer? _autoRefreshTimer;

  Map<String, dynamic> _anomalieStats = {};
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _anomalies = [];
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _declarations = [];
  List<Map<String, dynamic>> _checklists = [];
  Map<String, dynamic>? _vehicleHistory;
  int? _historyVehicleId;
  int _alertCount = 0;

  // Budget
  Map<String, dynamic>? _currentBudget;
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _budgetByProvider = [];

  // Declarations tab state
  bool _showCreateBudgetModal = false;
  Map<String, dynamic> _newBudgetForm = {'annee': DateTime.now().year, 'trimestre': 1, 'budgetTotal': ''};
  final TextEditingController _anneeCtrl = TextEditingController(text: '${DateTime.now().year}');

  Map<String, int> get _declStats {
    final decls = _declarations;
    return {
      'total': decls.length,
      'enAttente': decls.where((d) => d['statut'] == 'EN_ATTENTE').length,
      'enCours': decls.where((d) => d['statut'] == 'EN_COURS').length,
      'enValidation': decls.where((d) => d['statut'] == 'EN_VALIDATION').length,
      'cloturees': decls.where((d) => d['statut'] == 'CLOTURE').length,
      'retournees': decls.where((d) => d['statut'] == 'RETOURNEE').length,
    };
  }

  int _budgetVal(String key) {
    final direct = _currentBudget?[key];
    if (direct is num) return direct.toInt();
    if (key == 'budgetTotal' || key == 'montantTotal') {
      return ((_currentBudget?['budgetTotal'] ?? _currentBudget?['montantTotal']) as num?)?.toInt() ?? 0;
    }
    if (key == 'budgetUtilise' || key == 'montantUtilise') {
      return ((_currentBudget?['budgetUtilise'] ?? _currentBudget?['montantUtilise']) as num?)?.toInt() ?? 0;
    }
    if (key == 'budgetRestant') {
      return _budgetVal('budgetTotal') - _budgetVal('montantUtilise');
    }
    return (_currentBudget?[key] as num?)?.toInt() ?? 0;
  }
  int _budgetRestant() => _budgetVal('budgetTotal') - _budgetVal('montantUtilise');
  double _budgetProgress() => _budgetVal('budgetTotal') > 0 ? _budgetVal('montantUtilise') / _budgetVal('budgetTotal') : 0.0;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
    _loadAll();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadAll());
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabCtrl.dispose();
    _anneeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final docDao = DocumentVehiculeDao();
      final results = await Future.wait([
        AnomalieService().getStats(),
        VehicleService().getAll(),
        AnomalieService().getAll(),
        docDao.getAll(),
        FleetAlertService().getActive(),
        BudgetDao().getCurrent(),
        BudgetDao().getAll(),
        _fetchDeclarations(),
        _fetchChecklists(),
      ]);
      if (mounted) {
        final current = results[5] as Map<String, dynamic>?;
        List<Map<String, dynamic>> budgetByProvider = [];
        if (current != null) {
          budgetByProvider = await BudgetDao().getByProvider(current['id'] as int);
        }
        setState(() {
          _anomalieStats = results[0] as Map<String, dynamic>;
          _vehicles = results[1] as List<Map<String, dynamic>>;
          _anomalies = results[2] as List<Map<String, dynamic>>;
          _documents = results[3] as List<Map<String, dynamic>>;
          _alertCount = (results[4] as List).length;
          _currentBudget = current;
          _budgets = results[6] as List<Map<String, dynamic>>;
          _budgetByProvider = budgetByProvider;
          _declarations = results[7] as List<Map<String, dynamic>>;
          _checklists = results[8] as List<Map<String, dynamic>>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDeclarations() async {
    try {
      final client = http.Client();
      final url = Uri.parse('${ApiConfig.baseUrl}/declarations');
      final res = await client.get(url).timeout(ApiConfig.timeout);
      client.close();
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return (decoded is List ? decoded : []).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) { return []; }
  }

  Future<List<Map<String, dynamic>>> _fetchChecklists() async {
    try {
      final client = http.Client();
      final url = Uri.parse('${ApiConfig.baseUrl}/checklists');
      final res = await client.get(url).timeout(ApiConfig.timeout);
      client.close();
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return (decoded is List ? decoded : []).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) { return []; }
  }

  List<Map<String, dynamic>> get _blockedVehicles =>
      _vehicles.where((v) => v['statut'] == 'BLOQUE').toList();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final detectees = _anomalieStats['detectees'] as int? ?? 0;
    final enReparation = _anomalieStats['enReparation'] as int? ?? 0;
    final reparees = _anomalieStats['reparees'] as int? ?? 0;
    final validees = _anomalieStats['validees'] as int? ?? 0;
    final nonReparables = _anomalieStats['nonReparees'] as int? ?? 0;
    final tauxReparation = _anomalieStats['tauxReparation'] as String? ?? '0%';
    final blockedCount = _blockedVehicles.length;

    return Scaffold(
      appBar: DanoneAppBar(
        title: user?['nom'] as String? ?? 'Responsable Support',
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll, tooltip: 'Actualiser'),
          IconButton(icon: const Icon(Icons.file_download), onPressed: _showExportOptions, tooltip: 'Exporter'),
          if (_alertCount > 0)
            Stack(children: [
              IconButton(icon: const Icon(Icons.notifications_active), onPressed: () => context.go('/rs/alerts')),
              Positioned(right: 6, top: 6, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle), child: Text('$_alertCount', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)))),
            ]),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.go('/rs/settings')),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (context.mounted) context.go('/login');
          }),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _badge('Anomalies = SANS budget', Colors.orange),
                const SizedBox(width: 8),
                _badge('Déclarations = AVEC budget', Colors.blue),
              ]),
            ),
            TabBar(
              controller: _tabCtrl,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.bug_report), text: 'Anomalies'),
                Tab(icon: Icon(Icons.assignment), text: 'Déclarations'),
                Tab(icon: Icon(Icons.checklist), text: 'Checklists'),
                Tab(icon: Icon(Icons.description), text: 'Documents'),
                Tab(icon: Icon(Icons.analytics), text: 'Power BI'),
                Tab(icon: Icon(Icons.history), text: 'Historique'),
              ],
            ),
          ]),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildAnomaliesTab(detectees, enReparation, reparees, validees, nonReparables, tauxReparation, blockedCount),
                _buildDeclarationsTab(),
                _buildChecklistsTab(),
                _buildDocumentsTab(),
                _buildPowerBiTab(),
                _buildVehicleHistoryTab(),
              ],
            ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }

  // ─── ANOMALIES TAB ───
  Widget _buildAnomaliesTab(int detectees, int enReparation, int reparees, int validees, int nonReparables, String tauxReparation, int blocked) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Flexible(child: _miniKpi('Détectées', '$detectees', Icons.bug_report, AppTheme.danger)),
            const SizedBox(width: 6),
            Flexible(child: _miniKpi('En réparation', '$enReparation', Icons.build, AppTheme.warning)),
            const SizedBox(width: 6),
            Flexible(child: _miniKpi('Réparées', '$reparees', Icons.check_circle, Colors.blue)),
            const SizedBox(width: 6),
            Flexible(child: _miniKpi('Validées', '$validees', Icons.verified, AppTheme.success)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Flexible(child: _miniKpi('Non répar.', '$nonReparables', Icons.cancel, Colors.grey)),
            const SizedBox(width: 6),
            Flexible(child: _miniKpi('Bloqués', '$blocked', Icons.block, AppTheme.danger)),
            const SizedBox(width: 6),
            Flexible(child: _miniKpi('Taux réparation', tauxReparation, Icons.percent, Colors.purple)),
          ]),
        ]),
      ),
      const Expanded(child: RsAnomalies()),
    ]);
  }

  // ─── DECLARATIONS TAB ───
  Widget _buildDeclarationsTab() {
    final stats = _declStats;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        _buildBudgetSection(),
        const SizedBox(height: 12),
        _buildDeclPieChart(),
        const SizedBox(height: 12),
        _buildDeclStats(stats),
        const SizedBox(height: 12),
        const RsDeclarations(showAppBar: false),
        if (_showCreateBudgetModal) _buildCreateBudgetModal(),
      ]),
    );
  }

  Widget _buildBudgetSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(child: Row(children: [
            Icon(Icons.account_balance, size: 18, color: Colors.green[600]),
            const SizedBox(width: 8),
            Flexible(child: Text('Budget Trimestriel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ])),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('+ Nouveau Budget', style: TextStyle(fontSize: 11)),
            onPressed: () => setState(() {
              _newBudgetForm = {'annee': DateTime.now().year, 'trimestre': 1, 'budgetTotal': ''};
              _anneeCtrl.text = '${DateTime.now().year}';
              _showCreateBudgetModal = true;
            }),
          ),
        ]),
        if (_currentBudget != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(
                  'T${_currentBudget!['trimestre']} ${_currentBudget!['annee']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _StatusBadge(status: _currentBudget!['statut'] as String? ?? 'ACTIF'),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _BudgetLabelValue(
                  label: 'Budget Total',
                  value: '${_budgetVal('budgetTotal')} MAD',
                )),
                Expanded(child: _BudgetLabelValue(
                  label: 'Utilise',
                  value: '${_budgetVal('montantUtilise')} MAD',
                )),
                Expanded(child: _BudgetLabelValue(
                  label: 'Restant',
                  value: '${_budgetRestant()} MAD',
                )),
              ]),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _budgetProgress().clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade200,
                  color: _budgetProgress() > 0.8
                      ? AppTheme.danger
                      : _budgetProgress() > 0.6
                          ? AppTheme.warning
                          : AppTheme.success,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(_budgetProgress() * 100).toStringAsFixed(1)}% utilise',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ]),
          ),
        ] else ...[
          const SizedBox(height: 24),
          Center(child: Column(children: [
            Icon(Icons.account_balance, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text('Aucun budget trimestriel actif', style: TextStyle(fontSize: 13, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('Cliquez sur "+ Nouveau Budget"', style: TextStyle(fontSize: 11, color: Colors.grey[400]), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(height: 12),
        ],
      ]),
    );
  }

  Widget _buildDeclPieChart() {
    final stats = _declStats;
    final pieData = <_PieData>[
      _PieData('En attente', stats['enAttente']!, const Color(0xFFF59E0B)),
      _PieData('En cours', stats['enCours']!, const Color(0xFF3B82F6)),
      _PieData('En validation', stats['enValidation']!, const Color(0xFF8B5CF6)),
      _PieData('Cloturees', stats['cloturees']!, const Color(0xFF10B981)),
      _PieData('Retournees', stats['retournees']!, const Color(0xFFEF4444)),
    ].where((p) => p.value > 0).toList();
    if (pieData.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 4, children: [
            const Text('Repartition des declarations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Row(mainAxisSize: MainAxisSize.min, children: pieData.take(5).map((p) => Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: p.color, shape: BoxShape.circle)),
              const SizedBox(width: 2),
              FittedBox(child: Text(p.label.substring(0, 4), style: TextStyle(fontSize: 8, color: Colors.grey[600]))),
              const SizedBox(width: 6),
            ])).toList()),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: pieData.map((p) => PieChartSectionData(
              value: p.value.toDouble(),
              title: '${p.value}',
              color: p.color,
              radius: 60,
              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            )).toList(),
          )),
        ),
      ]),
    );
  }

  Widget _buildDeclStats(Map<String, int> stats) {
    final items = [
      {'label': 'Total', 'value': stats['total'], 'color': const Color(0xFFF1F5F9), 'textColor': const Color(0xFF1E293B), 'filter': ''},
      {'label': 'En attente', 'value': stats['enAttente'], 'color': const Color(0xFFFFFBEB), 'textColor': const Color(0xFFF59E0B), 'filter': 'EN_ATTENTE'},
      {'label': 'En cours', 'value': stats['enCours'], 'color': const Color(0xFFEFF6FF), 'textColor': const Color(0xFF3B82F6), 'filter': 'EN_COURS'},
      {'label': 'En validation', 'value': stats['enValidation'], 'color': const Color(0xFFF5F3FF), 'textColor': const Color(0xFF8B5CF6), 'filter': 'EN_VALIDATION'},
      {'label': 'Cloturees', 'value': stats['cloturees'], 'color': const Color(0xFFF0FDF4), 'textColor': const Color(0xFF10B981), 'filter': 'CLOTURE'},
      {'label': 'Retournees', 'value': stats['retournees'], 'color': const Color(0xFFFEF2F2), 'textColor': const Color(0xFFEF4444), 'filter': 'RETOURNEE'},
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: items.map((s) {
      final w = MediaQuery.of(context).size.width;
      final cardW = w < 360 ? (w - 56) / 2 : (w - 48) / 3;
      return Container(
        width: cardW,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: s['color'] as Color, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${s['value']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: s['textColor'] as Color)),
          ),
          const SizedBox(height: 2),
          Text(s['label'] as String, style: TextStyle(fontSize: 10, color: (s['textColor'] as Color).withValues(alpha: 0.8)), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );
    }).toList());
  }

  Widget _buildCreateBudgetModal() {
    return Stack(children: [
      GestureDetector(onTap: () => setState(() => _showCreateBudgetModal = false), child: Container(color: Colors.black54)),
      Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text('Nouveau Budget Trimestriel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showCreateBudgetModal = false)),
              ]),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: 'Annee', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
                keyboardType: TextInputType.number,
                controller: _anneeCtrl,
                onChanged: (v) => setState(() => _newBudgetForm['annee'] = int.tryParse(v) ?? DateTime.now().year),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _newBudgetForm['trimestre'] as int,
                isDense: true,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Trimestre',
                  labelStyle: TextStyle(fontSize: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('T1 (Jan-Mar)', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 2, child: Text('T2 (Avr-Jun)', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 3, child: Text('T3 (Jul-Sep)', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 4, child: Text('T4 (Oct-Dec)', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (v) => setState(() => _newBudgetForm['trimestre'] = v ?? 1),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: 'Budget Total (MAD)', hintText: 'Ex: 500000', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() => _newBudgetForm['budgetTotal'] = v),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => setState(() => _showCreateBudgetModal = false),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Annuler', style: TextStyle(fontSize: 12))),
                )),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(
                  onPressed: _handleCreateBudget,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Creer', style: TextStyle(fontSize: 12))),
                )),
              ]),
            ]),
          ),
        ),
      ),
    ]);
  }

  Future<void> _handleCreateBudget() async {
    final total = double.tryParse((_newBudgetForm['budgetTotal'] as String? ?? '').replaceAll(',', '.')) ?? 0;
    if (total <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Montant invalide'), backgroundColor: AppTheme.danger));
      return;
    }
    try {
      final client = http.Client();
      final res = await client.post(
        Uri.parse('${ApiConfig.baseUrl}/budget/create'),
        headers: ApiConfig.headers,
        body: jsonEncode({'annee': _newBudgetForm['annee'], 'trimestre': _newBudgetForm['trimestre'], 'budgetTotal': total}),
      ).timeout(ApiConfig.timeout);
      client.close();
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget cree'), backgroundColor: AppTheme.success));
          setState(() => _showCreateBudgetModal = false);
          _loadAll();
        }
        return;
      }
    } catch (_) {}
    // Fallback local insert
    try {
      final annee = _newBudgetForm['annee'] as int? ?? DateTime.now().year;
      final trimestre = _newBudgetForm['trimestre'] as int? ?? 1;
      await BudgetDao().insert({
        'periode': '${annee}-Q$trimestre',
        'montantTotal': total,
        'montantUtilise': 0,
        'statut': 'ACTIF',
        'annee': annee,
        'trimestre': trimestre,
        'actif': 1,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget cree (local)'), backgroundColor: AppTheme.success));
        setState(() => _showCreateBudgetModal = false);
        _loadAll();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger));
    }
  }



  // ─── CHECKLISTS TAB ───
  Widget _buildChecklistsTab() {
    final nonConforme = _checklists.where((c) =>
      c['statut'] == 'REPAIRE' || (c['statut'] == 'COMPLETE' && c['estConforme'] == false) ||
      c['statut'] == 'VALIDATED' || c['statut'] == 'REJECTED'
    ).toList();
    final pending = _checklists.where((c) =>
      c['statut'] == 'PENDING' || c['statut'] == 'SUBMITTED' || c['statut'] == 'EN_ATTENTE'
    ).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        // Repairs awaiting validation
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.checklist, size: 18, color: Colors.indigo[400]),
              const SizedBox(width: 8),
              const Text('Checklists — Check-up Chauffeur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 4),
            Text('Liste des check-up non conformes et réparations en attente de validation RS.',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            if (nonConforme.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child:                 Text('Aucune checklist non conforme ou en attente',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              )
            else
              ...nonConforme.map((c) => _buildChecklistRow(c)),
          ]),
        ),
        const SizedBox(height: 12),
        // Pending checkups
        if (pending.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.schedule, size: 18, color: Colors.blue[400]),
                const SizedBox(width: 8),
                const Text('Check-ups en attente de validation RS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
              const SizedBox(height: 4),
              Text('Ces check-ups ont été soumis par les chauffeurs et attendent votre validation.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              ...pending.map((c) => _buildPendingChecklistRow(c)),
            ]),
          ),
      ]),
    );
  }

  // ─── DOCUMENTS TAB ───
  Widget _buildDocumentsTab() {
    return const RsDocuments(showAppBar: false);
  }

  // ─── POWER BI TAB ───
  Widget _buildPowerBiTab() {
    return const PowerBiView(showAppBar: false);
  }

  // ─── VEHICLE HISTORY TAB ───
  Widget _buildVehicleHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        // Vehicle selector
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.history, size: 18, color: Colors.cyan[500]),
              const SizedBox(width: 8),
              const Text('Historique Véhicule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _historyVehicleId,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Sélectionner un véhicule',
                labelStyle: const TextStyle(fontSize: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              items: _vehicles.map((v) => DropdownMenuItem(
                value: v['id'] as int? ?? 0,
                child: Text('${v['immatriculation'] ?? ''} - ${v['marque'] ?? ''}', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (id) {
                if (id != null && id > 0) _fetchVehicleHistory(id);
                else setState(() => _vehicleHistory = null);
              },
            ),
          ]),
        ),
        const SizedBox(height: 12),
        if (_vehicleHistory == null)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Column(children: [
              Icon(Icons.local_shipping, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('Sélectionnez un véhicule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[500])),
              const SizedBox(height: 4),
              Text('Consultez l\'historique complet: checkups, anomalies, documents, blocages, départs, tournées',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          )
        else
          _buildVehicleHistoryContent(),
      ]),
    );
  }

  Future<void> _fetchVehicleHistory(int vehicleId) async {
    setState(() => _historyVehicleId = vehicleId);
    try {
      final client = http.Client();
      final url = Uri.parse('${ApiConfig.baseUrl}/vehicles/$vehicleId/history');
      final res = await client.get(url).timeout(ApiConfig.timeout);
      client.close();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) setState(() => _vehicleHistory = data);
      }
    } catch (_) {
      // Use local data as fallback
      if (mounted) _buildLocalVehicleHistory(vehicleId);
    }
  }

  Future<void> _buildLocalVehicleHistory(int vehicleId) async {
    final v = _vehicles.where((v) => v['id'] == vehicleId).firstOrNull;
    if (v == null) return;
    final immat = v['immatriculation'] as String? ?? '';
    final localAnomalies = _anomalies.where((a) =>
      (a['vehiculeImmatriculation'] as String? ?? '').toLowerCase() == immat.toLowerCase()
    ).toList();
    if (mounted) {
      setState(() {
        _vehicleHistory = {
          'vehicle': v,
          'checkupsCount': 0,
          'anomaliesCount': localAnomalies.length,
          'documentsCount': 0,
          'anomaliesOuvertes': localAnomalies.where((a) => a['statut'] == 'DETECTEE' || a['statut'] == 'EN_REPARATION').length,
          'checklists': [],
          'anomalies': localAnomalies,
          'blocages': [],
          'departs': [],
          'tournees': [],
          'documentStatus': {},
          'blocageInfo': null,
        };
      });
    }
  }

  Widget _buildVehicleHistoryContent() {
    final h = _vehicleHistory!;
    final v = h['vehicle'] as Map<String, dynamic>? ?? {};
    final immat = v['immatriculation'] as String? ?? '';
    final marque = v['marque'] as String? ?? '';
    final modele = v['modele'] as String? ?? '';
    final chauffeur = v['chauffeurNom'] as String? ?? 'Non affecté';
    final statut = v['statut'] as String? ?? '-';
    final checkupsCount = h['checkupsCount'] ?? 0;
    final anomaliesCount = h['anomaliesCount'] ?? 0;
    final documentsCount = h['documentsCount'] ?? 0;
    final anomaliesOuvertes = h['anomaliesOuvertes'] ?? 0;
    final blocageInfo = h['blocageInfo'] as Map<String, dynamic>?;
    final departsCount = h['departsCount'] ?? 0;
    final tourneesCount = h['tourneesCount'] ?? 0;

    return Column(children: [
      // Vehicle Info Card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Column(children: [
          IntrinsicHeight(
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.cyan[50], borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.local_shipping, size: 28, color: Colors.cyan[600]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FittedBox(fit: BoxFit.scaleDown, child: Text(immat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  Text('$marque $modele', style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(children: [
                      Text('Chauffeur: $chauffeur', style: TextStyle(fontSize: 10, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(width: 8),
                      Text('Statut: ', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      Text(statut, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                        color: statut == 'BLOQUE' ? Colors.red : Colors.green)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Flexible(child: _histCountCard('Checkups', '$checkupsCount', Colors.blue)),
            const SizedBox(width: 6),
            Flexible(child: _histCountCard('Anomalies', '$anomaliesCount', Colors.red)),
            const SizedBox(width: 6),
            Flexible(child: _histCountCard('Documents', '$documentsCount', Colors.green)),
          ]),
          // Blocage/Deblocage info
          if (blocageInfo != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _histInfoCard('Date blocage', _fmtDate(blocageInfo['dateBlocage']), blocageInfo['bloquePar'] as String? ?? '')),
              const SizedBox(width: 6),
              Expanded(child: _histInfoCard('Date déblocage', _fmtDate(blocageInfo['dateDeblocage']), blocageInfo['debloquePar'] as String? ?? '')),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _histInfoCard('Raison blocage', blocageInfo['raisonBlocage'] as String? ?? '-', '')),
              const SizedBox(width: 6),
              Expanded(child: _histInfoCard('Départs/Tournées', '$departsCount / $tourneesCount', '')),
            ]),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      // Document Status
      if ((h['documentStatus'] as Map?)?.isNotEmpty == true)
        _buildHistorySection('Documents réglementaires', Icons.shield, Colors.indigo,
          Column(children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ...(h['documentStatus'] as Map<String, dynamic>).entries.map((e) {
                  final ds = e.value as Map<String, dynamic>;
                  final etat = ds['etat'] as String? ?? '';
                  final bgColor = etat == 'VALIDE' ? Colors.green : etat == 'EXPIRE_BIENTOT' ? Colors.amber : Colors.red;
                  final icon = _docTypeIcon(e.key);
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: bgColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: bgColor.withValues(alpha: 0.2))),
                    child: Column(children: [
                      Icon(icon, size: 14, color: bgColor),
                      Text(ds['label'] as String? ?? e.key, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: bgColor), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(ds['numero'] as String? ?? '-', style: TextStyle(fontSize: 6, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (ds['dateExpiration'] != null)
                        Text('Exp: ${_toDateStr(ds['dateExpiration'])}', style: TextStyle(fontSize: 6, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  );
                }),
              ]),
            ),
          ])),
      // Check-ups
      _buildHistorySection('Check-ups Chauffeur ($checkupsCount)', Icons.checklist, Colors.indigo,
        Column(children: _buildChecklistsHistory(h['checklists'] as List? ?? []))),
      // Anomalies
      _buildHistorySection('Anomalies ($anomaliesCount) - $anomaliesOuvertes ouvertes', Icons.warning, Colors.red,
        Column(children: _buildAnomaliesHistory(h['anomalies'] as List? ?? []))),
      // Blocages
      _buildHistorySection('Historique Blocages/Déblocages', Icons.block, Colors.orange,
        Column(children: _buildBlocagesHistory(h['blocages'] as List? ?? []))),
      // Departs
      _buildHistorySection('Départs ($departsCount)', Icons.local_shipping, Colors.blue,
        Column(children: _buildDepartsHistory(h['departs'] as List? ?? []))),
      // Tournees
      _buildHistorySection('Tournées ($tourneesCount)', Icons.calendar_today, Colors.purple,
        Column(children: _buildTourneesHistory(h['tournees'] as List? ?? []))),
    ]);
  }

  Widget _buildHistorySection(String title, IconData icon, Color color, Widget content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[800])),
        ]),
        const SizedBox(height: 8),
        content,
      ]),
    );
  }

  List<Widget> _buildChecklistsHistory(List checklists) {
    if (checklists.isEmpty) return [Text('Aucun check-up enregistré', style: TextStyle(fontSize: 11, color: Colors.grey[400]))];
    return checklists.take(10).map((cl) {
      final statut = cl['statut'] as String? ?? '';
      final conforme = cl['estConforme'];
      final statutColor = statut == 'VALIDATED' ? Colors.green : statut == 'PENDING' ? Colors.blue : statut == 'REJECTED' ? Colors.red : statut == 'COMPLETE' ? Colors.red : Colors.amber;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[200]!)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              Text(_fmtDate(cl['dateChecklist']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: statutColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: FittedBox(child: Text(statut, style: TextStyle(fontSize: 8, color: statutColor, fontWeight: FontWeight.bold))),
              ),
              if (conforme != null) ...[
                const SizedBox(width: 4),
                Icon(conforme == true ? Icons.check_circle : Icons.cancel, size: 11, color: conforme == true ? Colors.green : Colors.red),
                Text(conforme == true ? 'Conforme' : 'Non conforme', style: TextStyle(fontSize: 8, color: conforme == true ? Colors.green : Colors.red)),
              ],
            ]),
          ),
          if (cl['chauffeurNom'] != null || cl['tourneeId'] != null)
              Text('Chauffeur: ${cl['chauffeurNom'] ?? '-'} | Tournée: ${cl['tourneeId'] ?? '-'}',
                style: TextStyle(fontSize: 9, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
          // Checklist items
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: [
            _checklistItem('Pneus', cl['pneus']),
            _checklistItem('Freins', cl['freins']),
            _checklistItem('Feux', cl['feux']),
            _checklistItem('Extincteur', cl['extincteur']),
            _checklistItem('Documents', cl['documents']),
            _checklistItem('Carrosserie', cl['carrosserie']),
            _checklistItem('Huile', cl['huileNiveau']),
            _checklistItem('Batterie', cl['batterie']),
            _checklistItem('Essuie-glaces', cl['essuieGlaces']),
            _checklistItem('Ceintures', cl['ceinturesSecurite']),
          ]),
          if (cl['defautsJson'] != null && cl['defautsJson'] != '[]' && cl['defautsJson'] != '{}')
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('Défauts: ${cl['defautsJson']}',
              style: TextStyle(fontSize: 9, color: Colors.red[600], fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (cl['commentaireGeneral'] != null && (cl['commentaireGeneral'] as String).isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 2), child: Text('Commentaire: ${cl['commentaireGeneral']}',
              style: TextStyle(fontSize: 9, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (cl['reparationsJson'] != null && cl['reparationsJson'] != '[]' && cl['reparationsJson'] != '{}')
            Padding(padding: const EdgeInsets.only(top: 2), child: Text('Réparations: ${cl['reparationsJson']}',
              style: TextStyle(fontSize: 9, color: Colors.amber[700], fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (cl['validePar'] != null)
            Padding(padding: const EdgeInsets.only(top: 2), child: Text('Validé par: ${cl['validePar']} ${cl['dateValidation'] != null ? 'le ${_fmtDate(cl['dateValidation'])}' : ''}',
              style: TextStyle(fontSize: 8, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      );
    }).toList();
  }

  Widget _checklistItem(String label, dynamic value) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label: ', style: TextStyle(fontSize: 8, color: Colors.grey[500])),
      value == true
          ? Icon(Icons.check_circle, size: 10, color: Colors.green)
          : value == false
              ? Icon(Icons.cancel, size: 10, color: Colors.red)
              : Text('-', style: TextStyle(fontSize: 8, color: Colors.grey[300])),
    ]);
  }

  List<Widget> _buildAnomaliesHistory(List anomalies) {
    if (anomalies.isEmpty) return [Text('Aucune anomalie enregistrée', style: TextStyle(fontSize: 11, color: Colors.grey[400]))];
    return anomalies.take(10).map((a) {
      final statut = a['statut'] as String? ?? '';
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (_anomalieStatutColors[statut] ?? Colors.grey).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_anomalieStatutLabels[statut] ?? statut,
                style: TextStyle(fontSize: 8, color: _anomalieStatutColors[statut] ?? Colors.grey, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text('${a['elementVehicule'] ?? a['element'] ?? '-'}',
                style: TextStyle(fontSize: 10, color: Colors.grey[800], fontWeight: FontWeight.w500))),
              Text('${a['descriptionFrancais'] ?? a['description'] ?? '-'}',
                style: TextStyle(fontSize: 8, color: Colors.grey[500]), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (a['photoUrl'] != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.image, size: 12, color: Colors.blue[400]),
            ),
          FittedBox(fit: BoxFit.scaleDown, child: Text(_toDateStr(a['dateDetection']), style: TextStyle(fontSize: 8, color: Colors.grey[500]))),
        ]),
      );
    }).toList();
  }

  List<Widget> _buildBlocagesHistory(List blocages) {
    if (blocages.isEmpty) return [Text('Aucun historique de blocage', style: TextStyle(fontSize: 11, color: Colors.grey[400]))];
    return blocages.map((b) {
      final bloque = b['bloque'] == true;
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (bloque ? Colors.red : Colors.green).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: FittedBox(child: Text(bloque ? 'Bloqué' : 'Débloqué',
                style: TextStyle(fontSize: 8, color: bloque ? Colors.red : Colors.green, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(b['raison'] as String? ?? '-', style: TextStyle(fontSize: 10, color: Colors.grey[700]), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text('Blocage: ${_fmtDate(b['dateBlocage'])}', style: TextStyle(fontSize: 8, color: Colors.grey[500]))),
            if (b['dateDeblocage'] != null) ...[
              const SizedBox(width: 4),
              FittedBox(fit: BoxFit.scaleDown, child: Text('Déblocage: ${_fmtDate(b['dateDeblocage'])}', style: TextStyle(fontSize: 8, color: Colors.green))),
            ],
            if (b['bloquePar'] != null) ...[
              const SizedBox(width: 4),
              FittedBox(fit: BoxFit.scaleDown, child: Text('par ${b['bloquePar']}', style: TextStyle(fontSize: 8, color: Colors.grey[500]))),
            ],
          ]),
        ),
      );
    }).toList();
  }

  List<Widget> _buildDepartsHistory(List departs) {
    if (departs.isEmpty) return [Text('Aucun départ enregistré', style: TextStyle(fontSize: 11, color: Colors.grey[400]))];
    return departs.take(10).map((d) {
      final resultat = d['resultatControle'] as String? ?? '-';
      final conforme = resultat == 'CONFORME';
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (conforme ? Colors.green : Colors.red).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: FittedBox(child: Text(resultat, style: TextStyle(fontSize: 8, color: conforme ? Colors.green : Colors.red, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(d['numeroDepart'] as String? ?? '-', style: TextStyle(fontSize: 10, color: Colors.grey[700]), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text('${d['dateDepart'] ?? ''} ${d['heureDepart'] ?? ''}', style: TextStyle(fontSize: 8, color: Colors.grey[500]))),
            const SizedBox(width: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text('${d['chauffeurNom'] ?? '-'}', style: TextStyle(fontSize: 8, color: Colors.grey[500]))),
          ]),
        ),
      );
    }).toList();
  }

  List<Widget> _buildTourneesHistory(List tournees) {
    if (tournees.isEmpty) return [Text('Aucune tournée enregistrée', style: TextStyle(fontSize: 11, color: Colors.grey[400]))];
    return tournees.take(10).map((t) {
      final statut = t['statut'] as String? ?? '';
      final statutColor = statut == 'TERMINEE' ? Colors.green : statut == 'EN_COURS' ? Colors.blue : Colors.amber;
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statutColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6),
              ),
              child: FittedBox(child: Text(statut, style: TextStyle(fontSize: 8, color: statutColor, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(t['numeroTournee'] ?? t['idTournee'] ?? '-', style: TextStyle(fontSize: 10, color: Colors.grey[700]), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text(_toDateStr(t['dateTournee']), style: TextStyle(fontSize: 8, color: Colors.grey[500]))),
            if (t['site'] != null) ...[
              const SizedBox(width: 4),
              FittedBox(fit: BoxFit.scaleDown, child: Text('Site: ${t['site']}', style: TextStyle(fontSize: 8, color: Colors.grey[500]))),
            ],
          ]),
        ),
      );
    }).toList();
  }

  Widget _histCountCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color))),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _histInfoCard(String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 8, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  // ─── CHECKLIST ROW ───
  Widget _buildChecklistRow(Map<String, dynamic> c) {
    final id = c['id'] as int? ?? 0;
    final immat = c['vehiculeImmatriculation'] as String? ?? '';
    final chauffeur = c['chauffeurNom'] as String? ?? '-';
    final date = _fmtDate(c['dateChecklist']);
    final statut = c['statut'] as String? ?? '';
    final conforme = c['estConforme'];
    final statutColor = statut == 'VALIDATED' ? Colors.green : statut == 'REJECTED' ? Colors.red : statut == 'REPAIRE' ? Colors.amber : Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  Text(immat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace')),
                  const SizedBox(width: 8),
                  FittedBox(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: statutColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(statut, style: TextStyle(fontSize: 8, color: statutColor, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (conforme != null) ...[
                    const SizedBox(width: 4),
                    Icon(conforme == true ? Icons.check_circle : Icons.cancel, size: 12, color: conforme == true ? Colors.green : Colors.red),
                    FittedBox(child: Text(conforme == true ? 'Conforme' : 'Non conforme', style: TextStyle(fontSize: 8, color: conforme == true ? Colors.green : Colors.red))),
                  ],
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 2),
          Text('$chauffeur • $date', style: TextStyle(fontSize: 10, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          if (statut == 'REPAIRE')
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  height: 28,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Réparé', style: TextStyle(fontSize: 10)),
                    onPressed: () => _validerChecklistRepair(id),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 28,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Non réparé', style: TextStyle(fontSize: 10)),
                    onPressed: () => _rejeterChecklistRepair(id),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
              ]),
            ),
          if (statut == 'COMPLETE' && conforme == false)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                height: 28,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.build, size: 14),
                  label: const Text('Réparation effectuée', style: TextStyle(fontSize: 10)),
                  onPressed: () => _marquerChecklistRepare(id),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ),
            ),
          if (statut == 'VALIDATED')
            FittedBox(fit: BoxFit.scaleDown, child: Text('✓ Validée', style: TextStyle(fontSize: 11, color: Colors.green[600], fontWeight: FontWeight.w600))),
          if (statut == 'REJECTED')
            FittedBox(fit: BoxFit.scaleDown, child: Text('✗ Rejetée', style: TextStyle(fontSize: 11, color: Colors.red[600], fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildPendingChecklistRow(Map<String, dynamic> c) {
    final id = c['id'] as int? ?? 0;
    final immat = c['vehiculeImmatriculation'] as String? ?? '';
    final chauffeur = c['chauffeurNom'] as String? ?? '-';
    final date = _fmtDate(c['dateChecklist']);
    final conforme = c['estConforme'];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(fit: BoxFit.scaleDown, child: Text(immat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'))),
                const SizedBox(height: 2),
                Text('$chauffeur • $date', style: TextStyle(fontSize: 10, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (conforme != null)
                  Row(children: [
                    Icon(conforme == true ? Icons.check_circle : Icons.cancel, size: 11, color: conforme == true ? Colors.green : Colors.red),
                    const SizedBox(width: 4),
                    Flexible(child: Text(conforme == true ? 'Conforme' : 'Non conforme', style: TextStyle(fontSize: 9, color: conforme == true ? Colors.green : Colors.red), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
              ]),
            ),
            SizedBox(
              height: 28,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, size: 14),
                label: const Text('Valider', style: TextStyle(fontSize: 10)),
                onPressed: () => _validerPendingChecklist(id),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _validerChecklistRepair(int id) async {
    try {
      final client = http.Client();
      await client.put(Uri.parse('${ApiConfig.baseUrl}/checklists/$id/validate-repair'), headers: ApiConfig.headers).timeout(ApiConfig.timeout);
      client.close();
      _loadAll();
    } catch (_) {}
  }

  Future<void> _rejeterChecklistRepair(int id) async {
    try {
      final client = http.Client();
      await client.put(Uri.parse('${ApiConfig.baseUrl}/checklists/$id/reject-repair'), headers: ApiConfig.headers).timeout(ApiConfig.timeout);
      client.close();
      _loadAll();
    } catch (_) {}
  }

  Future<void> _marquerChecklistRepare(int id) async {
    try {
      final client = http.Client();
      await client.put(Uri.parse('${ApiConfig.baseUrl}/checklists/$id/mark-repaired'), headers: ApiConfig.headers).timeout(ApiConfig.timeout);
      client.close();
      _loadAll();
    } catch (_) {}
  }

  Future<void> _validerPendingChecklist(int id) async {
    try {
      final client = http.Client();
      await client.put(Uri.parse('${ApiConfig.baseUrl}/checklists/$id/validate'), headers: ApiConfig.headers).timeout(ApiConfig.timeout);
      client.close();
      _loadAll();
    } catch (_) {}
  }

  Widget _buildPlaceholder(String title, IconData icon) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Text('Contenu à implémenter', style: TextStyle(fontSize: 14, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  // ─── SHARED ───
  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Exporter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.table_chart, color: AppTheme.primary),
              title: const Text('Excel complet'),
              subtitle: const Text('Déclarations, Check-ups, Départs'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await ExportService().exportExcel();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export Excel généré'), backgroundColor: AppTheme.success));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: AppTheme.danger),
              title: const Text('Déclarations CSV'),
              subtitle: const Text('Export CSV des déclarations'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await ExportService().exportDeclarationsCSV();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export CSV généré'), backgroundColor: AppTheme.success));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.build_circle, color: AppTheme.warning),
              title: const Text('Check-ups CSV'),
              subtitle: const Text('Export CSV des check-ups'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await ExportService().exportCheckupsCSV();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export CSV généré'), backgroundColor: AppTheme.success));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger));
                }
              },
            ),
          ]),
        ),
      ),
    );
  }

  Widget _miniKpi(String title, String value, IconData icon, Color color) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(title, style: TextStyle(fontSize: 9, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _BudgetLabelValue extends StatelessWidget {
  final String label;
  final String value;
  const _BudgetLabelValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
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
        color: isActive ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.textSecondary.withValues(alpha: 0.1),
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
