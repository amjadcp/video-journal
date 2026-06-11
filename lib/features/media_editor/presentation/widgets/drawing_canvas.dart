import 'package:flutter/material.dart';

class DrawingPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawingPath({
    required this.points,
    required this.color,
    this.strokeWidth = 4.0,
  });
}

class DrawingCanvas extends StatefulWidget {
  final Color currentColor;
  final Function(List<DrawingPath> paths) onPathsUpdated;

  const DrawingCanvas({
    super.key,
    required this.currentColor,
    required this.onPathsUpdated,
  });

  @override
  State<DrawingCanvas> createState() => DrawingCanvasState();
}

class DrawingCanvasState extends State<DrawingCanvas> {
  final List<DrawingPath> _paths = [];
  List<Offset> _currentPoints = [];

  void undo() {
    if (_paths.isNotEmpty) {
      setState(() {
        _paths.removeLast();
        widget.onPathsUpdated(List.from(_paths));
      });
    }
  }

  void clear() {
    if (_paths.isNotEmpty) {
      setState(() {
        _paths.clear();
        widget.onPathsUpdated([]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final localPosition = renderBox.globalToLocal(details.globalPosition);
          _currentPoints = [localPosition];
          _paths.add(DrawingPath(
            points: _currentPoints,
            color: widget.currentColor,
          ));
        });
      },
      onPanUpdate: (details) {
        setState(() {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final localPosition = renderBox.globalToLocal(details.globalPosition);
          _currentPoints.add(localPosition);
          widget.onPathsUpdated(List.from(_paths));
        });
      },
      onPanEnd: (details) {
        _currentPoints = [];
      },
      child: CustomPaint(
        painter: CanvasPainter(paths: _paths),
        size: Size.infinite,
      ),
    );
  }
}

class CanvasPainter extends CustomPainter {
  final List<DrawingPath> paths;

  CanvasPainter({required this.paths});

  @override
  void paint(Canvas canvas, Size size) {
    for (final path in paths) {
      if (path.points.length < 2) continue;

      final paint = Paint()
        ..color = path.color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = path.strokeWidth
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < path.points.length - 1; i++) {
        canvas.drawLine(path.points[i], path.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.paths != paths;
  }
}
