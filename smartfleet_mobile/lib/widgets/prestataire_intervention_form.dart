import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_constants.dart';
import '../config/theme.dart';
import '../providers/declaration_provider.dart';

class PrestataireInterventionForm extends StatefulWidget {
  final int declarationId;
  final Map<String, dynamic> declaration;

  const PrestataireInterventionForm({
    super.key,
    required this.declarationId,
    required this.declaration,
  });

  @override
  State<PrestataireInterventionForm> createState() =>
      _PrestataireInterventionFormState();
}

class _PrestataireInterventionFormState
    extends State<PrestataireInterventionForm> {
  final _formKey = GlobalKey<FormState>();
  final _actionsCtrl = TextEditingController();
  final _piecesCtrl = TextEditingController();
  final _coutCtrl = TextEditingController();
  String? _contratBonCommande;
  String? _etatReparation;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final d = widget.declaration;
    if (d['actionsRealisees'] != null) {
      _actionsCtrl.text = d['actionsRealisees'] as String;
    }
    if (d['piecesNecessaires'] != null) {
      _piecesCtrl.text = d['piecesNecessaires'] as String;
    }
    if (d['coutReel'] != null) {
      _coutCtrl.text = (d['coutReel'] as num).toStringAsFixed(2);
    }
    _contratBonCommande = d['contratBonCommande'] as String?;
    _etatReparation = d['etat'] as String?;
  }

  @override
  void dispose() {
    _actionsCtrl.dispose();
    _piecesCtrl.dispose();
    _coutCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_contratBonCommande == null) {
      _showError('Veuillez sélectionner un type de contrat/bon de commande');
      return;
    }
    if (_etatReparation == null) {
      _showError('Veuillez sélectionner l\'état de réparation');
      return;
    }

    setState(() => _submitting = true);

    final coutReel = double.tryParse(_coutCtrl.text.trim());
    final dureeReparation = _calcDureeReparation();

    final ok = await context.read<DeclarationProvider>().submitForValidation(
          widget.declarationId,
          actionsRealisees: _actionsCtrl.text.trim(),
          piecesNecessaires: _piecesCtrl.text.trim().isEmpty
              ? null
              : _piecesCtrl.text.trim(),
          contratBonCommande: _contratBonCommande,
          coutReel: coutReel,
          dureeReparation: dureeReparation,
          etatReparation: _etatReparation,
          dateReparation: DateTime.now().toIso8601String(),
        );

    setState(() => _submitting = false);

    if (mounted) {
      if (ok) {
        Navigator.pop(context, true);
      } else {
        _showError('Erreur lors de la soumission');
      }
    }
  }

  int _calcDureeReparation() {
    final dateCreationStr = widget.declaration['dateCreation'] as String?;
    if (dateCreationStr == null) return 0;
    try {
      final dateCreation = DateTime.parse(dateCreationStr);
      return DateTime.now().difference(dateCreation).inDays;
    } catch (_) {
      return 0;
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport d\'intervention'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Déclaration #${widget.declaration['id']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Véhicule: ${widget.declaration['immatriculation'] ?? ''}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Analyse',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _actionsCtrl,
              decoration: const InputDecoration(
                labelText: 'Actions réalisées *',
                hintText: 'Décrivez les actions effectuées',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _piecesCtrl,
              decoration: const InputDecoration(
                labelText: 'Pièces nécessaires',
                hintText: 'Références des pièces utilisées (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _contratBonCommande,
              decoration: const InputDecoration(
                labelText: 'Contrat / Bon de commande *',
                border: OutlineInputBorder(),
              ),
              items: AppConstants.contratBonCommandeOptions
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                          AppConstants.contratBonCommandeLabels[c] ?? c),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _contratBonCommande = v),
            ),
            const SizedBox(height: 24),
            Text(
              'Action',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _coutCtrl,
              decoration: const InputDecoration(
                labelText: 'Coût réel *',
                hintText: 'Montant en euros',
                border: OutlineInputBorder(),
                suffixText: '€',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Champ requis';
                final val = double.tryParse(v.trim());
                if (val == null || val <= 0) return 'Montant invalide';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _etatReparation,
              decoration: const InputDecoration(
                labelText: 'État de réparation *',
                border: OutlineInputBorder(),
              ),
              items: AppConstants.etatReparationOptions
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(AppConstants.etatReparationLabels[e] ?? e),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _etatReparation = v),
            ),
            const SizedBox(height: 8),
            Text(
              'Durée de réparation: ${_calcDureeReparation()} jour(s)',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(_submitting
                    ? 'Soumission...'
                    : 'Soumettre pour validation'),
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
