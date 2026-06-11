import 'package:flutter/material.dart';

enum PhotoFilter {
  none('Original', [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  grayscale('Grayscale', [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]),
  sepia('Sepia', [
    0.393, 0.769, 0.189, 0, 0,
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0,     0,     0,     1, 0,
  ]),
  vintage('Vintage', [
    0.9, 0,   0,   0, 0,
    0,   0.8, 0,   0, 0,
    0,   0,   0.6, 0, 0,
    0,   0,   0,   1, 0,
  ]),
  cool('Cool', [
    0.7, 0,   0,   0, 0,
    0,   0.9, 0,   0, 0,
    0,   0,   0.9, 0, 0,
    0,   0,   0,   1, 0,
  ]);

  final String label;
  final List<double> matrix;

  const PhotoFilter(this.label, this.matrix);
}

class FilterSelector extends StatelessWidget {
  final PhotoFilter selectedFilter;
  final Function(PhotoFilter filter) onFilterChanged;

  const FilterSelector({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      color: Colors.black.withOpacity(0.6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: PhotoFilter.values.length,
        itemBuilder: (context, index) {
          final filter = PhotoFilter.values[index];
          final isSelected = filter == selectedFilter;

          return GestureDetector(
            onTap: () => onFilterChanged(filter),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.greenAccent.withOpacity(0.25) : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.greenAccent : Colors.transparent,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                filter.label,
                style: TextStyle(
                  color: isSelected ? Colors.greenAccent : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
