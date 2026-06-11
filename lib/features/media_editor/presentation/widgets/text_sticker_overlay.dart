import 'package:flutter/material.dart';

class StickerData {
  final String id;
  final String text;
  final Color color;
  final bool isEmoji;
  Offset position;
  double scale;

  StickerData({
    required this.id,
    required this.text,
    required this.color,
    required this.isEmoji,
    required this.position,
    this.scale = 1.0,
  });
}

class TextStickerOverlay extends StatefulWidget {
  final List<StickerData> stickers;
  final Function(String id, Offset newPos, double newScale) onUpdateSticker;
  final Function(String id) onDeleteSticker;

  const TextStickerOverlay({
    super.key,
    required this.stickers,
    required this.onUpdateSticker,
    required this.onDeleteSticker,
  });

  @override
  State<TextStickerOverlay> createState() => _TextStickerOverlayState();
}

class _TextStickerOverlayState extends State<TextStickerOverlay> {
  String? _activeStickerId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: widget.stickers.map((sticker) {
        final isSelected = _activeStickerId == sticker.id;

        return Positioned(
          left: sticker.position.dx,
          top: sticker.position.dy,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _activeStickerId = isSelected ? null : sticker.id;
              });
            },
            onPanUpdate: (details) {
              setState(() {
                sticker.position += details.delta;
              });
              widget.onUpdateSticker(sticker.id, sticker.position, sticker.scale);
            },
            onScaleUpdate: (details) {
              setState(() {
                sticker.scale = (sticker.scale * details.scale).clamp(0.5, 4.0);
              });
              widget.onUpdateSticker(sticker.id, sticker.position, sticker.scale);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: isSelected
                  ? BoxDecoration(
                      border: Border.all(color: Colors.greenAccent, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: sticker.scale,
                    child: Text(
                      sticker.text,
                      style: TextStyle(
                        color: sticker.color,
                        fontSize: sticker.isEmoji ? 36 : 24,
                        fontWeight: sticker.isEmoji ? FontWeight.normal : FontWeight.bold,
                        shadows: const [
                          Shadow(
                            blurRadius: 4.0,
                            color: Colors.black45,
                            offset: Offset(1.0, 1.0),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isSelected)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                      onPressed: () => widget.onDeleteSticker(sticker.id),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
