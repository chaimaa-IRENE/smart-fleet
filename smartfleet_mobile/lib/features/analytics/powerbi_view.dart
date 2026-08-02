import 'package:flutter/material.dart';
import 'powerbi_data.dart';
import 'powerbi_theme.dart';
import 'powerbi_executive_view.dart';
import 'powerbi_vehicle_detail_view.dart';
import 'powerbi_anomaly_view.dart';
import 'powerbi_drivers_view.dart';

class PowerBiView extends StatefulWidget {
  final bool showAppBar;
  const PowerBiView({super.key, this.showAppBar = true});

  @override
  State<PowerBiView> createState() => _PowerBiViewState();
}

class _PowerBiViewState extends State<PowerBiView> {
  final PowerBiDataLoader _loader = PowerBiDataLoader();

  DashboardData? _data;
  bool _loading = true;
  String? _error;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _page = 'executive';
  bool _sidebarCollapsed = false;
  bool _filterOpen = false;

  void _selectPage(String key) {
    setState(() => _page = key);
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      _scaffoldKey.currentState!.closeDrawer();
    }
  }

  final Map<String, String> _filters = {
    'period': '30j',
    'site': '',
    'vehicle': '',
    'driver': '',
    'status': '',
    'criticite': '',
    'typePanne': '',
    'region': '',
    'prestataire': '',
    'ville': '',
    'annee': '',
    'mois': '',
  };

  static const _bg = Color(0xFF0F172A);
  static const _sidebarBg = Color(0xFF08192D);
  static const _border = Color(0x0DFFFFFF);
  static const _border2 = Color(0x1AFFFFFF);
  static const _textPrimary = Color(0xFFD1D5DB);
  static const _textSecondary = Color(0xFF9CA3AF);
  static const _textTertiary = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _loader.load();
      if (mounted) setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Impossible de charger les données';
        _loading = false;
      });
    }
  }

  DashboardData? get _filtered =>
      _data == null ? null : filterDashboardData(_data!, _filters);

  String _todayFr() {
    final now = DateTime.now();
    const jours = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
    const mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
    return '${jours[now.weekday - 1]} ${now.day} ${mois[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 640;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bg,
      drawer: isNarrow ? _buildDrawer() : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isNarrow) _buildSidebar(),
                  Expanded(child: _buildContent(isNarrow: isNarrow)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    const items = [
      ('executive', 'Executive Dashboard', Icons.dashboard_outlined),
      ('vehicles', 'Détail Véhicules', Icons.local_shipping_outlined),
      ('anomalies', 'Analyse Anomalies', Icons.warning_amber_rounded),
      ('drivers', 'Performance Chauffeurs', Icons.group_outlined),
    ];
    return Drawer(
      backgroundColor: _sidebarBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [PbiColors.blue, PbiColors.indigo],
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.local_shipping, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Smart Fleet',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xF2FFFFFF),
                                letterSpacing: -0.2)),
                        Text(
                          'Power BI Dashboard',
                          style: TextStyle(fontSize: 10, color: Color(0x99BFDBFE), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                children: [
                  for (final it in items) ...[
                    _navItem(it.$1, it.$2, it.$3, it.$3, false),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SIDEBAR ───
  Widget _buildSidebar() {
    final collapsed = _sidebarCollapsed;
    final width = collapsed ? 64.0 : 216.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: width,
      decoration: const BoxDecoration(
        color: _sidebarBg,
        border: Border(right: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [PbiColors.blue, PbiColors.indigo],
                    ),
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x333B82F6),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.local_shipping, size: 20, color: Colors.white),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Smart Fleet',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: PbiColors.white.withValues(alpha: 0.95),
                                letterSpacing: -0.2)),
                        const SizedBox(height: 1),
                        const Text(
                          'Power BI Dashboard',
                          style: TextStyle(fontSize: 9, color: Color(0x99BFDBFE), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                children: [
                  _navItem('executive', 'Executive Dashboard',
                      Icons.dashboard_outlined, Icons.dashboard, collapsed),
                  const SizedBox(height: 4),
                  _navItem('vehicles', 'Détail Véhicules',
                      Icons.local_shipping_outlined, Icons.local_shipping, collapsed),
                  const SizedBox(height: 4),
                  _navItem('anomalies', 'Analyse Anomalies',
                      Icons.warning_amber_rounded, Icons.warning_amber_rounded, collapsed),
                  const SizedBox(height: 4),
                  _navItem('drivers', 'Performance Chauffeurs',
                      Icons.group_outlined, Icons.group, collapsed),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: collapsed ? 0 : 0.5,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.chevron_right,
                          size: 16, color: _textTertiary),
                    ),
                    if (!collapsed) ...[
                      const SizedBox(width: 10),
                      Text('Réduire',
                          style: TextStyle(fontSize: 12, color: _textTertiary)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(String key, String label, IconData icon, IconData activeIcon,
      bool collapsed) {
    final isActive = _page == key;
    final color = isActive ? PbiColors.blue : _textTertiary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectPage(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0x333B82F6) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isActive ? const Color(0x333B82F6) : Colors.transparent),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                        color: Color(0x403B82F6), blurRadius: 16),
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (isActive) ...[
                Container(width: 2, height: 20,
                    decoration: BoxDecoration(
                        color: const Color(0xFF60A5FA),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
              ],
              Icon(isActive ? activeIcon : icon, size: 17, color: color),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? const Color(0xFF93C5FD)
                          : _textSecondary,
                    ),
                  ),
                ),
                if (isActive)
                  const Icon(Icons.chevron_right,
                      size: 12, color: PbiColors.blue),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── CONTENT (header + filters + page) ───
  Widget _buildContent({required bool isNarrow}) {
    return Column(
      children: [
        _buildHeader(isNarrow: isNarrow),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _filterOpen && _data != null ? _buildFilterPanel() : const SizedBox.shrink(),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader({required bool isNarrow}) {
    const titles = {
      'executive': 'Executive Dashboard',
      'vehicles': 'Détail Véhicules',
      'anomalies': 'Analyse Anomalies',
      'drivers': 'Performance Chauffeurs',
    };
    final title = titles[_page] ?? 'Executive Dashboard';
    final padding = isNarrow
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 12);

    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          if (isNarrow) ...[
            _buildHeaderIconButton(
              icon: Icons.menu,
              tooltip: 'Menu',
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: isNarrow ? 13 : 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.2)),
                ),
                if (!isNarrow) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x1A3B82F6),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x333B82F6)),
                      ),
                      child: Text(_todayFr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF60A5FA))),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildPeriodSelect(),
          const SizedBox(width: 6),
          _buildHeaderIconButton(
            icon: Icons.tune,
            tooltip: 'Filtres',
            active: _filterOpen,
            onTap: () => setState(() => _filterOpen = !_filterOpen),
          ),
          const SizedBox(width: 6),
          _buildHeaderIconButton(
            icon: Icons.refresh,
            tooltip: 'Actualiser',
            spinning: _loading,
            onTap: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelect() {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 11, color: _textTertiary),
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filters['period'],
              isDense: true,
              dropdownColor: _bg,
              style: const TextStyle(fontSize: 11, color: _textPrimary),
              icon: const Icon(Icons.arrow_drop_down, size: 16, color: _textTertiary),
              items: const [
                DropdownMenuItem(value: '7j', child: Text('7 jours')),
                DropdownMenuItem(value: '30j', child: Text('30 jours')),
                DropdownMenuItem(value: '90j', child: Text('90 jours')),
                DropdownMenuItem(value: '1a', child: Text('1 an')),
              ],
              onChanged: (v) => setState(() => _filters['period'] = v ?? '30j'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
    bool spinning = false,
  }) {
    return Material(
      color: active ? const Color(0x333B82F6) : const Color(0x0DFFFFFF),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? const Color(0x333B82F6) : _border),
          ),
          child: Center(
            child: spinning
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: PbiColors.blue))
                : Icon(icon,
                    size: 14,
                    color: active ? const Color(0xFF60A5FA) : _textTertiary),
          ),
        ),
      ),
    );
  }

  // ─── FILTER PANEL (12 filtres, ordre web) ───
  Widget _buildFilterPanel() {
    final fo = _data!.filterOptions;
    final sites = ((fo['sites'] as List?) ?? []).cast<String>();
    final vehicles = ((fo['vehicles'] as List?) ?? [])
        .map((v) => (v as Map)['immatriculation'].toString())
        .where((s) => s.isNotEmpty)
        .toList();
    final drivers = ((fo['drivers'] as List?) ?? []).cast<String>();
    final status = ((fo['status'] as List?) ?? []).cast<String>();
    final criticites = ((fo['criticites'] as List?) ?? []).cast<String>();
    final typesPanne = ((fo['typesPanne'] as List?) ?? []).cast<String>();
    final regions = ((fo['regions'] as List?) ?? []).cast<String>();
    final prestataires = ((fo['prestataires'] as List?) ?? []).cast<String>();
    final villes = ((fo['villes'] as List?) ?? []).cast<String>();
    final annees = ((fo['annees'] as List?) ?? []).cast<String>();
    final mois = ((fo['mois'] as List?) ?? []).cast<String>();

    final entries = <_FilterEntry>[
      _FilterEntry(
          key: 'period',
          placeholder: 'Période',
          icon: Icons.calendar_today,
          options: const [
            ('7j', '7 jours'),
            ('30j', '30 jours'),
            ('90j', '90 jours'),
            ('1a', '1 an'),
          ]),
      _FilterEntry(key: 'site', placeholder: 'Tous sites',
          icon: Icons.location_on_outlined,
          options: sites.map((s) => (s, s)).toList()),
      _FilterEntry(key: 'vehicle', placeholder: 'Tous véhicules',
          icon: Icons.local_shipping_outlined,
          options: vehicles.map((s) => (s, s)).toList()),
      _FilterEntry(key: 'driver', placeholder: 'Tous chauffeurs',
          icon: Icons.group_outlined,
          options: drivers.map((s) => (s, s)).toList()),
      _FilterEntry(key: 'status', placeholder: 'Tous statuts',
          icon: Icons.warning_amber_rounded,
          options: status.map((s) => (s, s)).toList()),
      _FilterEntry(key: 'criticite', placeholder: 'Toutes criticites',
          icon: Icons.warning_amber_rounded,
          options: criticites.map((s) => (s, s)).toList()),
      _FilterEntry(key: 'typePanne', placeholder: 'Tous types panne',
          icon: Icons.build_outlined,
          options: typesPanne.map((s) => (s, s)).toList()),
      _FilterEntry(key: 'region', placeholder: 'Toutes régions',
          icon: Icons.location_city_outlined,
          options: regions.map((s) => (s, s)).toList()),
      _FilterEntry(
          key: 'prestataire',
          placeholder: prestataires.isEmpty ? 'Aucun prestataire' : 'Tous prestataires',
          icon: Icons.engineering_outlined,
          options: prestataires.map((s) => (s, s)).toList()),
      _FilterEntry(key: 'ville', placeholder: 'Toutes villes',
          icon: Icons.location_city_outlined,
          options: villes.map((s) => (s, s)).toList()),
      _FilterEntry(key: 'annee', placeholder: 'Toutes années',
          icon: Icons.calendar_today,
          options: annees.map((s) => (s, s)).toList()),
      _FilterEntry(key: 'mois', placeholder: 'Tous mois',
          icon: Icons.calendar_today,
          options: mois.map((s) => (s, s)).toList()),
    ];

    final isNarrow = MediaQuery.sizeOf(context).width < 640;
    return Container(
      padding: isNarrow
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: _sidebarBg,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.maxWidth < 500
              ? 2
              : constraints.maxWidth < 900
                  ? 3
                  : 6;
          final w = (constraints.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: entries
                .map((e) => SizedBox(
                      width: w,
                      child: _buildFilterSelect(e),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildFilterSelect(_FilterEntry e) {
    final value = _filters[e.key] ?? '';
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border2),
      ),
      child: Row(
        children: [
          Icon(e.icon, size: 12, color: _textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value.isEmpty ? null : value,
                hint: Text(e.placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: _textSecondary)),
                isExpanded: true,
                isDense: true,
                dropdownColor: _sidebarBg,
                style: const TextStyle(fontSize: 10, color: _textPrimary),
                icon: const Icon(Icons.arrow_drop_down,
                    size: 16, color: _textTertiary),
                items: e.options
                    .map((o) => DropdownMenuItem(
                        value: o.$1,
                        child: Text(o.$2,
                            maxLines: 1, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: e.options.isEmpty
                    ? null
                    : (v) => setState(() => _filters[e.key] = v ?? ''),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BODY (page active / erreur) ───
  Widget _buildBody() {
    if (_error != null && _data == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Icon(Icons.warning_amber_rounded,
                size: 48, color: Color(0x80EF4444)),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _textTertiary)),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _load,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x1A3B82F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x333B82F6)),
                ),
                child: const Text('Réessayer',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF60A5FA))),
              ),
            ),
          ],
        ),
      );
    }

    final data = _filtered;
    if (data == null) {
      return const Center(
        child: CircularProgressIndicator(color: PbiColors.blue),
      );
    }

    final isNarrow = MediaQuery.sizeOf(context).width < 640;
    return SingleChildScrollView(
      padding: isNarrow
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
          : const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey(_page),
          child: _buildPage(data),
        ),
      ),
    );
  }

  Widget _buildPage(DashboardData data) {
    switch (_page) {
      case 'vehicles':
        return VehicleDetailView(data: data);
      case 'anomalies':
        return AnomalyAnalysisView(data: data);
      case 'drivers':
        return DriverPerformanceView(data: data);
      default:
        return ExecutiveDashboardView(data: data);
    }
  }
}

class _FilterEntry {
  final String key;
  final String placeholder;
  final IconData icon;
  final List<(String, String)> options;
  const _FilterEntry({
    required this.key,
    required this.placeholder,
    required this.icon,
    required this.options,
  });
}
