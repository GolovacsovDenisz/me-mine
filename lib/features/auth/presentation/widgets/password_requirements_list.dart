import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/password_requirement.dart';
import '../../domain/value_objects/password_policy.dart';

/// Live checklist: green when met, red when not (read-only).
class PasswordRequirementsList extends StatelessWidget {
  const PasswordRequirementsList({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final items = PasswordPolicy.requirements(password);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final item in items) _RequirementRow(item: item)],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.item});

  final PasswordRequirement item;

  @override
  Widget build(BuildContext context) {
    final met = item.met;
    final color = met ? AppColors.success : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: met,
              onChanged: null,
              activeColor: AppColors.success,
              checkColor: Colors.white,
              side: BorderSide(color: color, width: 1.5),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                item.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
