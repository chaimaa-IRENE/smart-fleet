import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/vehicle.dart';

class VehicleSelector extends StatelessWidget {
  final List<Vehicle> vehicles;
  final String? selectedImmat;
  final ValueChanged<String> onChanged;

  const VehicleSelector({
    super.key,
    required this.vehicles,
    required this.selectedImmat,
    required this.onChanged,
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
            const Text(
              'Sélectionnez un véhicule',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: vehicles.map((v) {
                final selected = v.immatriculation == selectedImmat;
                return ChoiceChip(
                  label: Text(
                    v.immatriculation,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? Colors.white : null,
                    ),
                  ),
                  selected: selected,
                  selectedColor: AppTheme.primary,
                  backgroundColor: Colors.grey.shade100,
                  onSelected: (_) => onChanged(v.immatriculation),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
