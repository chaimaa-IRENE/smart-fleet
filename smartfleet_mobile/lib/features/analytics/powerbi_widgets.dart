import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'powerbi_theme.dart';

Widget pbiIcon(String name, {double size = 16, Color? color}) {
  final c = color ?? const Color(0xFF9CA3AF);
  switch (name) {
    case 'Truck': return Icon(Icons.local_shipping, size: size, color: c);
    case 'Search': return Icon(Icons.search, size: size, color: c);
    case 'AlertTriangle': return Icon(Icons.warning_amber_rounded, size: size, color: c);
    case 'FileText': return Icon(Icons.description_outlined, size: size, color: c);
    case 'Clock': return Icon(Icons.schedule, size: size, color: c);
    case 'Gauge': return Icon(Icons.speed, size: size, color: c);
    case 'Fuel': return Icon(Icons.local_gas_station, size: size, color: c);
    case 'Shield': return Icon(Icons.shield_outlined, size: size, color: c);
    case 'Activity': return Icon(Icons.monitor_heart_outlined, size: size, color: c);
    case 'BrainCircuit': return Icon(Icons.psychology_outlined, size: size, color: c);
    case 'Sparkles': return Icon(Icons.auto_awesome, size: size, color: c);
    case 'CheckCircle': return Icon(Icons.check_circle, size: size, color: c);
    case 'XCircle': return Icon(Icons.cancel, size: size, color: c);
    case 'Wrench': return Icon(Icons.build, size: size, color: c);
    case 'Wallet': return Icon(Icons.account_balance_wallet_outlined, size: size, color: c);
    case 'BarChart3': return Icon(Icons.bar_chart, size: size, color: c);
    case 'TrendingUp': return Icon(Icons.trending_up, size: size, color: c);
    case 'TrendingDown': return Icon(Icons.trending_down, size: size, color: c);
    case 'Trophy': return Icon(Icons.emoji_events_outlined, size: size, color: c);
    case 'Users': return Icon(Icons.group, size: size, color: c);
    case 'User': return Icon(Icons.person, size: size, color: c);
    case 'Building2': return Icon(Icons.business, size: size, color: c);
    case 'UserCog': return Icon(Icons.manage_accounts_outlined, size: size, color: c);
    case 'MapPin': return Icon(Icons.place_outlined, size: size, color: c);
    case 'Calendar': return Icon(Icons.calendar_month_outlined, size: size, color: c);
    case 'SlidersHorizontal': return Icon(Icons.tune, size: size, color: c);
    case 'RefreshCw': return Icon(Icons.refresh, size: size, color: c);
    case 'LayoutDashboard': return Icon(Icons.space_dashboard_outlined, size: size, color: c);
    case 'ChevronRight': return Icon(Icons.chevron_right, size: size, color: c);
    case 'Bell': return Icon(Icons.notifications_outlined, size: size, color: c);
    case 'Zap': return Icon(Icons.bolt, size: size, color: c);
    case 'Star': return Icon(Icons.star, size: size, color: c);
    case 'Award': return Icon(Icons.workspace_premium_outlined, size: size, color: c);
    case 'Phone': return Icon(Icons.phone_outlined, size: size, color: c);
    case 'Mail': return Icon(Icons.mail_outline, size: size, color: c);
    case 'X': return Icon(Icons.close, size: size, color: c);
    case 'Bot': return Icon(Icons.smart_toy_outlined, size: size, color: c);
    case 'DollarSign': return Icon(Icons.attach_money, size: size, color: c);
    case 'Timer': return Icon(Icons.timer_outlined, size: size, color: c);
    case 'BadgeCheck': return Icon(Icons.verified, size: size, color: c);
    case 'Copy': return Icon(Icons.copy, size: size, color: c);
    default: return Icon(Icons.circle, size: size, color: c);
  }
}

