import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../models/evolution_data.dart';
import '../../services/powerbi_service.dart';
import '../../services/vehicle_service.dart';
import '../../widgets/evolution_chart.dart';

class PowerBiView extends StatefulWidget {
  const PowerBiView({super.key});

  @override
  State<PowerBiView> createState() => _PowerBiViewState();
}

class _PowerBiViewState extends State<PowerBiView> {
  final PowerBiService _powerbi = PowerBiService();
  final VehicleService _vehicleSvc = VehicleService();
  List<Map<String, dynamic>> _vehicles = [];
  Map<String, dynamic>? _evolution;
  String? _selectedImmat;
  String? _mois1;
  String? _mois2;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      _vehicles = await _vehicleSvc.getAll();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadEvolution() async {
    if (_selectedImmat == null) return;
    setState(() => _loading = true);
    try {
      _evolution = await _powerbi.getVehicleEvolution(
        _selectedImmat!,
        mois1: _mois1,
        mois2: _mois2,
      );
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _onVehicleChanged(String immat) async {
    setState(() {
      _selectedImmat = immat;
      _mois1 = null;
      _mois2 = null;
      _evolution = null;
    });
    try {
      final months = await _powerbi.getAvailableMonths(immat);
      if (months.isNotEmpty && mounted) {
        setState(() {
          _mois1 = months.last;
          _mois2 = months.first;
        });
        _loadEvolution();
      } else {
        _loadEvolution();
      }
    } catch (_) {
      _loadEvolution();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Translations.t('powerbi.evolution'))),
      body: _loading && _vehicles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _VehicleSelector(
                  vehicles: _vehicles,
                  selectedImmat: _selectedImmat,
                  onChanged: _onVehicleChanged,
                ),
                if (_evolution != null) ...[
                  const SizedBox(height: 16),
                  if (((_evolution!['moisDisponibles'] as List?)?.length ?? 0) >
                      1) ...[
                    _MonthChips(
                      months: (_evolution!['moisDisponibles'] as List)
                          .map((e) => e as String)
                          .toList(),
                      selectedMonth: _mois1,
                      label: 'Mois 1 (début)',
                      onChanged: (m) {
                        setState(() => _mois1 = m);
                        _loadEvolution();
                      },
                    ),
                    const SizedBox(height: 8),
                    _MonthChips(
                      months: (_evolution!['moisDisponibles'] as List)
                          .map((e) => e as String)
                          .toList(),
                      selectedMonth: _mois2,
                      label: 'Mois 2 (fin)',
                      onChanged: (m) {
                        setState(() => _mois2 = m);
                        _loadEvolution();
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildEvolutionChart(),
                  const SizedBox(height: 12),
                  _buildPanneChart(),
                ],
              ],
            ),
    );
  }

  Widget _buildEvolutionChart() {
    final evolution = (_evolution!['evolution'] as List?) ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Évolution des coûts',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            EvolutionChart(
              data: evolution
                  .map(
                    (e) => EvolutionData(
                      mois: e['mois'] as String? ?? '',
                      coutTotal: (e['coutTotal'] as num?)?.toDouble() ?? 0,
                      nombrePannes: e['nombrePannes'] as int? ?? 0,
                    ),
                  )
                  .toList(),
              metric: 'coutTotal',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanneChart() {
    final evolution = (_evolution!['evolution'] as List?) ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nombre de pannes',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            EvolutionChart(
              data: evolution
                  .map(
                    (e) => EvolutionData(
                      mois: e['mois'] as String? ?? '',
                      coutTotal: (e['coutTotal'] as num?)?.toDouble() ?? 0,
                      nombrePannes: e['nombrePannes'] as int? ?? 0,
                    ),
                  )
                  .toList(),
              metric: 'nombrePannes',
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleSelector extends StatelessWidget {
  final List<Map<String, dynamic>> vehicles;
  final String? selectedImmat;
  final ValueChanged<String> onChanged;

  const _VehicleSelector({
    required this.vehicles,
    required this.selectedImmat,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sélectionnez un véhicule',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: vehicles.map((v) {
                final immat = v['immatriculation'] as String? ?? '';
                final selected = immat == selectedImmat;
                return ChoiceChip(
                  label: Text(
                    immat,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? Colors.white : null,
                    ),
                  ),
                  selected: selected,
                  selectedColor: AppTheme.primary,
                  backgroundColor: Colors.grey.shade100,
                  onSelected: (_) => onChanged(immat),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthChips extends StatelessWidget {
  final List<String> months;
  final String? selectedMonth;
  final ValueChanged<String> onChanged;
  final String label;

  const _MonthChips({
    required this.months,
    required this.selectedMonth,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: months.map((m) {
                final selected = m == selectedMonth;
                return ChoiceChip(
                  label: Text(
                    _formatMonth(m),
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : null,
                    ),
                  ),
                  selected: selected,
                  selectedColor: AppTheme.primary,
                  backgroundColor: Colors.grey.shade100,
                  onSelected: (_) => onChanged(m),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMonth(String m) {
    if (m.length >= 7) {
      final parts = m.split('-');
      if (parts.length >= 2) {
        const months = [
          'Jan',
          'Fév',
          'Mar',
          'Avr',
          'Mai',
          'Juin',
          'Juil',
          'Aoû',
          'Sep',
          'Oct',
          'Nov',
          'Déc',
        ];
        final idx = int.tryParse(parts[1]) ?? 0;
        if (idx >= 1 && idx <= 12) {
          return '${months[idx - 1]} ${parts[0]}';
        }
      }
    }
    return m;
  }
}
