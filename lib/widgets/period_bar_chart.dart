import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/currency_format.dart';

class PeriodBar {
  const PeriodBar({
    required this.label,
    required this.income,
    required this.expense,
    required this.balance,
    this.highlighted = false,
  });

  final String label;
  final double income;
  final double expense;

  /// Running balance of the default wallet as of the end of this period.
  /// Null for periods that haven't happened yet — nothing's been paid, so
  /// there's no balance to show.
  final double? balance;
  final bool highlighted;
}

/// Diverging income/expense chart — income grows up and expense grows down
/// from a shared zero baseline, one column per period — with the default
/// wallet's running balance traced as a line across the same axis. Shared by
/// the home dashboard's daily and weekly views.
class PeriodBarChart extends StatefulWidget {
  const PeriodBarChart({super.key, required this.bars});

  final List<PeriodBar> bars;

  @override
  State<PeriodBarChart> createState() => _PeriodBarChartState();
}

class _PeriodBarChartState extends State<PeriodBarChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final bars = widget.bars;
    final hasData = bars.any((b) => b.income != 0 || b.expense != 0 || (b.balance ?? 0) != 0);

    if (!hasData) {
      return const Center(
        child: Text('No transactions in this period', style: TextStyle(color: AppColors.muted)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ChartLegend(),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (details) => _select(details.localPosition, size),
                onPanUpdate: (details) => _select(details.localPosition, size),
                onPanEnd: (_) => setState(() => _selectedIndex = null),
                onPanCancel: () => setState(() => _selectedIndex = null),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _DivergingChartPainter(bars: bars, selectedIndex: _selectedIndex),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _select(Offset localPosition, Size size) {
    final layout = _ChartLayout(widget.bars, size);
    final index = layout.indexForX(localPosition.dx);
    if (index != _selectedIndex) setState(() => _selectedIndex = index);
  }
}

/// Shared geometry so the painter and the tap handler agree on where each
/// column sits and how values map to pixels.
class _ChartLayout {
  _ChartLayout(this.bars, Size size)
      : plotWidth = math.max(size.width - axisWidth, 0),
        plotHeight = math.max(size.height - _labelAreaHeight, 0) {
    var maxPositive = 0.0;
    var maxNegativeAbs = 0.0;
    for (final b in bars) {
      final balance = b.balance ?? 0;
      maxPositive = math.max(maxPositive, math.max(b.income, balance > 0 ? balance : 0));
      maxNegativeAbs = math.max(maxNegativeAbs, math.max(b.expense, balance < 0 ? -balance : 0));
    }
    yMax = maxPositive > 0 ? _niceCeil(maxPositive * 1.2) : 0;
    yMin = maxNegativeAbs > 0 ? -_niceCeil(maxNegativeAbs * 1.2) : 0;
    final range = yMax - yMin;
    _range = range == 0 ? 1 : range;
  }

  /// Reserved on the left for the value-scale (axis) column.
  static const double axisWidth = 40;
  static const double _labelAreaHeight = 24;

  final List<PeriodBar> bars;
  final double plotWidth;
  final double plotHeight;
  late final double yMax;
  late final double yMin;
  late final double _range;

  double yToPixel(double value) => (yMax - value) / _range * plotHeight;

  double get zeroY => yToPixel(0);

  double get _slotWidth => plotWidth / bars.length;

  double columnCenterX(int index) => _slotWidth * (index + 0.5);

  double get columnWidth => math.min(20, _slotWidth * 0.5);

  /// Scale markers for the axis column: just the top/bottom extremes and
  /// zero — the halfway points added noise without adding readability.
  List<double> get axisTicks => [
        if (yMax > 0) yMax,
        0,
        if (yMin < 0) yMin,
      ];

  int? indexForX(double x) {
    if (bars.isEmpty) return null;
    final adjusted = x - axisWidth;
    final index = (adjusted / _slotWidth).floor();
    if (index < 0 || index >= bars.length) return null;
    return index;
  }
}

/// Rounds up to a "nice" round number (1/2/5 × a power of ten) so axis
/// scale markers read as 50k, 100k, etc. instead of arbitrary values like 71k.
double _niceCeil(double value) {
  if (value <= 0) return 0;
  final magnitude = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
  final fraction = value / magnitude;
  final niceFraction = fraction <= 1
      ? 1.0
      : fraction <= 2
          ? 2.0
          : fraction <= 5
              ? 5.0
              : 10.0;
  return niceFraction * magnitude;
}

/// Compact value label for the axis column, e.g. "240k", "1.2tr", "-80k".
String _formatAxisValue(double value) {
  if (value == 0) return '0';
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  if (abs >= 1000000) {
    final millions = abs / 1000000;
    final text = millions == millions.roundToDouble()
        ? millions.toStringAsFixed(0)
        : millions.toStringAsFixed(1);
    return '$sign${text}tr';
  }
  if (abs >= 1000) {
    return '$sign${(abs / 1000).round()}k';
  }
  return '$sign${abs.round()}';
}

class _DivergingChartPainter extends CustomPainter {
  _DivergingChartPainter({required this.bars, required this.selectedIndex});

  final List<PeriodBar> bars;
  final int? selectedIndex;

  static const double _cornerRadius = 4;
  static const double _baselineGap = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _ChartLayout(bars, size);

    canvas.save();
    canvas.translate(_ChartLayout.axisWidth, 0);

    _paintAxis(canvas, layout);
    for (var i = 0; i < bars.length; i++) {
      _paintColumn(canvas, layout, i);
    }
    _paintBalanceLine(canvas, layout);
    _paintLabels(canvas, layout);

    if (selectedIndex != null) {
      _paintSelection(canvas, layout, selectedIndex!);
    }

    canvas.restore();
  }

  /// Value labels for each scale tick in the reserved left column (drawn at
  /// negative x, which — thanks to the canvas translation in [paint] — lands
  /// back in that margin). Only the zero tick gets a gridline across the
  /// plot; it's the one divider that's actually meaningful (it separates
  /// income from expense). The rest are label-only to keep the chart clean.
  void _paintAxis(Canvas canvas, _ChartLayout layout) {
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;

    for (final tick in layout.axisTicks) {
      final y = layout.yToPixel(tick);
      if (tick == 0) {
        canvas.drawLine(Offset(0, y), Offset(layout.plotWidth, y), gridPaint);
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: _formatAxisValue(tick),
          style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(-6 - textPainter.width, y - textPainter.height / 2),
      );
    }
  }

  void _paintColumn(Canvas canvas, _ChartLayout layout, int index) {
    final bar = bars[index];
    final centerX = layout.columnCenterX(index);
    final width = layout.columnWidth;
    final left = centerX - width / 2;
    final right = centerX + width / 2;

    if (bar.income > 0) {
      final top = layout.yToPixel(bar.income);
      final bottom = layout.zeroY - _baselineGap;
      if (bottom > top) {
        final radius = math.min(_cornerRadius, (bottom - top) / 2);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(left, top, right, bottom),
            topLeft: Radius.circular(radius),
            topRight: Radius.circular(radius),
          ),
          Paint()..color = AppColors.income,
        );
      }
    }

    if (bar.expense > 0) {
      final top = layout.zeroY + _baselineGap;
      final bottom = layout.yToPixel(-bar.expense);
      if (bottom > top) {
        final radius = math.min(_cornerRadius, (bottom - top) / 2);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(left, top, right, bottom),
            bottomLeft: Radius.circular(radius),
            bottomRight: Radius.circular(radius),
          ),
          Paint()..color = AppColors.expense,
        );
      }
    }
  }

  void _paintBalanceLine(Canvas canvas, _ChartLayout layout) {
    // Periods with no balance yet (not paid/not happened) break the line
    // instead of drawing a misleading flat continuation.
    final points = <Offset?>[
      for (var i = 0; i < bars.length; i++)
        if (bars[i].balance != null)
          Offset(layout.columnCenterX(i), layout.yToPixel(bars[i].balance!))
        else
          null,
    ];

    final linePaint = Paint()
      ..color = AppColors.balance
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final segments = <Path>[];
    Path? currentSegment;
    for (final point in points) {
      if (point == null) {
        currentSegment = null;
        continue;
      }
      if (currentSegment == null) {
        currentSegment = Path()..moveTo(point.dx, point.dy);
        segments.add(currentSegment);
      } else {
        currentSegment.lineTo(point.dx, point.dy);
      }
    }
    for (final segment in segments) {
      canvas.drawPath(segment, linePaint);
    }

    final ringPaint = Paint()..color = AppColors.surface;
    final dotPaint = Paint()..color = AppColors.balance;
    for (final point in points) {
      if (point == null) continue;
      canvas.drawCircle(point, 6, ringPaint);
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  void _paintLabels(Canvas canvas, _ChartLayout layout) {
    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final textPainter = TextPainter(
        text: TextSpan(
          text: bar.label,
          style: TextStyle(
            fontSize: 12,
            color: bar.highlighted ? AppColors.ink : AppColors.muted,
            fontWeight: bar.highlighted ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final centerX = layout.columnCenterX(i);
      textPainter.paint(canvas, Offset(centerX - textPainter.width / 2, layout.plotHeight + 8));
    }
  }

  void _paintSelection(Canvas canvas, _ChartLayout layout, int index) {
    final bar = bars[index];
    final centerX = layout.columnCenterX(index);

    final guidePaint = Paint()
      ..color = AppColors.muted.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, layout.plotHeight), guidePaint);

    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${bar.label}\n',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          TextSpan(
            text: 'Income  ${compactVnd(bar.income)}\n'
                'Expense  ${compactVnd(bar.expense)}\n'
                'Balance  ${bar.balance == null ? 'Not paid yet' : compactVnd(bar.balance!)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const paddingH = 10.0;
    const paddingV = 8.0;
    final boxWidth = textPainter.width + paddingH * 2;
    final boxHeight = textPainter.height + paddingV * 2;
    final boxLeft =
        (centerX - boxWidth / 2).clamp(0, math.max(0, layout.plotWidth - boxWidth)).toDouble();
    const boxTop = 4.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
          const Radius.circular(8)),
      Paint()..color = AppColors.ink,
    );
    textPainter.paint(canvas, Offset(boxLeft + paddingH, boxTop + paddingV));
  }

  @override
  bool shouldRepaint(covariant _DivergingChartPainter oldDelegate) {
    return oldDelegate.bars != bars || oldDelegate.selectedIndex != selectedIndex;
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _LegendItem(color: AppColors.income, label: 'Income'),
        SizedBox(width: 16),
        _LegendItem(color: AppColors.expense, label: 'Expense'),
        SizedBox(width: 16),
        _LegendItem(color: AppColors.balance, label: 'Balance'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
