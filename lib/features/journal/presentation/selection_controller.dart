import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectionState {
  final bool isSelectionMode;
  final Set<String> selectedAssetIds;

  SelectionState({
    this.isSelectionMode = false,
    this.selectedAssetIds = const {},
  });

  SelectionState copyWith({
    bool? isSelectionMode,
    Set<String>? selectedAssetIds,
  }) {
    return SelectionState(
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedAssetIds: selectedAssetIds ?? this.selectedAssetIds,
    );
  }
}

class SelectionController extends StateNotifier<SelectionState> {
  SelectionController() : super(SelectionState());

  void enterSelectionMode(String initialAssetId) {
    state = SelectionState(
      isSelectionMode: true,
      selectedAssetIds: {initialAssetId},
    );
  }

  void exitSelectionMode() {
    state = SelectionState();
  }

  void toggleSelection(String assetId) {
    if (!state.isSelectionMode) return;
    final updated = Set<String>.from(state.selectedAssetIds);
    if (updated.contains(assetId)) {
      updated.remove(assetId);
      if (updated.isEmpty) {
        state = SelectionState();
      } else {
        state = state.copyWith(selectedAssetIds: updated);
      }
    } else {
      updated.add(assetId);
      state = state.copyWith(selectedAssetIds: updated);
    }
  }

  void selectAll(List<String> assetIds) {
    state = state.copyWith(
      isSelectionMode: true,
      selectedAssetIds: Set<String>.from(assetIds),
    );
  }
}

final selectionProvider = StateNotifierProvider<SelectionController, SelectionState>((ref) {
  return SelectionController();
});
