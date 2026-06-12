import 'package:flutter/material.dart';

enum CropHandleType { none, topLeft, topRight, bottomLeft, bottomRight, center }

class CropOverlay extends StatefulWidget {
  final ValueChanged<Rect> onCropRectChanged;

  const CropOverlay({
    super.key,
    required this.onCropRectChanged,
  });

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<CropOverlay> {
  // Crop rect bounds in relative coordinates (0.0 to 1.0)
  double _left = 0.1;
  double _top = 0.1;
  double _right = 0.9;
  double _bottom = 0.9;

  CropHandleType _activeHandle = CropHandleType.none;
  Offset _dragStartOffset = Offset.zero;
  double _dragStartLeft = 0.0;
  double _dragStartTop = 0.0;
  double _dragStartRight = 0.0;
  double _dragStartBottom = 0.0;

  @override
  void initState() {
    super.initState();
    // Notify parent initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyChange();
    });
  }

  void _notifyChange() {
    widget.onCropRectChanged(
      Rect.fromLTRB(_left, _top, _right, _bottom),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // Convert relative coordinates to absolute screen pixels
        final absLeft = _left * width;
        final absTop = _top * height;
        final absRight = _right * width;
        final absBottom = _bottom * height;

        const handleRadius = 24.0; // Touch target radius

        return GestureDetector(
          onPanStart: (details) {
            final localPos = details.localPosition;
            _dragStartOffset = localPos;
            _dragStartLeft = _left;
            _dragStartTop = _top;
            _dragStartRight = _right;
            _dragStartBottom = _bottom;

            // Check if touch is near corner handles
            final distTL = (localPos - Offset(absLeft, absTop)).distance;
            final distTR = (localPos - Offset(absRight, absTop)).distance;
            final distBL = (localPos - Offset(absLeft, absBottom)).distance;
            final distBR = (localPos - Offset(absRight, absBottom)).distance;

            if (distTL < handleRadius) {
              _activeHandle = CropHandleType.topLeft;
            } else if (distTR < handleRadius) {
              _activeHandle = CropHandleType.topRight;
            } else if (distBL < handleRadius) {
              _activeHandle = CropHandleType.bottomLeft;
            } else if (distBR < handleRadius) {
              _activeHandle = CropHandleType.bottomRight;
            } else if (localPos.dx > absLeft &&
                localPos.dx < absRight &&
                localPos.dy > absTop &&
                localPos.dy < absBottom) {
              _activeHandle = CropHandleType.center;
            } else {
              _activeHandle = CropHandleType.none;
            }
          },
          onPanUpdate: (details) {
            if (_activeHandle == CropHandleType.none) return;

            final delta = details.localPosition - _dragStartOffset;
            final relDeltaX = delta.dx / width;
            final relDeltaY = delta.dy / height;

            setState(() {
              switch (_activeHandle) {
                case CropHandleType.topLeft:
                  _left = (_dragStartLeft + relDeltaX).clamp(0.0, _right - 0.1);
                  _top = (_dragStartTop + relDeltaY).clamp(0.0, _bottom - 0.1);
                  break;
                case CropHandleType.topRight:
                  _right = (_dragStartRight + relDeltaX).clamp(_left + 0.1, 1.0);
                  _top = (_dragStartTop + relDeltaY).clamp(0.0, _bottom - 0.1);
                  break;
                case CropHandleType.bottomLeft:
                  _left = (_dragStartLeft + relDeltaX).clamp(0.0, _right - 0.1);
                  _bottom = (_dragStartBottom + relDeltaY).clamp(_top + 0.1, 1.0);
                  break;
                case CropHandleType.bottomRight:
                  _right = (_dragStartRight + relDeltaX).clamp(_left + 0.1, 1.0);
                  _bottom = (_dragStartBottom + relDeltaY).clamp(_top + 0.1, 1.0);
                  break;
                case CropHandleType.center:
                  final cropWidth = _dragStartRight - _dragStartLeft;
                  final cropHeight = _dragStartBottom - _dragStartTop;

                  double newLeft = _dragStartLeft + relDeltaX;
                  double newTop = _dragStartTop + relDeltaY;

                  // Constrain inside bounds
                  if (newLeft < 0.0) {
                    newLeft = 0.0;
                  } else if (newLeft + cropWidth > 1.0) {
                    newLeft = 1.0 - cropWidth;
                  }

                  if (newTop < 0.0) {
                    newTop = 0.0;
                  } else if (newTop + cropHeight > 1.0) {
                    newTop = 1.0 - cropHeight;
                  }

                  _left = newLeft;
                  _top = newTop;
                  _right = newLeft + cropWidth;
                  _bottom = newTop + cropHeight;
                  break;
                default:
                  break;
              }
            });
            _notifyChange();
          },
          onPanEnd: (_) {
            _activeHandle = CropHandleType.none;
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: CropPainter(
                    left: _left,
                    top: _top,
                    right: _right,
                    bottom: _bottom,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CropPainter extends CustomPainter {
  final double left;
  final double top;
  final double right;
  final double bottom;

  CropPainter({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rectLeft = left * w;
    final rectTop = top * h;
    final rectRight = right * w;
    final rectBottom = bottom * h;

    final cropRect = Rect.fromLTRB(rectLeft, rectTop, rectRight, rectBottom);

    // 1. Paint transparent/shadowed background mask
    final maskPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Top block
    canvas.drawRect(Rect.fromLTRB(0, 0, w, rectTop), maskPaint);
    // Bottom block
    canvas.drawRect(Rect.fromLTRB(0, rectBottom, w, h), maskPaint);
    // Left block
    canvas.drawRect(Rect.fromLTRB(0, rectTop, rectLeft, rectBottom), maskPaint);
    // Right block
    canvas.drawRect(Rect.fromLTRB(rectRight, rectTop, w, rectBottom), maskPaint);

    // 2. Draw border
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(cropRect, borderPaint);

    // 3. Draw grid (3x3)
    final gridPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final cellW = cropRect.width / 3;
    final cellH = cropRect.height / 3;

    // Vertical grid lines
    canvas.drawLine(Offset(rectLeft + cellW, rectTop), Offset(rectLeft + cellW, rectBottom), gridPaint);
    canvas.drawLine(Offset(rectLeft + cellW * 2, rectTop), Offset(rectLeft + cellW * 2, rectBottom), gridPaint);

    // Horizontal grid lines
    canvas.drawLine(Offset(rectLeft, rectTop + cellH), Offset(rectRight, rectTop + cellH), gridPaint);
    canvas.drawLine(Offset(rectLeft, rectTop + cellH * 2), Offset(rectRight, rectTop + cellH * 2), gridPaint);

    // 4. Draw corner handles (thick L shapes)
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const len = 20.0;

    // Top Left
    canvas.drawLine(Offset(rectLeft - 2, rectTop), Offset(rectLeft + len, rectTop), cornerPaint);
    canvas.drawLine(Offset(rectLeft, rectTop - 2), Offset(rectLeft, rectTop + len), cornerPaint);

    // Top Right
    canvas.drawLine(Offset(rectRight + 2, rectTop), Offset(rectRight - len, rectTop), cornerPaint);
    canvas.drawLine(Offset(rectRight, rectTop - 2), Offset(rectRight, rectTop + len), cornerPaint);

    // Bottom Left
    canvas.drawLine(Offset(rectLeft - 2, rectBottom), Offset(rectLeft + len, rectBottom), cornerPaint);
    canvas.drawLine(Offset(rectLeft, rectBottom + 2), Offset(rectLeft, rectBottom - len), cornerPaint);

    // Bottom Right
    canvas.drawLine(Offset(rectRight + 2, rectBottom), Offset(rectRight - len, rectBottom), cornerPaint);
    canvas.drawLine(Offset(rectRight, rectBottom + 2), Offset(rectRight, rectBottom - len), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CropPainter oldDelegate) {
    return oldDelegate.left != left ||
        oldDelegate.top != top ||
        oldDelegate.right != right ||
        oldDelegate.bottom != bottom;
  }
}
