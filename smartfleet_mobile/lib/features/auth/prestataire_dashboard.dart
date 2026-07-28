import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_sizes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/declaration_provider.dart';
import '../../widgets/prestataire_intervention_form.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/danone_app_bar.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/premium/premium_kpi_card.dart';
import '../common/error_screen.dart';
import '../../services/export_service.dart';

class PrestataireDashboard extends StatefulWidget {
  const PrestataireDashboard({super.key});

  @override
  State<PrestataireDashboard> createState() => _PrestataireDashboardState();
}

class _PrestataireDashboardState extends State<PrestataireDashboard> {
  String _searchQuery = '';
  String _statutFilter = '';
  bool _showFilters = false;
  String _moisFilter = '';
  String _categorieFilter = '';
  String _elementVehiculeFilter = '';
  String _siteFilter = '';
  String _typePanneFilter = '';
  String _slaFilter = '';
  String _coutMinFilter = '';
  String _coutMaxFilter = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeclarationProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final prov = context.watch<DeclarationProvider>();

    return Scaffold(
      appBar: DanoneAppBar(
        title: '${user?['nom'] ?? ''}',
        actions: [
          IconButton(icon: Icon(Icons.filter_list, color: _showFilters ? AppTheme.primary : null), onPressed: () => setState(() => _showFilters = !_showFilters)),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.go('/prestataire/settings')),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (context.mounted) context.go('/login');
          }),
        ],
      ),
      body: _buildBody(prov, user),
    );
  }

  Widget _buildBody(DeclarationProvider prov, Map<String, dynamic>? user) {
    if (prov.loading) return const Center(child: CircularProgressIndicator());
    if (prov.error != null) return ErrorScreen(message: prov.error!, onRetry: () => prov.loadAll());

    final declarations = prov.declarations;
    final prestataireId = user?['id'] as int?;
    final prestataireNom = user?['nom'] as String? ?? '';

    final filtered = declarations.where((d) {
      if (_statutFilter.isNotEmpty && d['statut'] != _statutFilter) return false;
      if (_moisFilter.isNotEmpty) {
        final date = d['dateCreation'] as String? ?? '';
        if (date.length >= 7 && date.substring(5, 7) != _moisFilter) return false;
      }
      if (_categorieFilter.isNotEmpty && d['categorie'] != _categorieFilter) return false;
      if (_elementVehiculeFilter.isNotEmpty) {
        final elem = (d['elementVehicule'] as String? ?? '').toLowerCase();
        if (!elem.contains(_elementVehiculeFilter.toLowerCase())) return false;
      }
      if (_siteFilter.isNotEmpty) {
        final site = (d['site'] as String? ?? '').toLowerCase();
        if (!site.contains(_siteFilter.toLowerCase())) return false;
      }
      if (_typePanneFilter.isNotEmpty) {
        final tp = (d['typePanne'] as String? ?? '').toLowerCase();
        if (!tp.contains(_typePanneFilter.toLowerCase())) return false;
      }
      if (_slaFilter.isNotEmpty) {
        final slaStr = d['sla']?.toString() ?? '';
        if (!slaStr.contains(_slaFilter)) return false;
      }
      if (_coutMinFilter.isNotEmpty) {
        final cout = double.tryParse(d['cout']?.toString() ?? '') ?? 0;
        final min = double.tryParse(_coutMinFilter) ?? 0;
        if (cout < min) return false;
      }
      if (_coutMaxFilter.isNotEmpty) {
        final cout = double.tryParse(d['cout']?.toString() ?? '') ?? 0;
        final max = double.tryParse(_coutMaxFilter) ?? double.infinity;
        if (cout > max) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final immat = (d['immatriculation'] as String? ?? '').toLowerCase();
        final type = (d['typePanne'] as String? ?? '').toLowerCase();
        final num = (d['numeroDemande'] as String? ?? '').toLowerCase();
        if (!immat.contains(q) && !type.contains(q) && !num.contains(q)) return false;
      }
      return true;
    }).toList();

    final enAttente = filtered.where((d) => d['statut'] == 'EN_ATTENTE').length;
    final enCours = filtered.where((d) => ['PRISE_EN_CHARGE', 'EN_COURS'].contains(d['statut'])).length;
    final enValidation = filtered.where((d) => d['statut'] == 'EN_VALIDATION').length;
    final traitees = filtered.where((d) => d['statut'] == 'TRAITE').length;
    final cloture = filtered.where((d) => d['statut'] == 'CLOTURE').length;
    final retournees = filtered.where((d) => d['statut'] == 'RETOURNEE').length;

    return RefreshIndicator(
      onRefresh: () => prov.loadAll(),
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        children: [
          GlassCard(padding: const EdgeInsets.all(20), glowColor: AppTheme.primary,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tableau de bord Prestataire', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text('${filtered.length} déclarations', style: TextStyle(color: AppTheme.textSecondary)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: PremiumKpiCard(title: 'Total', value: '${filtered.length}', icon: Icons.list_alt, color: AppTheme.primary)),
            const SizedBox(width: 6),
            Expanded(child: PremiumKpiCard(title: 'En attente', value: '$enAttente', icon: Icons.pending_actions, color: AppTheme.warning)),
            const SizedBox(width: 6),
            Expanded(child: PremiumKpiCard(title: 'En cours', value: '$enCours', icon: Icons.engineering, color: Colors.blue)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: PremiumKpiCard(title: 'Validation', value: '$enValidation', icon: Icons.verified, color: Colors.purple)),
            const SizedBox(width: 6),
            Expanded(child: PremiumKpiCard(title: 'Traitées', value: '$traitees', icon: Icons.check_circle, color: Colors.teal)),
            const SizedBox(width: 6),
            Expanded(child: PremiumKpiCard(title: 'Clôturées', value: '$cloture', icon: Icons.lock, color: AppTheme.success)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: PremiumKpiCard(title: 'Retournées', value: '$retournees', icon: Icons.undo, color: AppTheme.danger)),
          ]),
          if (_showFilters) ...[
            const SizedBox(height: 8),
            GlassCard(padding: const EdgeInsets.all(12), child: Column(children: [
              TextField(
                decoration: InputDecoration(hintText: 'Rechercher...', prefixIcon: const Icon(Icons.search, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                _filterChip('Tous', '', AppTheme.primary),
                _filterChip('En attente', 'EN_ATTENTE', AppTheme.warning),
                _filterChip('En cours', 'EN_COURS', Colors.blue),
                _filterChip('Validation', 'EN_VALIDATION', Colors.purple),
                _filterChip('Traitée', 'TRAITE', Colors.teal),
                _filterChip('Clôturée', 'CLOTURE', AppTheme.success),
                _filterChip('Retournée', 'RETOURNEE', AppTheme.danger),
              ])),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _moisFilter.isEmpty ? null : _moisFilter,
                  decoration: const InputDecoration(labelText: 'Mois', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tous')),
                    ...List.generate(12, (i) => DropdownMenuItem(
                      value: '${(i + 1).toString().padLeft(2, '0')}',
                      child: Text(['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'][i]),
                    )),
                  ],
                  onChanged: (v) => setState(() => _moisFilter = v ?? ''),
                )),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<String>(
                  value: _categorieFilter.isEmpty ? null : _categorieFilter,
                  decoration: const InputDecoration(labelText: 'Catégorie', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tous')),
                    const DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                    const DropdownMenuItem(value: 'Panne', child: Text('Panne')),
                    const DropdownMenuItem(value: 'Accident', child: Text('Accident')),
                    const DropdownMenuItem(value: 'Usure normale', child: Text('Usure normale')),
                    const DropdownMenuItem(value: 'Autre', child: Text('Autre')),
                  ],
                  onChanged: (v) => setState(() => _categorieFilter = v ?? ''),
                )),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: TextField(
                  decoration: const InputDecoration(labelText: 'Élément véhicule', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  onChanged: (v) => setState(() => _elementVehiculeFilter = v),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  decoration: const InputDecoration(labelText: 'Site', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  onChanged: (v) => setState(() => _siteFilter = v),
                )),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: TextField(
                  decoration: const InputDecoration(labelText: 'Type panne', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  onChanged: (v) => setState(() => _typePanneFilter = v),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  decoration: const InputDecoration(labelText: 'SLA (jours)', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() => _slaFilter = v),
                )),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: TextField(
                  decoration: const InputDecoration(labelText: 'Coût min', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() => _coutMinFilter = v),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  decoration: const InputDecoration(labelText: 'Coût max', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() => _coutMaxFilter = v),
                )),
              ]),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Réinitialiser'),
                onPressed: () => setState(() {
                  _searchQuery = '';
                  _statutFilter = '';
                  _moisFilter = '';
                  _categorieFilter = '';
                  _elementVehiculeFilter = '';
                  _siteFilter = '';
                  _typePanneFilter = '';
                  _slaFilter = '';
                  _coutMinFilter = '';
                  _coutMaxFilter = '';
                }),
              )),
            ])),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Text('Déclarations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textPrimary)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.account_tree, size: 16),
              label: const Text('Mode Stepper', style: TextStyle(fontSize: 12)),
              onPressed: _showStepper,
            ),
          ]),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            GlassCard(padding: const EdgeInsets.all(24), child: Center(child: Column(children: [
              Icon(Icons.inbox, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 8),
              Text('Aucune déclaration', style: TextStyle(color: AppTheme.textSecondary)),
            ])))
          else
            ...filtered.map((d) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildDeclarationCard(prov, d, prestataireId, prestataireNom))),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, Color color) {
    final active = _statutFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: active ? Colors.white : null)),
        selected: active,
        onSelected: (_) => setState(() => _statutFilter = active ? '' : value),
        selectedColor: color,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildDeclarationCard(DeclarationProvider prov, Map<String, dynamic> d, int? prestataireId, String prestataireNom) {
    final id = d['id'] as int? ?? 0;
    final statut = d['statut'] as String? ?? '';
    final typePanne = d['typePanne'] as String? ?? '';
    final immat = d['immatriculation'] as String? ?? '';
    final date = d['dateCreation'] as String? ?? '';
    final declPrestataireId = d['prestataireId'] as int?;
    final motifRejet = d['motifRejet'] as String?;
    final nm = d['numeroDemande'] as String? ?? '#$id';
    final canAct = statut == 'EN_ATTENTE' || (declPrestataireId != null && declPrestataireId == prestataireId);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.statusColor(statut).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(_typeIcon(typePanne), color: AppColors.statusColor(statut), size: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$immat - ${_typeLabel(typePanne)}', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textPrimary)),
          Text('$nm  •  ${date.length >= 10 ? date.substring(0, 10) : date}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ])),
        StatusBadge(status: statut),
      ]),
      if (d['criticite'] != null)
        Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
          Icon(Icons.flag, size: 14, color: d['criticite'] == 'BLOQUANT' ? AppTheme.danger : AppTheme.warning),
          const SizedBox(width: 4),
          Text(d['criticite'] as String, style: TextStyle(fontSize: 11, color: d['criticite'] == 'BLOQUANT' ? AppTheme.danger : AppTheme.warning)),
          if (d['kilometrage'] != null) ...[
            const SizedBox(width: 12),
            Icon(Icons.speed, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text('${d['kilometrage']} km', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
          if (d['lieu'] != null) ...[
            const SizedBox(width: 12),
            Icon(Icons.location_on, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text('${d['lieu']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ])),
      if (d['description'] != null && (d['description'] as String).isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(
          d['description'] as String,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        )),
      if (d['dateReparation'] != null)
        Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
          Icon(Icons.calendar_today, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text('Réparation: ${d['dateReparation']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ])),
      if (d['dureeReparation'] != null)
        Padding(padding: const EdgeInsets.only(top: 2), child: Row(children: [
          Icon(Icons.timer, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text('Durée: ${d['dureeReparation']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ])),
      if (d['etat'] != null)
        Padding(padding: const EdgeInsets.only(top: 2), child: Row(children: [
          Icon(Icons.info_outline, size: 12, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text('État: ${d['etat']}', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500)),
        ])),
      if (d['cout'] != null)
        Padding(padding: const EdgeInsets.only(top: 2), child: Row(children: [
          Icon(Icons.attach_money, size: 12, color: AppTheme.success),
          const SizedBox(width: 4),
          Text('Coût: ${d['cout']} MAD', style: const TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w500)),
        ])),
      if (statut == 'CLOTURE' || statut == 'RETOURNEE')
        Padding(padding: const EdgeInsets.only(top: 4), child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statut == 'CLOTURE' ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.danger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            statut == 'CLOTURE' ? 'Clôturée' : 'Retournée',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statut == 'CLOTURE' ? AppTheme.success : AppTheme.danger),
          ),
        )),
      if (motifRejet != null && motifRejet.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [Icon(Icons.info, size: 16, color: AppTheme.danger), const SizedBox(width: 6), Text('Motif: $motifRejet', style: const TextStyle(fontSize: 13, color: AppTheme.danger))])),
      ],
      if (canAct) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: _buildActions(prov, d, id, statut, prestataireId, prestataireNom)),
      ],
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton.icon(
          icon: const Icon(Icons.visibility, size: 16),
          label: const Text('Détails', style: TextStyle(fontSize: 12)),
          onPressed: () => _showDetailsModal(d),
        ),
        TextButton.icon(
          icon: Icon(Icons.picture_as_pdf, size: 16, color: AppTheme.primary),
          label: Text('PDF', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
          onPressed: () async {
            final svc = ExportService();
            await svc.exportPdfIntervention(id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rapport généré: ${d['numeroDemande'] ?? id}')));
            }
          },
        ),
      ]),
    ]));
  }

  void _showDetailsModal(Map<String, dynamic> d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Déclaration ${d['numeroDemande'] ?? d['id']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _detailSection('Informations générales', [
              _detailRow('N° Demande', d['numeroDemande'] ?? '-'),
              _detailRow('Date', d['dateCreation'] as String? ?? '-'),
              _detailRow('Statut', d['statut'] as String? ?? '-'),
              _detailRow('Source', d['source'] as String? ?? '-'),
            ]),
            _detailSection('Chauffeur & Véhicule', [
              _detailRow('Immatriculation', d['immatriculation'] as String? ?? '-'),
              _detailRow('Chauffeur', d['chauffeurNom'] as String? ?? '-'),
              _detailRow('Kilométrage', d['kilometrage']?.toString() ?? '-'),
              _detailRow('Lieu', d['lieu'] as String? ?? '-'),
            ]),
            _detailSection('Incident', [
              _detailRow('Type panne', d['typePanne'] as String? ?? '-'),
              _detailRow('Élément', d['elementVehicule'] as String? ?? '-'),
              _detailRow('Criticité', d['criticite'] as String? ?? '-'),
              _detailRow('Description', d['description'] as String? ?? '-'),
            ]),
            if (d['actionsRealisees'] != null)
              _detailSection('Rapport d\'intervention', [
                _detailRow('Actions', d['actionsRealisees'] as String? ?? '-'),
                _detailRow('Pièces', d['piecesNecessaires'] as String? ?? '-'),
                if (d['dateDebutIntervention'] != null) _detailRow('Début intervention', d['dateDebutIntervention'] as String? ?? '-'),
                if (d['qualification'] != null) _detailRow('Qualification', d['qualification'] as String? ?? '-'),
                _detailRow('Contrat/BC', d['contratBonCommande'] as String? ?? '-'),
                _detailRow('État', d['etat'] as String? ?? '-'),
              ]),
            if (d['photo'] != null || d['photoUrl'] != null)
              _detailSection('Photo', [
                _detailRow('Fichier', d['photo'] as String? ?? d['photoUrl'] as String? ?? '-'),
              ]),
            if (d['video'] != null || d['videoUrl'] != null)
              _detailSection('Vidéo', [
                _detailRow('Fichier', d['video'] as String? ?? d['videoUrl'] as String? ?? '-'),
              ]),
            if (d['motifRetour'] != null && (d['motifRetour'] as String).isNotEmpty)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.info, size: 18, color: AppTheme.danger),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Motif de retour: ${d['motifRetour']}', style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w500))),
                ]),
              )),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
        const SizedBox(height: 6),
        ...rows,
      ]),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text('$label:', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  List<Widget> _buildActions(DeclarationProvider prov, Map<String, dynamic> d, int id, String statut, int? prestataireId, String prestataireNom) {
    switch (statut) {
      case 'EN_ATTENTE':
        return [_actionBtn('Prendre en charge', Icons.pan_tool, AppTheme.primary, () => prov.takeCharge(id, prestataireId!, prestataireNom))];
      case 'PRISE_EN_CHARGE':
        return [_actionBtn('Commencer', Icons.play_arrow, AppTheme.success, () => prov.markAsInProgress(id))];
      case 'EN_COURS':
        return [_actionBtn('Rapport', Icons.edit_note, AppTheme.primary, () => _openInterventionForm(id, d))];
      case 'EN_VALIDATION':
        return [
          _actionBtn('Valider', Icons.check, AppTheme.success, () => prov.markAsProcessed(id)),
          _outlineBtn('Retourner', Icons.undo, () => _showReturnDialog(prov, id)),
        ];
      case 'TRAITE':
        return [_actionBtn('Clôturer', Icons.lock, AppTheme.primary, () => _showCloseDialog(prov, id))];
      default:
        return [];
    }
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16), label: Text(label, style: const TextStyle(fontSize: 13)),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
    );
  }

  Widget _outlineBtn(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16), label: Text(label, style: const TextStyle(fontSize: 13)),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.warning, side: BorderSide(color: AppTheme.warning.withValues(alpha: 0.4)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    );
  }

  Future<void> _openInterventionForm(int id, Map<String, dynamic> d) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: context.read<DeclarationProvider>(), child: PrestataireInterventionForm(declarationId: id, declaration: d))));
    if (mounted) context.read<DeclarationProvider>().loadAll();
  }

  Future<void> _showReturnDialog(DeclarationProvider prov, int id) async {
    final motifController = TextEditingController();
    final result = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Retourner la déclaration'),
      content: TextField(controller: motifController, decoration: InputDecoration(labelText: 'Motif du retour', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), maxLines: 3),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), ElevatedButton(onPressed: () { if (motifController.text.trim().isNotEmpty) Navigator.pop(ctx, true); }, child: const Text('Retourner'))],
    ));
    if (result == true) await prov.returnDeclaration(id, motifController.text.trim());
  }

  Future<void> _showCloseDialog(DeclarationProvider prov, int id) async {
    final coutController = TextEditingController();
    final result = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Clôturer la déclaration'),
      content: TextField(controller: coutController, decoration: InputDecoration(labelText: 'Coût réel (optionnel)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixText: '€'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clôturer'))],
    ));
    if (result == true) {
      final coutReel = coutController.text.trim().isNotEmpty ? double.tryParse(coutController.text.trim()) : null;
      await prov.close(id, coutReel: coutReel);
    }
  }

  void _showStepper() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Processus en 3 étapes'),
        content: SizedBox(
          width: double.maxFinite,
          child: Stepper(
            controlsBuilder: (_, __) => const SizedBox.shrink(),
            steps: const [
              Step(
                title: Text('Réception'),
                subtitle: Text('Réception et prise en charge de la déclaration'),
                content: Text('Le prestataire reçoit la déclaration et la prend en charge pour débuter l\'intervention.'),
                isActive: true,
              ),
              Step(
                title: Text('Analyse'),
                subtitle: Text('Diagnostic et rapport d\'intervention'),
                content: Text('Le prestataire analyse le problème, réalise l\'intervention et soumet son rapport pour validation.'),
                isActive: true,
              ),
              Step(
                title: Text('Action'),
                subtitle: Text('Validation, clôture ou retour'),
                content: Text('L\'administrateur valide l\'intervention, clôture la déclaration ou la retourne pour corrections si nécessaire.'),
                isActive: true,
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) { case 'MECANIQUE': return Icons.settings; case 'ELECTRIQUE': return Icons.bolt; case 'CAISSE': return Icons.inventory_2; case 'CABINE': return Icons.airline_seat_recline_normal; case 'SECURITE': return Icons.security; default: return Icons.build; }
  }

  String _typeLabel(String type) {
    switch (type) { case 'MECANIQUE': return 'Mécanique'; case 'ELECTRIQUE': return 'Électrique'; case 'CAISSE': return 'Caisse'; case 'CABINE': return 'Cabine'; case 'SECURITE': return 'Sécurité'; default: return 'Autres'; }
  }
}
