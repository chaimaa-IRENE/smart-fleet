import 'package:flutter/material.dart';

class DashboardTile {
  final String title;
  final IconData icon;
  final Color color;
  final String route;

  DashboardTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
  });

  static Widget grid(
    List<DashboardTile> tiles,
    BuildContext context, {
    int crossAxisCount = 2,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) {
        final t = tiles[i];
        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pushNamed(context, t.route),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t.icon, size: 36, color: t.color),
                const SizedBox(height: 8),
                Text(
                  t.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