class CardHeader extends StatelessWidget {
  final String title;
  final String icon;
  final Color iconColor;
  const CardHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          pbiIcon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD1D5DB),
                letterSpacing: 0.6,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class PbiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const PbiCard({super.key, required this.child, this.padding = const EdgeInsets.all(12)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE61E293B), Color(0xE61A2436)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0FFFFFFF), width: 1),
      ),
      child: child,
    );
  }
}

/// Displays [children] in a horizontal `Row` (equal width) on wide screens,
/// and stacks them vertically (full width) on narrow screens to prevent
/// right/bottom overflows.
class PbiStackRow extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  final double breakpoint;
  const PbiStackRow({
    super.key,
    required this.children,
    this.gap = 10,
    this.breakpoint = 560,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint || children.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

/// Responsive KPI grid: uses a `Wrap` so every cell has a computed width
/// (2 columns on phones) while the height grows with the content, which
/// guarantees there is never a bottom overflow.
class PbiKpiGrid extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const PbiKpiGrid({super.key, required this.children, this.gap = 8});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w < 420
            ? 2
            : w < 700
                ? 3
                : w < 1000
                    ? 4
                    : 6;
        final cardW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final child in children) SizedBox(width: cardW, child: child)],
        );
      },
    );
  }
}

class PbiEmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String message;
  const PbiEmptyState({
    super.key,
    this.icon = 'truck',
    this.title = 'Prêt à démarrer',
    this.message = 'Les données apparaîtront ici une fois disponibles.',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x1A3B82F6), Color(0x1A6366F1)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x333B82F6)),
            ),
            child: Center(
              child: pbiIcon(icon, size: 48, color: const Color(0x663B82F6)),
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD1D5DB))),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class PbiAnimatedCounter extends StatelessWidget {
  final double value;
  final String suffix;
  final int decimals;
  const PbiAnimatedCounter({
    super.key,
    required this.value,
    this.suffix = '',
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final txt = decimals > 0 ? v.toStringAsFixed(decimals) : v.round().toString();
        return Text('$txt$suffix', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white));
      },
    );
  }
}

class PbiStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool border;
  const PbiStatusBadge({super.key, required this.label, required this.color, this.border = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: border ? Border.all(color: color.withValues(alpha: 0.20)) : null,
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class PbiProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  final Duration duration;
  const PbiProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: height,
        width: double.infinity,
        color: Colors.white.withValues(alpha: 0.05),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final target = (value.clamp(0.0, 100.0) / 100) * constraints.maxWidth;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: target),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Align(
                alignment: Alignment.centerLeft,
                child: Container(width: v, color: color),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PbiGauge extends StatelessWidget {
  final double value;
  final String label;
  final double size;
  final Color? color;
  const PbiGauge({
    super.key,
    required this.value,
    required this.label,
    this.size = 160,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = value.clamp(0, 100).toDouble();
    final gaugeColor = color ?? (normalized >= 80 ? PbiColors.emerald : normalized >= 50 ? PbiColors.amber : PbiColors.rose);
    final strokeWidth = 12.0;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(
          value: normalized,
          color: gaugeColor,
          trackColor: const Color(0x14FFFFFF),
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${normalized.round()}%',
                style: TextStyle(fontSize: size * 0.16, fontWeight: FontWeight.bold, color: gaugeColor),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _GaugePainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width - 40) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawArc(rect, -math.pi / 2, (value / 100) * math.pi * 2, false, progress);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

class PbiMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const PbiMiniStat({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x800F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }
}

class PbiChartTooltip extends StatelessWidget {
  final String label;
  final List<MapEntry<String, (double, Color)>> entries;
  final Color background;
  const PbiChartTooltip({
    super.key,
    required this.label,
    required this.entries,
    this.background = const Color(0xF21E293B),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD1D5DB))),
          const SizedBox(height: 4),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: e.value.$2, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                    '${e.key}: ',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                  ),
                  Text(
                    e.value.$1.toString(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE5E7EB)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class PbiPageTitle extends StatelessWidget {
  final String title;
  const PbiPageTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE5E7EB), letterSpacing: 0.6),
    );
  }
}

Widget pbiSectionTitle(String icon, String title, Color iconColor) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        pbiIcon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE5E7EB), letterSpacing: 0.6),
          ),
        ),
      ],
    ),
  );
}

