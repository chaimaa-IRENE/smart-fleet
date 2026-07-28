import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_constants.dart';
import '../../providers/declaration_provider.dart';
import '../../widgets/status_badge.dart';
import '../declaration/declaration_detail.dart';

class RsDeclarations extends StatefulWidget {
  const RsDeclarations({super.key});

  @override
  State<RsDeclarations> createState() => _RsDeclarationsState();
}

class _RsDeclarationsState extends State<RsDeclarations> {
  String _filter = 'EN_VALIDATION';
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeclarationProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DeclarationProvider>();
    final all = prov.declarations;

    List<Map<String, dynamic>> filtered;
    if (_filter == 'TOUT') {
      filtered = all;
    } else {
      filtered = all.where((d) => d['statut'] == _filter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toUpperCase();
      filtered = filtered
          .where((d) =>
              ((d['immatriculation'] as String?) ?? '').toUpperCase().contains(q) ||
              ((d['numeroDemande'] as String?) ?? '').contains(q) ||
              ((d['chauffeurNom'] as String?) ?? '').toUpperCase().contains(q))
          .toList();
    }
    filtered.sort((a, b) => ((b['dateCreation'] as String?) ?? '').compareTo((a['dateCreation'] as String?) ?? ''));

    return Scaffold(
      appBar: AppBar(title: const Text('Validation déclarations')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher (immat, N°, chauffeur)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _filterChip('TOUT', 'Toutes'),
                _filterChip('EN_VALIDATION', 'En validation'),
                _filterChip('TRAITE', 'Traitées'),
                _filterChip('RETOURNEE', 'Retournées'),
                _filterChip('REJETEE', 'Rejetées'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: prov.loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('Aucune déclaration'))
                    : RefreshIndicator(
                        onRefresh: () => prov.loadAll(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) =>
                              _buildCard(prov, filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _buildCard(DeclarationProvider prov, Map<String, dynamic> d) {
    final id = d['id'] as int? ?? 0;
    final statut = d['statut'] as String? ?? '';
    final immat = d['immatriculation'] as String? ?? '';
    final date = d['dateCreation'] as String? ?? '';
    final typeLabel =
        AppConstants.typePanneLabels[d['typePanne']] ?? '${d['typePanne'] ?? ''}';
    final chauffeur = d['chauffeurNom'] as String? ?? '';
    final coutReel = (d['coutReel'] as num?)?.toDouble();
    final motif = d['motifRejet'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: prov,
                    child: DeclarationDetail(id: id),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$immat - $typeLabel',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '${date.length >= 10 ? date.substring(0, 10) : date}  •  $chauffeur',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        if (coutReel != null)
                          Text(
                            'Coût: ${coutReel.toStringAsFixed(0)} €',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primary),
                          ),
                      ],
                    ),
                  ),
                  StatusBadge(status: statut),
                ],
              ),
            ),
            if (motif != null && motif.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Motif: $motif',
                  style: const TextStyle(fontSize: 13, color: AppTheme.danger)),
            ],
            if (statut == 'EN_VALIDATION') ...[
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Valider'),
                      onPressed: () => _validate(prov, id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Retourner'),
                      onPressed: () => _returnDialog(prov, id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Rejeter'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                      onPressed: () => _rejectDialog(prov, id),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _validate(DeclarationProvider prov, int id) async {
    final ok = await prov.markAsProcessed(id);
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Déclaration traitée')),
      );
    }
  }

  Future<void> _returnDialog(DeclarationProvider prov, int id) async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retourner la déclaration'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Motif du retour',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('Retourner'),
          ),
        ],
      ),
    );
    if (result == true) {
      await prov.returnDeclaration(id, ctrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Déclaration retournée')),
        );
      }
    }
  }

  Future<void> _rejectDialog(DeclarationProvider prov, int id) async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeter la déclaration'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Motif du rejet',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    if (result == true) {
      await prov.reject(id, ctrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Déclaration rejetée')),
        );
      }
    }
  }
}
