import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../config/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/declaration_provider.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/danone_app_bar.dart';
import '../common/error_screen.dart';

class DeclarationsList extends StatefulWidget {
  const DeclarationsList({super.key});

  @override
  State<DeclarationsList> createState() => _DeclarationsListState();
}

class _DeclarationsListState extends State<DeclarationsList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().userId;
      if (userId != null) {
        context.read<DeclarationProvider>().loadMine(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DeclarationProvider>();

    return Scaffold(
      appBar: DanoneAppBar(title: Translations.t('nav.declarations')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chauffeur/declarations/create'),
        child: const Icon(Icons.add),
      ),
      body: _buildBody(prov),
    );
  }

  Widget _buildBody(DeclarationProvider prov) {
    if (prov.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (prov.error != null) {
      return ErrorScreen(
        message: prov.error!,
        onRetry: () {
          final userId = context.read<AuthProvider>().userId;
          if (userId != null) prov.loadMine(userId);
        },
      );
    }
    if (prov.declarations.isEmpty) {
      return const Center(child: Text('Aucune déclaration'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        final userId = context.read<AuthProvider>().userId;
        if (userId != null) await prov.loadMine(userId);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: prov.declarations.length,
        itemBuilder: (_, i) {
          final d = prov.declarations[i];
          final statut = d['statut'] as String? ?? '';
          final typePanne = d['typePanne'] as String? ?? '';
          final immat = d['immatriculation'] as String? ?? '';
          final date = d['dateCreation'] as String? ?? '';
          final priorite = d['criticite'] as String? ?? d['priorite'] as String? ?? '';

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    AppTheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  _typeIcon(typePanne),
                  color: AppTheme.primary,
                ),
              ),
              title: Text('$immat — ${_typeLabel(typePanne)}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${date.length >= 10 ? date.substring(0, 10) : date}'),
                  if (priorite.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.flag, size: 14, color: priorite == 'BLOQUANT' ? AppTheme.danger : AppTheme.warning),
                        const SizedBox(width: 4),
                        Text(AppConstants.declarationCriticiteLabels[priorite] ?? priorite,
                            style: TextStyle(fontSize: 12, color: priorite == 'BLOQUANT' ? AppTheme.danger : AppTheme.warning)),
                      ],
                    ),
                ],
              ),
              trailing: StatusBadge(status: statut),
              onTap: () => context.push('/chauffeur/declarations/${d['id']}'),
              isThreeLine: priorite.isNotEmpty,
            ),
          );
        },
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'MECANIQUE': return Icons.settings;
      case 'ELECTRIQUE': return Icons.bolt;
      case 'CAISSE': return Icons.inventory_2;
      case 'CABINE': return Icons.airline_seat_recline_normal;
      case 'SECURITE': return Icons.security;
      default: return Icons.build;
    }
  }

  String _typeLabel(String type) {
    return AppConstants.typePanneLabels[type] ?? type;
  }
}
