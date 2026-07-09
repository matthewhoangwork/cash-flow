import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// True on iOS/macOS, where native chrome (dialogs, action sheets, buttons)
/// should look Cupertino instead of Material.
bool isApplePlatform(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

/// A dialog action for use inside [AlertDialog.adaptive] + [showAdaptiveDialog]:
/// [CupertinoDialogAction] on iOS/macOS, [TextButton] elsewhere.
Widget adaptiveDialogAction({
  required BuildContext context,
  required VoidCallback? onPressed,
  required Widget child,
  bool isDestructive = false,
  bool isDefault = false,
}) {
  if (isApplePlatform(context)) {
    return CupertinoDialogAction(
      onPressed: onPressed,
      isDestructiveAction: isDestructive,
      isDefaultAction: isDefault,
      child: child,
    );
  }
  return TextButton(
    onPressed: onPressed,
    style: isDestructive
        ? TextButton.styleFrom(foregroundColor: AppColors.expense)
        : null,
    child: child,
  );
}

/// A full-width primary form action: [CupertinoButton.filled] on iOS/macOS,
/// the themed [ElevatedButton] (see [buildAppTheme]) elsewhere.
class AdaptivePrimaryButton extends StatelessWidget {
  const AdaptivePrimaryButton({
    required this.onPressed,
    required this.child,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform(context)) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(onPressed: onPressed, child: child),
      );
    }
    return ElevatedButton(onPressed: onPressed, child: child);
  }
}

/// A date-only picker: a [CupertinoDatePicker] in a bottom sheet with a
/// "Done" button on iOS/macOS, [showDatePicker]'s Material calendar
/// elsewhere.
Future<DateTime?> showAdaptiveDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  if (isApplePlatform(context)) {
    var selected = initialDate;
    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) => Container(
        height: 320,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context, selected),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initialDate,
                minimumDate: firstDate,
                maximumDate: lastDate,
                onDateTimeChanged: (value) => selected = value,
              ),
            ),
          ],
        ),
      ),
    );
  }
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );
}

/// A top-bar action button: a compact borderless [CupertinoButton] with the
/// Cupertino glyph on iOS/macOS (sized to sit inside a
/// [CupertinoSliverNavigationBar]'s trailing slot), an [IconButton] with the
/// Material glyph elsewhere.
class AdaptiveNavAction extends StatelessWidget {
  const AdaptiveNavAction({
    required this.materialIcon,
    required this.cupertinoIcon,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final IconData materialIcon;
  final IconData cupertinoIcon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform(context)) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(38, 44),
        onPressed: onPressed,
        child: Icon(cupertinoIcon, size: 22, color: AppColors.ink),
      );
    }
    return IconButton(
      icon: Icon(materialIcon),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

/// A two-or-more-way toggle: [CupertinoSlidingSegmentedControl] on iOS/macOS,
/// [SegmentedButton] elsewhere. Segments are (value, label) pairs.
class AdaptiveSegmentedControl<T extends Object> extends StatelessWidget {
  const AdaptiveSegmentedControl({
    required this.segments,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<(T, String)> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform(context)) {
      return CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        onValueChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
        children: {
          for (final (segmentValue, label) in segments)
            segmentValue: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
        },
      );
    }
    return SegmentedButton<T>(
      segments: [
        for (final (segmentValue, label) in segments)
          ButtonSegment(value: segmentValue, label: Text(label)),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// One entry in an [AdaptiveMenuButton].
class AdaptiveMenuItem {
  const AdaptiveMenuItem({
    required this.label,
    required this.onSelected,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onSelected;
  final bool isDestructive;
}

/// An overflow "manage" menu: a [CupertinoActionSheet] on iOS/macOS
/// (triggered from an ellipsis icon), a [PopupMenuButton] elsewhere.
class AdaptiveMenuButton extends StatelessWidget {
  const AdaptiveMenuButton({required this.items, this.tooltip, super.key});

  final List<AdaptiveMenuItem> items;
  final String? tooltip;

  void _showActionSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          for (final item in items)
            CupertinoActionSheetAction(
              isDestructiveAction: item.isDestructive,
              onPressed: () {
                Navigator.pop(sheetContext);
                item.onSelected();
              },
              child: Text(item.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform(context)) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(38, 44),
        onPressed: () => _showActionSheet(context),
        child: const Icon(
          CupertinoIcons.ellipsis_circle,
          size: 22,
          color: AppColors.ink,
        ),
      );
    }
    return PopupMenuButton<VoidCallback>(
      icon: const Icon(Icons.more_vert),
      tooltip: tooltip,
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem(
            value: item.onSelected,
            child: Text(
              item.label,
              style: item.isDestructive
                  ? const TextStyle(color: AppColors.expense)
                  : null,
            ),
          ),
      ],
    );
  }
}