String formatNumber(num v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    buf.write(s[i]);
    final remaining = s.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) buf.write(' ');
  }
  return buf.toString();
}

class PbiComposedChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final List<({String key, String name, Color color, double? width, double? barRadius, double? barWidth})> bars;
  final List<({String key, String name, Color color, double width})> lines;
  final double height;
  final Color tooltipBackground;

  const PbiComposedChart({
    super.key,
    required this.data,
    this.bars = const [],
    this.lines = const [],
    this.height = 220,
    this.tooltipBackground = const Color(0xF20F172A),
  });

  @override
  State<PbiComposedChart> createState() => _PbiComposedChartState();
}

class _PbiComposedChartState extends State<PbiComposedChart> {
  int? _hover;

  double _maxVal() {
    var m = 4.0;
    for (final d in widget.data) {
      for (final b in widget.bars) {
        final v = (d[b.key] as num?)?.toDouble() ?? 0;
        if (v > m) m = v;
      }
      for (final l in widget.lines) {
        final v = (d[l.key] as num?)?.toDouble() ?? 0;
        if (v > m) m = v;
      }
    }
    return m * 1.2;
  }

  Widget _bottomTitle(double v, TitleMeta meta) {
    final i = v.toInt();
    if (i < 0 || i >= widget.data.length) return const SizedBox.shrink();
    final mois = widget.data[i]['mois'] as String? ?? '';
    final label = mois.length >= 7 ? mois.substring(2) : mois;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(label, style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8))),
    );
  }

  Widget _leftTitle(double v, TitleMeta meta) {
    return Text(
      v.toInt().toString(),
      style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data.isEmpty) {
      return SizedBox(height: widget.height, child: const PbiEmptyState(icon: 'chart', message: 'Aucune donnée'));
    }
    final maxY = _maxVal();
    final n = data.length;
    final tooltipItems = <MapEntry<String, (double, Color)>>[];
    if (_hover != null && _hover! >= 0 && _hover! < n) {
      for (final b in widget.bars) {
        final v = (data[_hover!][b.key] as num?)?.toDouble() ?? 0;
        tooltipItems.add(MapEntry(b.name, (v, b.color)));
      }
      for (final l in widget.lines) {
        final v = (data[_hover!][l.key] as num?)?.toDouble() ?? 0;
        tooltipItems.add(MapEntry(l.name, (v, l.color)));
      }
    }

    final grid = FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) =>
          const FlLine(color: Color(0x14FFFFFF), strokeWidth: 1, dashArray: [4, 4]),
    );
    final titles = FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 34,
          interval: maxY / 4,
          getTitlesWidget: _leftTitle,
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 18,
          getTitlesWidget: _bottomTitle,
        ),
      ),
    );

    final bars = BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: 0,
        maxY: maxY,
        gridData: grid,
        borderData: FlBorderData(show: false),
        titlesData: titles,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: widget.tooltipBackground,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => null,
          ),
          touchCallback: (event, response) {
            if (event.isInterestedForInteractions && response != null && response.spot != null) {
              setState(() => _hover = response.spot!.touchedBarGroupIndex);
            }
          },
        ),
        barGroups: [
          for (int i = 0; i < n; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                for (final b in widget.bars)
                  BarChartRodData(
                    toY: (data[i][b.key] as num?)?.toDouble() ?? 0,
                    color: b.color,
                    width: b.barWidth ?? 12,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(b.barRadius ?? 6)),
                  ),
              ],
            ),
        ],
      ),
    );

    final lines = LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: grid,
        borderData: FlBorderData(show: false),
        titlesData: titles,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: widget.tooltipBackground,
            getTooltipItems: (_) => [],
          ),
          touchCallback: (event, response) {
            if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
              final x = response.lineBarSpots!.first.x.toInt();
              if (x >= 0 && x < n) setState(() => _hover = x);
            } else if (!event.isInterestedForInteractions) {
              setState(() => _hover = null);
            }
          },
        ),
        lineBarsData: [
          for (final l in widget.lines)
            LineChartBarData(
              spots: [
                for (int i = 0; i < n; i++)
                  FlSpot(i.toDouble(), (data[i][l.key] as num?)?.toDouble() ?? 0),
              ],
              color: l.color,
              barWidth: l.width,
              isCurved: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                  radius: 3,
                  color: l.color,
                  strokeWidth: 0,
                ),
              ),
            ),
        ],
      ),
    );

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final xPos = _hover != null ? (_hover! + 0.5) * w / n : 0.0;
          return Stack(
            children: [
              Positioned.fill(child: bars),
              Positioned.fill(
                child: IgnorePointer(child: lines),
              ),
              if (_hover != null && tooltipItems.isNotEmpty)
                Positioned(
                  left: (xPos - 90).clamp(4.0, w - 200),
                  top: 0,
                  child: PbiChartTooltip(
                    label: data[_hover!]['mois'] as String? ?? '',
                    entries: tooltipItems,
                    background: widget.tooltipBackground,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class PbiBarChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final String dataKey;
  final String name;
  final Color color;
  final double height;
  final bool vertical;
  final double barRadius;
  final Color tooltipBackground;

  const PbiBarChart({
    super.key,
    required this.data,
    required this.dataKey,
    required this.name,
    required this.color,
    this.height = 220,
    this.vertical = false,
    this.barRadius = 6,
    this.tooltipBackground = const Color(0xF20F172A),
  });

  @override
  State<PbiBarChart> createState() => _PbiBarChartState();
}

class _PbiBarChartState extends State<PbiBarChart> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data.isEmpty) {
      return SizedBox(height: widget.height, child: const PbiEmptyState(icon: 'chart', message: 'Aucune donnée'));
    }
    final n = data.length;
    var maxV = 4.0;
    for (final d in data) {
      final v = (d[widget.dataKey] as num?)?.toDouble() ?? 0;
      if (v > maxV) maxV = v;
    }
    final maxY = maxV * 1.2;

    final tooltipItems = <MapEntry<String, (double, Color)>>[];
    if (_hover != null && _hover! >= 0 && _hover! < n) {
      tooltipItems.add(MapEntry(
        widget.name,
        ((data[_hover!][widget.dataKey] as num?)?.toDouble() ?? 0, widget.color),
      ));
    }

    if (!widget.vertical) {
      return SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final xPos = _hover != null ? (_hover! + 0.5) * w / n : 0.0;
            return Stack(
              children: [
                Positioned.fill(
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      minY: 0,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: Color(0x14FFFFFF), strokeWidth: 1, dashArray: [4, 4]),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            interval: maxY / 4,
                            getTitlesWidget: (v, meta) => Text(
                              v.toInt().toString(),
                              style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 18,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= n) return const SizedBox.shrink();
                              final label = (data[i].keys.contains('mois'))
                                  ? ((data[i]['mois'] as String).length >= 7
                                      ? (data[i]['mois'] as String).substring(2)
                                      : data[i]['mois'] as String)
                                  : data[i][widget.dataKey].toString();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(label, style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8))),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: widget.tooltipBackground,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) => null,
                        ),
                        touchCallback: (event, response) {
                          if (event.isInterestedForInteractions && response != null && response.spot != null) {
                            setState(() => _hover = response.spot!.touchedBarGroupIndex);
                          }
                        },
                      ),
                      barGroups: [
                        for (int i = 0; i < n; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: (data[i][widget.dataKey] as num?)?.toDouble() ?? 0,
                                color: widget.color,
                                width: 12,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(widget.barRadius)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                if (_hover != null && tooltipItems.isNotEmpty)
                  Positioned(
                    left: (xPos - 60).clamp(4.0, w - 140),
                    top: 0,
                    child: PbiChartTooltip(
                      label: (data[_hover!].keys.contains('mois'))
                          ? data[_hover!]['mois'] as String
                          : data[_hover!][widget.dataKey].toString(),
                      entries: tooltipItems,
                      background: widget.tooltipBackground,
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    // Horizontal (vertical=true) layout
    final reversed = data.reversed.toList();
    return SizedBox(
      height: widget.height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            getDrawingVerticalLine: (_) =>
                const FlLine(color: Color(0x14FFFFFF), strokeWidth: 1, dashArray: [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 18,
                interval: maxY / 4,
                getTitlesWidget: (v, meta) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 90,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= reversed.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      reversed[i].keys.contains('name')
                          ? reversed[i]['name'] as String
                          : reversed[i][widget.dataKey].toString(),
                      style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: widget.tooltipBackground,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${widget.name}: ${rod.toY.round()}',
                const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE5E7EB)),
              ),
            ),
          ),
          barGroups: [
            for (int i = 0; i < reversed.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (reversed[i][widget.dataKey] as num?)?.toDouble() ?? 0,
                    color: widget.color,
                    width: 14,
                    borderRadius: BorderRadius.horizontal(right: Radius.circular(widget.barRadius)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class PbiDonut extends StatelessWidget {
  final List<MapEntry<String, double>> data;
  final Color Function(int) colorFor;
  final double centerValue;
  final String centerLabel;
  final double height;
  final double innerRadius;
  final double outerRadius;

  const PbiDonut({
    super.key,
    required this.data,
    required this.colorFor,
    required this.centerValue,
    required this.centerLabel,
    this.height = 240,
    this.innerRadius = 38,
    this.outerRadius = 52,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(height: height, child: const PbiEmptyState(icon: 'chart', message: 'Aucune donnée'));
    }
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final short = math.min(constraints.maxWidth, constraints.maxHeight);
          final safeOuter = math.max(
            12.0,
            math.min(outerRadius, (short - innerRadius - 8) / 2),
          );
          final safeInner = math.min(innerRadius, short / 2 - safeOuter - 8);
          return Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: math.max(0, safeInner),
                  sections: [
                    for (int i = 0; i < data.length; i++)
                      PieChartSectionData(
                        value: data[i].value,
                        color: colorFor(i),
                        radius: safeOuter,
                        showTitle: false,
                      ),
                  ],
                  pieTouchData: PieTouchData(enabled: false),
                ),
              ),
              if (centerValue >= 0)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerValue.round().toString(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    if (centerLabel.isNotEmpty)
                      Text(
                        centerLabel,
                        style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

List<Map<String, dynamic>> toChart(List<MapEntry<String, num>> entries) {
  return entries.map((e) => {'name': e.key, 'value': e.value}).toList();
}

Color chartColor(int i) => kChartColors[i % kChartColors.length];

enum PbiAlign { left, center, right }

class PbiTable extends StatelessWidget {
  final List<(String, PbiAlign)> headers;
  final List<List<Widget>> rows;
  final double maxHeight;
  final double rowHeight;
  final Widget? empty;

  const PbiTable({
    super.key,
    required this.headers,
    required this.rows,
    this.maxHeight = 208,
    this.rowHeight = 36,
    this.empty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  color: const Color(0xF21E293B),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final h in headers)
                        Container(
                          width: 110,
                          alignment: h.$2 == PbiAlign.center
                              ? Alignment.center
                              : h.$2 == PbiAlign.right
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Text(
                            h.$1,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF)),
                          ),
                        ),
                    ],
                  ),
                ),
                if (rows.isEmpty && empty != null)
                  SizedBox(width: 400, child: empty)
                else
                  for (final row in rows)
                    Container(
                      height: rowHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0x0DFFFFFF))),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < row.length; i++)
                            Container(
                              width: 110,
                              alignment: headers[i].$2 == PbiAlign.center
                                  ? Alignment.center
                                  : headers[i].$2 == PbiAlign.right
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                              child: row[i],
                            ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
