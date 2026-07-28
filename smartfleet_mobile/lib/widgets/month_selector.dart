import 'package:flutter/material.dart';
import '../config/theme.dart';

class MonthSelector extends StatelessWidget {
  final List<String> months;
  final String? selectedMonth;
  final ValueChanged<String> onChanged;
  final String label;

  const MonthSelector({
    super.key,
    required this.months,
    required this.selectedMonth,
    required this.onChanged,
    this.label = 'Mois',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: months.map((m) {
                final selected = m == selectedMonth;
                return ChoiceChip(
                  label: Text(
                    _formatMonth(m),
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : null,
                    ),
                  ),
                  selected: selected,
                  selectedColor: AppTheme.primary,
                  backgroundColor: Colors.grey.shade100,
                  onSelected: (_) => onChanged(m),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMonth(String m) {
    if (m.length >= 7) {
      final parts = m.split('-');
      if (parts.length >= 2) {
        const months = [
          'Jan',
          'Fév',
          'Mar',
          'Avr',
          'Mai',
          'Juin',
          'Juil',
          'Aoû',
          'Sep',
          'Oct',
          'Nov',
          'Déc',
        ];
        final idx = int.tryParse(parts[1]) ?? 0;
        if (idx >= 1 && idx <= 12) {
          return '${months[idx - 1]} ${parts[0]}';
        }
      }
    }
    return m;
  }
}
