import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../providers/auth_provider.dart';
import '../../features/common/error_screen.dart';

class UsersCrud extends StatefulWidget {
  const UsersCrud({super.key});

  @override
  State<UsersCrud> createState() => _UsersCrudState();
}

class _UsersCrudState extends State<UsersCrud> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _roleFilter = '';
  int? _expandedId;

  static const _roleOptions = [
    'ADMIN', 'CHAUFFEUR', 'PRESTATAIRE', 'RS', 'MAINTENANCE',
    'SL', 'RPF', 'ASM', 'CPL', 'DRL', 'RFL'
  ];

  static const _roleLabels = {
    'ADMIN': 'Admin', 'CHAUFFEUR': 'Chauffeur', 'PRESTATAIRE': 'Prestataire',
    'RS': 'Responsable Support', 'MAINTENANCE': 'Maintenance',
    'SL': 'Superviseur Logistique', 'RPF': 'RPF', 'ASM': 'ASM',
    'CPL': 'Chef Parc Logistique', 'DRL': 'Dir. Régional Logistique',
    'RFL': 'Responsable Flotte',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _users = await context.read<AuthProvider>().getUsers();
      _applyFilter();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilter() {
    setState(() {
      _filtered = _users.where((u) {
        final q = _search.toLowerCase();
        if (q.isNotEmpty) {
          final nom = (u['nom'] as String? ?? '').toLowerCase();
          final email = (u['email'] as String? ?? '').toLowerCase();
          final role = (u['role'] as String? ?? '').toLowerCase();
          final prenom = (u['prenom'] as String? ?? '').toLowerCase();
          if (!nom.contains(q) && !email.contains(q) && !role.contains(q) && !prenom.contains(q)) {
            return false;
          }
        }
        if (_roleFilter.isNotEmpty && u['role'] != _roleFilter) return false;
        return true;
      }).toList();
    });
  }

  String _roleLabel(String? role) => _roleLabels[role] ?? role ?? '';

  void _showUserDialog({Map<String, dynamic>? user}) {
    final nomCtrl = TextEditingController(text: user?['nom'] ?? '');
    final prenomCtrl = TextEditingController(text: user?['prenom'] ?? '');
    final emailCtrl = TextEditingController(text: user?['email'] ?? '');
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: user?['telephone'] ?? '');
    final matriculeCtrl = TextEditingController(text: user?['matricule'] ?? '');
    final branchCtrl = TextEditingController(text: user?['branchCode'] ?? '');
    String roleSelec = user?['role'] ?? 'CHAUFFEUR';
    bool actif = user == null || user?['actif'] == 1 || user?['actif'] == true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(user != null ? 'Modifier ${user['nom']}' : 'Nouvel utilisateur'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom *'), textCapitalization: TextCapitalization.words),
              const SizedBox(height: 8),
              TextField(controller: prenomCtrl, decoration: const InputDecoration(labelText: 'Prénom'), textCapitalization: TextCapitalization.words),
              const SizedBox(height: 8),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email *'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 8),
              TextField(controller: passCtrl, decoration: InputDecoration(labelText: user != null ? 'Nouveau mot de passe (optionnel)' : 'Mot de passe *'), obscureText: true),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone'), keyboardType: TextInputType.phone),
              const SizedBox(height: 8),
              TextField(controller: matriculeCtrl, decoration: const InputDecoration(labelText: 'Matricule')),
              const SizedBox(height: 8),
              TextField(controller: branchCtrl, decoration: const InputDecoration(labelText: 'Code branche')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: roleSelec,
                decoration: const InputDecoration(labelText: 'Rôle'),
                items: _roleOptions.map((r) => DropdownMenuItem(value: r, child: Text(_roleLabel(r)))).toList(),
                onChanged: (v) => setDState(() => roleSelec = v ?? 'CHAUFFEUR'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Actif'),
                value: actif,
                onChanged: (v) => setDState(() => actif = v),
                contentPadding: EdgeInsets.zero,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(Translations.t('common.cancel'))),
            ElevatedButton(onPressed: () async {
              if (nomCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Nom et email requis')));
                return;
              }
              final authProv = context.read<AuthProvider>();
              final data = <String, dynamic>{
                'nom': nomCtrl.text.trim(),
                'prenom': prenomCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'password': passCtrl.text,
                'telephone': phoneCtrl.text.trim(),
                'role': roleSelec,
                'actif': actif ? 1 : 0,
                'matricule': matriculeCtrl.text.trim(),
                'branchCode': branchCtrl.text.trim(),
              };
              if (user != null) {
                await authProv.updateUser(user['id'] as int, data);
              } else {
                if (passCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Mot de passe requis')));
                  return;
                }
                await authProv.createUser(data);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }, child: Text(Translations.t('common.save'))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _users.length;
    final actifs = _users.where((u) => u['actif'] == 1 || u['actif'] == true).length;
    final inactifs = total - actifs;
    final chauffeurs = _users.where((u) => u['role'] == 'CHAUFFEUR').length;

    return Scaffold(
      appBar: AppBar(title: Text(Translations.t('nav.users'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorScreen(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Row(children: [
                        Expanded(child: _kpiCard('Total', '$total', Icons.people, AppTheme.primary)),
                        const SizedBox(width: 8),
                        Expanded(child: _kpiCard('Actifs', '$actifs', Icons.check_circle, AppTheme.success)),
                        const SizedBox(width: 8),
                        Expanded(child: _kpiCard('Inactifs', '$inactifs', Icons.cancel, AppTheme.danger)),
                        const SizedBox(width: 8),
                        Expanded(child: _kpiCard('Chauffeurs', '$chauffeurs', Icons.directions_car, AppTheme.accent)),
                      ]),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onChanged: (v) { _search = v; _applyFilter(); },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _filterChip('Tous', '', AppTheme.primary),
                            ..._roleOptions.map((r) => _filterChip(_roleLabel(r), r, AppTheme.accent)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_filtered.isEmpty)
                        const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Aucun utilisateur')))
                      else
                        ..._filtered.map((u) => _buildUserCard(u)),
                    ],
                  ),
                ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ]),
      ),
    );
  }

  Widget _filterChip(String label, String value, Color color) {
    final active = _roleFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: active ? Colors.white : null)),
        selected: active,
        onSelected: (_) { setState(() => _roleFilter = value); _applyFilter(); },
        selectedColor: color,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> u) {
    final id = u['id'] as int;
    final actif = u['actif'] == 1 || u['actif'] == true;
    final nom = u['nom'] as String? ?? '';
    final prenom = u['prenom'] as String? ?? '';
    final email = u['email'] as String? ?? '';
    final role = u['role'] as String? ?? '';
    final phone = u['telephone'] as String? ?? '';
    final expanded = _expandedId == id;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: actif ? AppTheme.success.withValues(alpha: 0.2) : Colors.grey.shade200,
              child: Text(
                (prenom.isNotEmpty ? prenom[0] : nom[0]).toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.bold, color: actif ? AppTheme.success : Colors.grey),
              ),
            ),
            title: Text('$prenom $nom', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('$email  •  ${_roleLabel(role)}', style: const TextStyle(fontSize: 12)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: Icon(actif ? Icons.shield : Icons.shield_outlined, size: 20, color: actif ? AppTheme.success : Colors.grey),
                onPressed: () async {
                  final authProv = context.read<AuthProvider>();
                  await authProv.updateUser(id, {'actif': actif ? 0 : 1});
                  _load();
                },
              ),
              IconButton(
                icon: Icon(Icons.edit, size: 20, color: AppTheme.primary),
                onPressed: () => _showUserDialog(user: u),
              ),
              IconButton(
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                onPressed: () => setState(() => _expandedId = expanded ? null : id),
              ),
            ]),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                _detailRow('Matricule', u['matricule'] as String? ?? '—'),
                _detailRow('Téléphone', phone.isNotEmpty ? phone : '—'),
                _detailRow('Branche', u['branchCode'] as String? ?? '—'),
                _detailRow('Créé le', u['dateCreation'] as String? ?? '—'),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text('$label: ', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
