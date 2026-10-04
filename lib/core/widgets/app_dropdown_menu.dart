import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../constants/app_colors.dart';

class AppDropdownItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final bool isDestructive;
  final bool isDividerAfter;

  const AppDropdownItem({
    required this.value,
    required this.label,
    this.icon,
    this.isDestructive = false,
    this.isDividerAfter = false,
  });
}

class AppDropdownMenu<T> extends StatelessWidget {
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T> onSelected;
  final Widget? triggerWidget;
  final String? tooltip;
  final Offset offset;

  const AppDropdownMenu({
    super.key,
    required this.items,
    required this.onSelected,
    this.triggerWidget,
    this.tooltip = 'Menu Opsi',
    this.offset = const Offset(0, 48),
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      offset: offset,
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.brandBorder),
      ),
      icon: triggerWidget ??
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brandBorder),
            ),
            alignment: Alignment.center,
            child: const Icon(
              TablerIcons.dots_vertical,
              size: 20,
              color: AppColors.brandEspresso,
            ),
          ),
      onSelected: onSelected,
      itemBuilder: (context) {
        final List<PopupMenuEntry<T>> entries = [];

        for (final item in items) {
          final itemColor =
              item.isDestructive ? AppColors.error : AppColors.brandEspresso;

          entries.add(
            PopupMenuItem<T>(
              value: item.value,
              height: 42,
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    Icon(
                      item.icon,
                      size: 19,
                      color: itemColor,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: itemColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          if (item.isDividerAfter) {
            entries.add(
              const PopupMenuDivider(height: 1),
            );
          }
        }

        return entries;
      },
    );
  }
}
