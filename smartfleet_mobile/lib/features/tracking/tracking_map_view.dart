import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/tracking_service.dart';
import '../../widgets/danone_app_bar.dart';
import '../../widgets/premium/glass_card.dart';

class TrackingMapView extends StatefulWidget {
  const TrackingMapView({super.key});

  @override
  State<TrackingMapView> createState() => _TrackingMapViewState();
}

class _TrackingMapViewState extends State<TrackingMapView> {
  final TrackingService _svc = TrackingService();
  List<Map<String, dynamic>> _positions = [];
  bool _loading = true;
  Map<String, dynamic>? _selected;

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final markers = _positions.where((p) {
      final lat = (p['latitude'] as num?)?.toDouble();
      final lng = (p['longitude'] as num?)?.toDouble();
      return lat != null && lng != null && lat != 0 && lng != 0;
    }).toList();

    return Scaffold(
      appBar: DanoneAppBar(
        title: 'Carte Tracking',
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: markers.isNotEmpty
                        ? LatLng(
                            (markers.first['latitude'] as num).toDouble(),
                            (markers.first['longitude'] as num).toDouble(),
                          )
                        : const LatLng(33.5731, -7.5898),
                    initialZoom: 12,
                    onTap: (_, __) => setState(() => _selected = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.smartfleet.app',
                    ),
                    MarkerLayer(
                      markers: markers.map((p) {
                        final lat = (p['latitude'] as num).toDouble();
                        final lng = (p['longitude'] as num).toDouble();
                        final immat = p['immatriculation'] as String? ?? '?';
                        final ignition = (p['ignition'] as int?) ?? 0;
                        final isOn = ignition == 1;
                        return Marker(
                          point: LatLng(lat, lng),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => setState(() => _selected = p),
                            child: Icon(
                              Icons.directions_car,
                              color: isOn ? AppTheme.success : AppTheme.warning,
                              size: 32,
                              shadows: [
                                Shadow(
                                  blurRadius: 8,
                                  color: (isOn ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                if (_selected != null)
                  Positioned(
                    left: 16, right: 16, bottom: 24,
                    child: _buildVehicleCard(_selected!),
                  ),
                if (markers.isEmpty)
                  Center(
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gps_off, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          Text('Aucune position GPS',
                              style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> p) {
    final immat = p['immatriculation'] as String? ?? 'N/C';
    final vitesse = (p['vitesse'] as num?)?.toDouble() ?? 0;
    final ignition = (p['ignition'] as int?) ?? 0;
    final lat = (p['latitude'] as num?)?.toDouble() ?? 0;
    final lng = (p['longitude'] as num?)?.toDouble() ?? 0;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(ignition == 1 ? Icons.speed : Icons.pause,
                  color: ignition == 1 ? AppTheme.success : AppTheme.warning, size: 20),
              const SizedBox(width: 8),
              Text(immat,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16,
                    color: AppTheme.textPrimary,
                  )),
              const Spacer(),
              Text('${vitesse.toStringAsFixed(0)} km/h',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: vitesse > 0 ? AppTheme.success : AppTheme.textSecondary,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Text('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (ignition == 1 ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(ignition == 1 ? 'Moteur ON' : 'Moteur OFF',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: ignition == 1 ? AppTheme.success : AppTheme.warning,
                )),
          ),
        ],
      ),
    );
  }
}
