import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_sizes.dart';
import '../../providers/auth_provider.dart';
import '../../services/tracking_service.dart';
import '../../widgets/danone_app_bar.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/premium/premium_kpi_card.dart';

class TrackingView extends StatefulWidget {
  const TrackingView({super.key});

  @override
  State<TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends State<TrackingView> {
  final TrackingService _svc = TrackingService();
  List<Map<String, dynamic>> _positions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _positions = await _svc.getAllLatest();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _simulerPosition() async {
    final user = context.read<AuthProvider>().user;
    final rng = DateTime.now().millisecondsSinceEpoch % 100;
    await _svc.updatePosition(
      'TEST-001',
      33.5731 + rng / 1000,
      -7.5898 + rng / 1000,
      vitesse: 30 + rng.toDouble(),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enRoute = _positions.where((p) => p['allumage'] == true).length;
    final total = _positions.length;

    return Scaffold(
      appBar: DanoneAppBar(
        title: 'Tracking GPS',
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 10, color: enRoute > 0 ? AppTheme.success : AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text('$enRoute/$total', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.my_location), onPressed: _simulerPosition),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _positions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gps_off, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          const Text('Aucune position GPS enregistrée',
                              style: TextStyle(color: AppTheme.textSecondary)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.my_location),
                            label: const Text('Simuler une position'),
                            onPressed: _simulerPosition,
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(AppSizes.paddingL),
                      children: [
                        Row(
                          children: [
                            Expanded(child: PremiumKpiCard(
                              title: 'Véhicules', value: '$total',
                              icon: Icons.directions_car, color: AppTheme.primary,
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: PremiumKpiCard(
                              title: 'En route', value: '$enRoute',
                              icon: Icons.speed, color: AppTheme.success,
                            )),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: PremiumKpiCard(
                              title: 'À l\'arrêt', value: '${total - enRoute}',
                              icon: Icons.pause_circle, color: AppTheme.warning,
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: PremiumKpiCard(
                              title: 'Total positions', value: '${_positions.length}',
                              icon: Icons.gps_fixed, color: AppTheme.accent,
                            )),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text('Dernières positions',
                            style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                            )),
                        const SizedBox(height: 12),
                        ...(_positions.take(20).map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildPositionCard(p),
                        ))),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
    );
  }

  Widget _buildPositionCard(Map<String, dynamic> p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lat = (p['latitude'] as num?)?.toDouble() ?? 0;
    final lng = (p['longitude'] as num?)?.toDouble() ?? 0;
    final vitesse = (p['vitesse'] as num?)?.toDouble() ?? 0;
    final ignition = (p['ignition'] as int?) ?? 0;
    final allumage = ignition == 1;
    final immat = p['immatriculation'] as String? ?? 'N/C';
    final date = p['dateTracking'] as String? ?? '';

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
                  color: (allumage ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  allumage ? Icons.speed : Icons.pause,
                  color: allumage ? AppTheme.success : AppTheme.warning,
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
                    Text('${vitesse.toStringAsFixed(0)} km/h',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (allumage ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(allumage ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: allumage ? AppTheme.success : AppTheme.warning,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Expanded(
                child: Text('${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.6))),
              ),
            ],
          ),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(date.length >= 16 ? date.substring(0, 16) : date,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.5))),
          ],
        ],
      ),
    );
  }
}
