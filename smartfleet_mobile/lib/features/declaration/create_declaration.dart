import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../config/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/declaration_provider.dart';
import '../../services/vehicle_service.dart';

class CreateDeclaration extends StatefulWidget {
  const CreateDeclaration({super.key});

  @override
  State<CreateDeclaration> createState() => _CreateDeclarationState();
}

class _CreateDeclarationState extends State<CreateDeclaration> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _lieuCtrl = TextEditingController();
  final _vehicleSvc = VehicleService();
  List<Map<String, dynamic>> _vehicules = [];

  int _step = 0;
  bool _saving = false;
  bool _capturingGps = false;

  String? _selectedImmat;
  int? _selectedVehiculeId;
  String _typePanne = 'MECANIQUE';
  String _criticite = 'NON_BLOQUANT';
  String _source = 'MANUEL';
  String _elementVehicule = 'MECANIQUE';
  String? _detailElement;
  String? _categorie;

  File? _photo;
  File? _video;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadVehicules();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _kmCtrl.dispose();
    _lieuCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVehicules() async {
    final v = await _vehicleSvc.getAll();
    if (mounted) setState(() => _vehicules = v);
  }

  Future<void> _capturePosition() async {
    setState(() => _capturingGps = true);
    try {
      final status = await Geolocator.requestPermission();
      if (status == LocationPermission.denied || status == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission de localisation refusée'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
        setState(() => _capturingGps = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      String adresse = '';
      try {
        final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&accept-language=fr';
        final resp = await http.get(Uri.parse(url), headers: {'User-Agent': 'SmartFleetMobile/1.0'});
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          adresse = data['display_name'] as String? ?? '';
          final city = data['address']?['city'] ?? data['address']?['town'] ?? data['address']?['village'] ?? '';
          if (city.toString().isNotEmpty && _lieuCtrl.text.isEmpty) {
            _lieuCtrl.text = city.toString();
          }
        }
      } catch (_) {}
      if (mounted) {
        setState(() { _latitude = pos.latitude; _longitude = pos.longitude; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(adresse.isNotEmpty ? adresse.split(',').take(3).join(',') : 'Position capturée'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur GPS: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
    if (mounted) setState(() => _capturingGps = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
    );
  }

  Future<void> _pickMedia(String type) async {
    final picker = ImagePicker();
    final source = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'photo' ? 'Ajouter photo' : 'Ajouter vidéo'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'camera'), child: const Text('Appareil photo')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'gallery'), child: const Text('Galerie')),
        ],
      ),
    );
    if (source == null || !mounted) return;
    try {
      if (type == 'photo') {
        final picked = source == 'camera'
            ? await picker.pickImage(source: ImageSource.camera)
            : await picker.pickImage(source: ImageSource.gallery);
        if (picked != null && mounted) setState(() => _photo = File(picked.path));
      } else {
        final picked = source == 'camera'
            ? await picker.pickVideo(source: ImageSource.camera)
            : await picker.pickVideo(source: ImageSource.gallery);
        if (picked != null && mounted) setState(() => _video = File(picked.path));
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if ((_selectedImmat ?? '').isEmpty || _selectedVehiculeId == null) {
      _showError('Véhicule non sélectionné');
      return;
    }

    setState(() => _saving = true);

    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    debugPrint('=== SUBMIT: userId=$userId, immat=$_selectedImmat, vehiculeId=$_selectedVehiculeId');

    final userName = auth.user?['nom'] as String? ?? '';
    final int? km = int.tryParse(_kmCtrl.text);
    final v = _vehicules.where((v) => v['id'] == _selectedVehiculeId).firstOrNull;

    final body = <String, dynamic>{
      'typePanne': _typePanne,
      'description': _descCtrl.text,
      'immatriculation': _selectedImmat ?? '',
      'chauffeurId': userId,
      'chauffeurNom': userName,
      'source': _source,
      'criticite': _criticite,
      'elementVehicule': _elementVehicule,
      if (_detailElement != null) 'detailElement': _detailElement,
      if (_categorie != null) 'categorie': _categorie,
      if (v != null) 'vehiculeId': v['id'],
      if (v != null) 'vehiculeMarque': v['marque'],
      if (v != null) 'vehiculeModele': v['modele'],
      if (v != null) 'vehiculeType': v['type'],
      if (km != null) 'kilometrage': km,
      if (_latitude != null) 'latitude': _latitude,
      if (_longitude != null) 'longitude': _longitude,
      if (_lieuCtrl.text.isNotEmpty) 'lieu': _lieuCtrl.text,
      if (_photo != null) 'withPhoto': 1,
      if (_video != null) 'withVideo': 1,
    };

    debugPrint('=== SUBMIT: body=$body');
    final result = await context.read<DeclarationProvider>().create(body);
    debugPrint('=== SUBMIT: result=$result error=${context.read<DeclarationProvider>().error}');

    setState(() => _saving = false);

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Déclaration créée'), backgroundColor: AppTheme.success),
      );
      context.pop();
    } else if (mounted) {
      _showError(context.read<DeclarationProvider>().error ?? 'Erreur lors de la création');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Étape ${_step + 1}/3 - ${_stepTitle()}')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildStepper(),
            Expanded(child: _buildStepContent()),
            _buildNavigation(),
          ],
        ),
      ),
    );
  }

  String _stepTitle() {
    switch (_step) {
      case 0: return 'Localisation';
      case 1: return 'Véhicule';
      case 2: return 'Détails incident';
      default: return '';
    }
  }

  Widget _buildStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.primary.withValues(alpha: 0.05),
      child: Row(
          children: List.generate(3, (i) {
            final active = i == _step;
            final done = i < _step;
            return Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: done ? AppTheme.success : active ? AppTheme.primary : Colors.grey.shade300,
                    child: done
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text('${i + 1}', style: TextStyle(fontSize: 12, color: active ? Colors.white : Colors.grey)),
                  ),
                  if (i < 2) Expanded(child: Container(height: 2, color: done ? AppTheme.success : Colors.grey.shade300)),
                ],
              ),
            );
          }),
        ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0: return _stepLocalisation();
      case 1: return _stepVehicule();
      case 2: return _stepDetails();
      default: return const SizedBox();
    }
  }

  Widget _stepLocalisation() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Position du véhicule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _capturingGps ? null : _capturePosition,
                icon: _capturingGps
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.location_on),
                label: Text(_latitude != null ? 'GPS: ${_latitude!.toStringAsFixed(4)}' : 'GPS automatique'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _lieuCtrl,
          decoration: const InputDecoration(
            labelText: 'Lieu (ville)',
            prefixIcon: Icon(Icons.location_city),
          ),
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }

  Widget _stepVehicule() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Sélection du véhicule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: _selectedVehiculeId,
          decoration: const InputDecoration(
            labelText: 'Véhicule',
            prefixIcon: Icon(Icons.directions_car),
          ),
          items: _vehicules.map((v) {
            final label = '${v['immatriculation']} - ${v['marque'] ?? ''} ${v['modele'] ?? ''}';
            return DropdownMenuItem(value: v['id'] as int, child: Text(label));
          }).toList(),
          onChanged: (v) {
            final veh = _vehicules.where((x) => x['id'] == v).firstOrNull;
            setState(() { _selectedVehiculeId = v; _selectedImmat = veh?['immatriculation'] as String?; });
          },
          validator: (v) => v == null ? 'Requis' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _kmCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Kilométrage',
            prefixIcon: Icon(Icons.speed),
          ),
        ),
      ],
    );
  }

  Widget _stepDetails() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Détails de l\'incident', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _typePanne,
          decoration: const InputDecoration(labelText: 'Type de panne', prefixIcon: Icon(Icons.build)),
          items: AppConstants.typePannes.map((t) =>
            DropdownMenuItem(value: t, child: Text(AppConstants.typePanneLabels[t] ?? t))
          ).toList(),
          onChanged: (v) => setState(() => _typePanne = v ?? 'AUTRES'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _criticite,
          decoration: const InputDecoration(labelText: 'Criticité', prefixIcon: Icon(Icons.warning)),
          items: AppConstants.declarationCriticites.map((c) =>
            DropdownMenuItem(value: c, child: Text(AppConstants.declarationCriticiteLabels[c] ?? c))
          ).toList(),
          onChanged: (v) => setState(() => _criticite = v ?? 'NON_BLOQUANT'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description)),
          validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _source,
          decoration: const InputDecoration(labelText: 'Source', prefixIcon: Icon(Icons.source)),
          items: AppConstants.sourcesDeclaration.map((s) =>
            DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ')))
          ).toList(),
          onChanged: (v) => setState(() => _source = v ?? 'MANUEL'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _elementVehicule,
          decoration: const InputDecoration(labelText: 'Élément véhicule', prefixIcon: Icon(Icons.precision_manufacturing)),
          items: AppConstants.elementVehicules.map((e) =>
            DropdownMenuItem(value: e, child: Text(AppConstants.elementVehiculeLabels[e] ?? e))
          ).toList(),
          onChanged: (v) => setState(() => _elementVehicule = v ?? 'MECANIQUE'),
        ),
        if (_elementVehicule == 'MECANIQUE' || _elementVehicule == 'CAISSE') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _detailElement,
            decoration: const InputDecoration(labelText: 'Détail élément', prefixIcon: Icon(Icons.tune)),
            items: AppConstants.detailElements.map((d) =>
              DropdownMenuItem(value: d, child: Text(AppConstants.detailElementLabels[d] ?? d))
            ).toList(),
            onChanged: (v) => setState(() => _detailElement = v),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _categorie,
          decoration: const InputDecoration(labelText: 'Catégorie', prefixIcon: Icon(Icons.category)),
          items: AppConstants.categoriesDecla.map((c) =>
            DropdownMenuItem(value: c, child: Text(AppConstants.categorieDeclaLabels[c] ?? c))
          ).toList(),
          onChanged: (v) => setState(() => _categorie = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickMedia('photo'),
                icon: const Icon(Icons.camera_alt),
                label: Text(_photo != null ? 'Photo ✓' : 'Photo'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickMedia('video'),
                icon: const Icon(Icons.videocam),
                label: Text(_video != null ? 'Vidéo ✓' : 'Vidéo'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2)),
      ]),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                child: const Text('Précédent'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _step < 2
                  ? () {
                      if (_step == 1 && _selectedVehiculeId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sélectionnez un véhicule'), backgroundColor: AppTheme.danger),
                        );
                        return;
                      }
                      setState(() => _step++);
                    }
                  : _saving ? null : _submit,
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_step < 2 ? 'Suivant' : 'Créer'),
            ),
          ),
        ],
      ),
    );
  }
}
