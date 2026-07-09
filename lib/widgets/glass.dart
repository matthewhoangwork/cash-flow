import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'adaptive.dart';

const _glassBlurSigma = 26.0;

/// Height of a compact (non-large-title) [CupertinoNavigationBar], excluding
/// the top safe-area inset — matches the framework's own internal constant.
const _kCupertinoNavBarHeight = 44.0;

/// A soft field of blurred color blobs (the app's own income/expense/balance
/// accent hues) painted behind scrollable content on iOS/macOS. Liquid Glass
/// panels blur whatever sits behind them — over a flat canvas color that
/// blur is a no-op, so without this the "glass" reads as a plain translucent
/// box. Use as the base layer of a screen's [Scaffold] body, under the
/// actual scrollable content.
class LiquidGlassBackdrop extends StatelessWidget {
  const LiquidGlassBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.canvas,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              left: -50,
              child: _blob(AppColors.balance, 240),
            ),
            Positioned(
              top: 140,
              right: -70,
              child: _blob(AppColors.income, 220),
            ),
            Positioned(
              bottom: 60,
              left: -40,
              child: _blob(AppColors.expense, 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(Color color, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: 0.18),
    ),
  );
}

/// A frosted-glass surface — gradient translucent fill, backdrop blur, a
/// specular highlight border, and a lifted shadow — evoking iOS 26's Liquid
/// Glass material. Falls back to the app's flat bordered [AppColors.surface]
/// card everywhere else, since blur/translucency without the platform's
/// native glass rendering reads as an unstyled bug rather than "glass".
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 12,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!isApplePlatform(context)) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: _glassBlurSigma,
          sigmaY: _glassBlurSigma,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.62),
                Colors.white.withValues(alpha: 0.34),
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A screen scaffold with a native-feeling top bar, over a
/// [LiquidGlassBackdrop] so the blur has color to work with. Elsewhere (or
/// when [largeTitle] is false) it falls back the same way [AppBar]/compact
/// [CupertinoNavigationBar] would.
///
/// - [largeTitle] true (root/tab screens): a [CupertinoSliverNavigationBar]
///   whose large title collapses into the translucent inline bar as content
///   scrolls under it, matching how iOS renders a navigation stack's root.
/// - [largeTitle] false (screens pushed via [Navigator.push]): a compact,
///   fixed [CupertinoNavigationBar] with the back chevron and title on the
///   same row — matching how iOS renders a pushed detail screen.
///
/// [slivers] is the screen body; wrap plain boxes in [SliverToBoxAdapter].
class AdaptiveSliverScaffold extends StatelessWidget {
  const AdaptiveSliverScaffold({
    required this.title,
    required this.slivers,
    this.actions,
    this.floatingActionButton,
    this.largeTitle = true,
    super.key,
  });

  final String title;
  final List<Widget> slivers;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool largeTitle;

  @override
  Widget build(BuildContext context) {
    if (!isApplePlatform(context)) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: CustomScrollView(slivers: slivers),
        floatingActionButton: floatingActionButton,
      );
    }
    final trailing = actions == null || actions!.isEmpty
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: actions!);

    if (!largeTitle) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: CupertinoNavigationBar(middle: Text(title), trailing: trailing),
        body: Stack(
          children: [
            const Positioned.fill(child: LiquidGlassBackdrop()),
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).padding.top + _kCupertinoNavBarHeight,
                  ),
                ),
                ...slivers,
              ],
            ),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: LiquidGlassBackdrop()),
          CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: Text(title),
                stretch: true,
                trailing: trailing,
              ),
              ...slivers,
            ],
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Shows a bottom sheet: the app's flat [AppColors.surface] sheet, with a
/// native iOS grab handle on top on iOS/macOS. Real iOS sheets (unlike nav
/// bars/toolbars) are opaque — a translucent blur here would pick up
/// whatever's behind the modal (the dimming scrim, other screens' colors),
/// producing an arbitrary muddy tint instead of a stable, correct sheet
/// color. Drop-in replacement for the plain `showModalBottomSheet` calls
/// used for the category/wallet/transaction forms.
Future<T?> showAdaptiveModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  );
  if (!isApplePlatform(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: shape,
      builder: builder,
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: shape,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 4),
          child: _SheetGrabber(),
        ),
        Flexible(child: builder(sheetContext)),
      ],
    ),
  );
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey3,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
