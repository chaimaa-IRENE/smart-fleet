import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/app_sizes.dart';
import '../../widgets/danone_app_bar.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/premium/premium_status_badge.dart';

class ComplaintView extends StatefulWidget {
  const ComplaintView({super.key});

  @override
  State<ComplaintView> createState() => _ComplaintViewState();
}

class _ComplaintViewState extends State<ComplaintView> {
  final List<Map<String, dynamic>> _complaints = [];
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: DanoneAppBar(title: 'Réclamations'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.paddingL),
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  glowColor: AppTheme.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Réclamations',
                          style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          )),
                      const SizedBox(height: 4),
                      Text('${_complaints.length} réclamation(s)',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showCreateComplaint,
                        icon: const Icon(Icons.add),
                        label: const Text('Nouvelle réclamation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_complaints.isEmpty)
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.feedback, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          Text('Aucune réclamation',
                              style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  )
                else
                  ..._complaints.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildComplaintCard(c),
                  )),
                const SizedBox(height: 24),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateComplaint,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final desc = c['description'] as String? ?? '';
    final statut = c['status'] as String? ?? 'OUVERT';
    final date = c['dateCreation'] as String? ?? '';

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
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.feedback, color: AppTheme.danger, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(desc.length > 60 ? '${desc.substring(0, 60)}...' : desc,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    )),
              ),
              PremiumStatusBadge(
                label: statut == 'OUVERT' ? 'Ouvert' : (statut == 'TRAITE' ? 'Traité' : statut),
                status: statut,
              ),
            ],
          ),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(date.length >= 10 ? date.substring(0, 10) : date,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.6))),
          ],
        ],
      ),
    );
  }

  void _showCreateComplaint() {
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nouvelle réclamation'),
        content: TextField(
          controller: descCtrl,
          decoration: InputDecoration(
            hintText: 'Décrivez votre réclamation...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (descCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _complaints.insert(0, {
                    'description': descCtrl.text.trim(),
                    'status': 'OUVERT',
                    'dateCreation': DateTime.now().toIso8601String(),
                  });
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Réclamation envoyée'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }
}
