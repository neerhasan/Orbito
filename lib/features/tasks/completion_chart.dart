import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/task_view.dart';
import '../../ui/ember.dart';

/// A line chart of tasks completed per day (or per month). The last point
/// is today and is the only orange one.
class CompletionChart extends StatelessWidget {
  const CompletionChart({
    super.key,
    required this.points,
    required this.summary,
  });

  final List<ChartPoint> points;

  /// Read by screen readers instead of the drawing.
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chart of tasks completed. $summary',
      child: SizedBox(
        height: 132,
        child: CustomPaint(painter: _ChartPainter(points), size: Size.infinite),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.points);

  final List<ChartPoint> points;

  static const _left = 22.0;
  static const _right = 10.0;
  static const _top = 6.0;
  static const _bottom = 22.0;
  static const _rows = 4;

  void _label(
    Canvas canvas,
    String text,
    Offset anchor, {
    required Color color,
    bool center = false,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: Ember.text(10, 12, weight: bold ? 600 : 400, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center
        ? anchor.dx - painter.width / 2
        : anchor.dx - painter.width;
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final width = size.width - _left - _right;
    final height = size.height - _top - _bottom;
    final highest = points.map((point) => point.count).reduce(math.max);
    // The top of the scale: a multiple of 4, so the row labels are whole.
    final top = math.max(_rows, (highest / _rows).ceil() * _rows);

    final grid = Paint()
      ..color = Ember.line
      ..strokeWidth = 1;
    for (var row = 0; row <= _rows; row++) {
      final y = _top + height - height * row / _rows;
      canvas.drawLine(Offset(_left, y), Offset(_left + width, y), grid);
      _label(
        canvas,
        '${top * row ~/ _rows}',
        Offset(_left - 8, y),
        color: Ember.ink3,
      );
    }

    Offset at(int index) {
      final x = points.length == 1
          ? _left + width
          : _left + width * index / (points.length - 1);
      final y = _top + height - height * points[index].count / top;
      return Offset(x, y);
    }

    final line = Paint()
      ..color = Ember.ink
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(path, line);

    // With many points, only some days get a label so they do not collide.
    final step = points.length <= 14 ? 1 : 5;
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final position = at(i);
      canvas.drawCircle(
        position,
        point.current ? 3 : 2,
        Paint()..color = point.current ? Ember.now : Ember.ink,
      );
      final fromEnd = points.length - 1 - i;
      if (fromEnd % step != 0) continue;
      _label(
        canvas,
        point.label,
        Offset(position.dx, size.height - 8),
        color: point.current ? Ember.nowInk : Ember.ink3,
        center: true,
        bold: point.current,
      );
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.points != points;
}
