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

/// Core widget dropdown / action menu berbasis komponen Material 3 Menus ([MenuAnchor] & [MenuItemButton]).
class AppDropdownMenu<T> extends StatelessWidget {
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T> onSelected;
  final Widget? triggerWidget;
  final String? tooltip;
  final Offset? offset;
  final EdgeInsetsGeometry padding;
  final double menuWidth;
  final bool alignRight;

  const AppDropdownMenu({
    super.key,
    required this.items,
    required this.onSelected,
    this.triggerWidget,
    this.tooltip = 'Menu Opsi',
    this.offset,
    this.padding = EdgeInsets.zero,
    this.menuWidth = 180,
    this.alignRight = true,
  });

  @override
  Widget build(BuildContext context) {
    // Jika alignRight aktif, geser menu ke kiri sejajar tepi kanan trigger (biasanya 40dp)
    // agar sisi kanan popup menu tidak menempel ke tepi layar dan tetap memiliki space 16dp.
    final effectiveOffset = offset ??
        (alignRight ? Offset(-(menuWidth - 40), 8) : const Offset(0, 8));

    return MenuAnchor(
      alignmentOffset: effectiveOffset,
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll<Color>(Colors.white),
        elevation: const WidgetStatePropertyAll<double>(6),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(vertical: 4),
        ),
        fixedSize: WidgetStatePropertyAll<Size>(Size.fromWidth(menuWidth)),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.brandBorder),
          ),
        ),
      ),
      menuChildren: [
        for (final item in items) ...[
          MenuItemButton(
            onPressed: () => onSelected(item.value),
            leadingIcon: item.icon != null
                ? Icon(
                    item.icon,
                    size: 19,
                    color: item.isDestructive
                        ? AppColors.error
                        : AppColors.brandEspresso,
                  )
                : null,
            child: Text(
              item.label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: item.isDestructive
                    ? AppColors.error
                    : AppColors.brandEspresso,
              ),
            ),
          ),
          if (item.isDividerAfter)
            const Divider(height: 1, color: AppColors.brandBorder),
        ],
      ],
      builder: (context, controller, child) {
        final defaultWidget = Container(
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
        );

        final target = triggerWidget ?? defaultWidget;

        return Padding(
          padding: padding,
          child: Tooltip(
            message: tooltip ?? '',
            child: InkWell(
              onTap: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: target,
            ),
          ),
        );
      },
    );
  }
}
