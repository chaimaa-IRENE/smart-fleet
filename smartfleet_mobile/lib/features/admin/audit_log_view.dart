import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/audit_service.dart';

class AuditLogView extends StatefulWidget {
  const AuditLogView({super.key});

  @override
  State<AuditLogView> createState() => _AuditLogViewState();
}

class _AuditLogViewState extends State<AuditLogView> {
  final AuditLogService _svc = AuditLogService();
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _logs = await _svc.getAll(limit: 200);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal d\'audit')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _logs.isEmpty
                  ? const Center(child: Text('Aucune entrée'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _logs.length,
                      itemBuilder: (_, i) {
                        final l = _logs[i];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              _actionIcon(l['action'] as String? ?? ''),
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            title: Text(
                              l['action'] as String? ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14,),
                            ),
                            subtitle: Text(
                              '${l['entite'] ?? ''} #${l['entiteId'] ?? ''} • ${l['details'] ?? ''}\n${l['dateAction'] ?? ''}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  IconData _actionIcon(String action) {
    if (action.contains('CREATE')) return Icons.add_circle;
    if (action.contains('UPDATE') ||
        action.contains('DEMARRER') ||
        action.contains('TERMINER')) {
      return Icons.edit;
    }
    if (action.contains('DELETE')) return Icons.delete;
    if (action.contains('VERIFY') || action.contains('VERIFICATION')) {
      return Icons.verified;
    }
    if (action.contains('ASSIGN')) return Icons.person_add;
    if (action.contains('RESOLVE')) return Icons.check_circle;
    return Icons.history;
  }
}
