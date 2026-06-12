import 'package:flutter/material.dart';

class VideoTrimmer extends StatefulWidget {
  final double totalDurationSeconds;
  final Function(double start, double end) onTrimChanged;
  final VoidCallback? onTrimStart;
  final Function(double start, double end)? onTrimEnd;

  const VideoTrimmer({
    super.key,
    required this.totalDurationSeconds,
    required this.onTrimChanged,
    this.onTrimStart,
    this.onTrimEnd,
  });

  @override
  State<VideoTrimmer> createState() => _VideoTrimmerState();
}

class _VideoTrimmerState extends State<VideoTrimmer> {
  late RangeValues _currentRange;

  @override
  void initState() {
    super.initState();
    _currentRange = RangeValues(0.0, widget.totalDurationSeconds);
  }

  @override
  void didUpdateWidget(VideoTrimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalDurationSeconds != widget.totalDurationSeconds) {
      setState(() {
        _currentRange = RangeValues(0.0, widget.totalDurationSeconds);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.black.withOpacity(0.6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Start: ${_currentRange.start.toStringAsFixed(1)}s',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Text(
                'Trim Video',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                'End: ${_currentRange.end.toStringAsFixed(1)}s',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          RangeSlider(
            values: _currentRange,
            min: 0.0,
            max: widget.totalDurationSeconds,
            divisions: widget.totalDurationSeconds > 0 ? (widget.totalDurationSeconds * 10).toInt() : 1,
            activeColor: Colors.greenAccent,
            inactiveColor: Colors.white24,
            labels: RangeLabels(
              _currentRange.start.toStringAsFixed(1),
              _currentRange.end.toStringAsFixed(1),
            ),
            onChangeStart: (RangeValues values) {
              widget.onTrimStart?.call();
            },
            onChangeEnd: (RangeValues values) {
              widget.onTrimEnd?.call(values.start, values.end);
            },
            onChanged: (RangeValues values) {
              setState(() {
                // Ensure at least 1 second length is selected
                if (values.end - values.start >= 1.0) {
                  _currentRange = values;
                  widget.onTrimChanged(values.start, values.end);
                }
              });
            },
          ),
        ],
      ),
    );
  }
}
