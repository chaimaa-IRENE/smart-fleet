import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_constants.dart';
import '../../providers/declaration_provider.dart';
import '../../widgets/status_badge.dart';

class DeclarationDetail extends StatefulWidget {
  final int id;
  const DeclarationDetail({super.key, required this.id});

  @override
  State<DeclarationDetail> createState() => _DeclarationDetailState();
}

class _DeclarationDetailState extends State<DeclarationDetail> {
  Map<String, dynamic>? _dec;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final prov = context.read<DeclarationProvider>();
    _dec = prov.declarations.where((d) => d['id'] == widget.id).firstOrNull;
    if (_dec == null) {
      prov.loadAll().then((_) {
        if (mounted) setState(() {
          _dec = prov.declarations.where((d) => d['id'] == widget.id).firstOrNull;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dec == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détail déclaration')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final d = _dec!;
    return Scaffold(
      appBar: AppBar(title: const Text('Déclaration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(d),
          const SizedBox(height: 16),
          _section('N° demande', '${d['numeroDemande'] ?? '—'}'),
          _section('Description', '${d['description'] ?? '—'}'),
          _section('Type de panne', AppConstants.typePanneLabels[d['typePanne']] ?? '${d['typePanne']}'),
          _section('Immatriculation', '${d['immatriculation'] ?? '—'}'),
          if (d['vehiculeMarque'] != null || d['vehiculeModele'] != null)
            _section('Véhicule', '${d['vehiculeMarque'] ?? ''} ${d['vehiculeModele'] ?? ''}'),
          _section('Criticité', AppConstants.declarationCriticiteLabels[d['criticite']] ?? '${d['criticite'] ?? '—'}'),
          _section('Source', '${d['source'] ?? 'MANUEL'}'),
          _section('Chauffeur', '${d['chauffeurNom'] ?? '—'}'),
          if (d['elementVehicule'] != null) _section('Élément', _elemLabel(d['elementVehicule'] as String)),
          if (d['detailElement'] != null) _section('Détail', _detailLabel(d['detailElement'] as String)),
          if (d['categorie'] != null) _section('Catégorie', _catLabel(d['categorie'] as String)),
          // Coût non affiché
          if (d['kilometrage'] != null) _section('Kilométrage', '${d['kilometrage']} km'),
          if (d['lieu'] != null || d['latitude'] != null)
            _section('Lieu', d['lieu'] ?? '${(d['latitude'] as num?)?.toStringAsFixed(4) ?? ''} ${(d['longitude'] as num?)?.toStringAsFixed(4) ?? ''}'),
          if (d['solution'] != null) _section('Solution', '${d['solution']}'),
          if (d['motifRejet'] != null) _section('Motif', '${d['motifRejet']}'),
          if (d['prestataireNom'] != null) _section('Prestataire', '${d['prestataireNom']}'),
          if (d['actionsRealisees'] != null) _section('Actions', '${d['actionsRealisees']}'),
          if (d['piecesNecessaires'] != null) _section('Pièces', '${d['piecesNecessaires']}'),
          if (d['contratBonCommande'] != null) _section('Contrat/BC', AppConstants.contratBonCommandeLabels[d['contratBonCommande'] as String] ?? '${d['contratBonCommande']}'),
          if (d['etat'] != null) _section('État réparation', AppConstants.etatReparationLabels[d['etat'] as String] ?? '${d['etat']}'),
          if (d['dureeReparation'] != null) _section('Durée réparation', '${d['dureeReparation']} jour(s)'),
          _section('Date création', '${d['dateCreation'] ?? '—'}'),
          if (d['dateCloture'] != null) _section('Date clôture', '${d['dateCloture']}'),
          if (d['dateReparation'] != null) _section('Date réparation', '${d['dateReparation']}'),
          if (d['withPhoto'] == 1) _section('Photo', 'Oui'),
          if (d['withVideo'] == 1) _section('Vidéo', 'Oui'),
        ],
      ),
    );
  }

  Widget _header(Map<String, dynamic> d) {
    final type = d['typePanne'] as String? ?? '';
    final immat = d['immatriculation'] as String? ?? '';
    final statut = d['statut'] as String? ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: Icon(_typeIcon(type), size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 12),
            Text(immat, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StatusBadge(status: statut),
          ],
        ),
      ),
    );
  }

  Widget _section(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  String _elemLabel(String v) => AppConstants.elementVehiculeLabels[v] ?? v;
  String _detailLabel(String v) => AppConstants.detailElementLabels[v] ?? v;
  String _catLabel(String v) => AppConstants.categorieDeclaLabels[v] ?? v;

  IconData _typeIcon(String type) {
    switch (type) {
      case 'MECANIQUE': return Icons.settings;
      case 'ELECTRIQUE': return Icons.bolt;
      case 'CAISSE': return Icons.inventory_2;
      case 'CABINE': return Icons.airline_seat_recline_normal;
      case 'SECURITE': return Icons.verified_user;
      default: return Icons.build;
    }
  }
}
