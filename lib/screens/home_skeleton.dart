import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/glass.dart';

/// Mirrors [HomeScreen]'s layout with pulsing placeholder blocks. Shown by
/// [AuthGate] while session state is still resolving, so app start never
/// shows a bare spinner.
class HomeSkeleton extends StatefulWidget {
  const HomeSkeleton({super.key});

  @override
  State<HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<HomeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _pulse = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  ).drive(Tween(begin: 0.5, end: 1.0));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveSliverScaffold(
      title: 'Cash',
      slivers: [
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _pulse,
            child: const Column(
              children: [
                _BalanceCardSkeleton(),
                _ChartCardSkeleton(),
                Divider(height: 1),
                _SkeletonTile(),
                _SkeletonTile(),
                _SkeletonTile(),
                _SkeletonTile(),
                _SkeletonTile(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceCardSkeleton extends StatelessWidget {
  const _BalanceCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SkeletonBox(width: 64, height: 12),
                _SkeletonBox(width: 72, height: 20, radius: 10),
              ],
            ),
            SizedBox(height: 10),
            _SkeletonBox(width: 160, height: 30),
            SizedBox(height: 18),
            Row(
              children: [_SkeletonStat(), SizedBox(width: 28), _SkeletonStat()],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCardSkeleton extends StatelessWidget {
  const _ChartCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SkeletonBox(width: 64, height: 12),
                _SkeletonBox(width: 88, height: 22, radius: 8),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 190,
              width: double.infinity,
              child: _SkeletonBox(
                width: double.infinity,
                height: 190,
                radius: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonStat extends StatelessWidget {
  const _SkeletonStat();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBox(width: 48, height: 10),
        SizedBox(height: 6),
        _SkeletonBox(width: 80, height: 14),
      ],
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: const [
          _SkeletonBox(width: 40, height: 40, radius: 10),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 120, height: 14),
                SizedBox(height: 6),
                _SkeletonBox(width: 80, height: 11),
              ],
            ),
          ),
          SizedBox(width: 8),
          _SkeletonBox(width: 64, height: 14),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 6,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
