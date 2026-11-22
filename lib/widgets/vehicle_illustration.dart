import 'package:flutter/material.dart';
import 'package:roadix_mobile/theme/app_colors.dart';

// Re-export core VehicleIllustration from brand_logo.dart for backward compatibility
export 'package:roadix_mobile/widgets/brand_logo.dart' show VehicleIllustration;

/// Enhanced Automotive Specification Badge for Vehicle Classification
class VehicleSpecBadge extends StatelessWidget {
  final String label;
  final bool isSelected;

  const VehicleSpecBadge({
    super.key,
    required this.label,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.caliperCrimson.withAlpha(22)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? AppColors.caliperCrimson.withAlpha(70)
              : AppColors.slateBorder,
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isSelected ? AppColors.caliperCrimson : AppColors.slateMuted,
          fontSize: 9.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
