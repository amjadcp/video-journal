import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/storage/database.dart';
import 'package:video_journal/features/folders/presentation/move_selector_sheet.dart';
import 'package:video_journal/features/journal/presentation/asset_detail_screen.dart';
import 'package:video_journal/features/journal/presentation/journal_controller.dart';
import 'package:video_journal/features/journal/presentation/selection_controller.dart';
import 'package:video_journal/shared/enums/enums.dart';

class FolderDetailScreen extends ConsumerStatefulWidget {
  final FolderData folder;

  const FolderDetailScreen({
    super.key,
    required this.folder,
  });

  @override
  ConsumerState<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends ConsumerState<FolderDetailScreen> {
  List<VisualAssetData> _assets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFolderAssets();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectionProvider.notifier).exitSelectionMode();
    });
  }

  @override
  void dispose() {
    ref.read(selectionProvider.notifier).exitSelectionMode();
    super.dispose();
  }

  Future<void> _loadFolderAssets() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(journalRepositoryProvider);
      final assets = await repo.getAssetsInFolder(widget.folder.id);
      if (mounted) {
        setState(() {
          _assets = assets;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load folder memories.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMoveAssetsSheet(BuildContext context, List<String> assetIds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      builder: (context) => MoveSelectorSheet(assetIds: assetIds),
    ).then((success) {
      if (success == true) {
        ref.read(selectionProvider.notifier).exitSelectionMode();
        _loadFolderAssets();
      }
    });
  }

  void _confirmDeleteAssets(BuildContext context, List<String> assetIds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Memories'),
        content: Text(
          'Are you sure you want to delete ${assetIds.length} selected memories? '
          'This will permanently delete local files and their cloud copies (if enabled).',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            onPressed: () async {
              Navigator.pop(context); // close dialog
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(width: 16),
                      Text('Deleting memories...'),
                    ],
                  ),
                  duration: Duration(days: 1),
                ),
              );
              try {
                await ref.read(journalControllerProvider.notifier).deleteAssets(assetIds);
                ref.read(selectionProvider.notifier).exitSelectionMode();
                scaffoldMessenger.hideCurrentSnackBar();
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Deleted ${assetIds.length} memories.')),
                );
                _loadFolderAssets();
              } catch (e) {
                scaffoldMessenger.hideCurrentSnackBar();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Failed to delete memories.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectionState = ref.watch(selectionProvider);
    final isSelectionMode = selectionState.isSelectionMode;
    final firstTags = ref.watch(firstTagsProvider).valueOrNull ?? {};

    return PopScope(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(selectionProvider.notifier).exitSelectionMode();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: isSelectionMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => ref.read(selectionProvider.notifier).exitSelectionMode(),
                )
              : null,
          title: isSelectionMode
              ? Text('${selectionState.selectedAssetIds.length} selected')
              : Text(widget.folder.name),
          actions: isSelectionMode
              ? [
                  IconButton(
                    icon: const Icon(Icons.select_all),
                    tooltip: 'Select All',
                    onPressed: () {
                      ref.read(selectionProvider.notifier).selectAll(_assets.map((a) => a.id).toList());
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.drive_file_move),
                    tooltip: 'Move to Folder',
                    onPressed: () => _showMoveAssetsSheet(context, selectionState.selectedAssetIds.toList()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Delete Selected',
                    onPressed: () => _confirmDeleteAssets(context, selectionState.selectedAssetIds.toList()),
                  ),
                ]
              : [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadFolderAssets,
                  ),
                ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _assets.isEmpty
                ? const Center(
                    child: Text(
                      'No memories saved in this folder yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _assets.length,
                    itemBuilder: (context, index) {
                      final asset = _assets[index];
                      final isVideo = asset.assetType == AssetType.video;
                      final isSelected = selectionState.selectedAssetIds.contains(asset.id);

                      return GestureDetector(
                        onTap: () {
                          if (isSelectionMode) {
                            ref.read(selectionProvider.notifier).toggleSelection(asset.id);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => AssetDetailScreen(asset: asset),
                              ),
                            ).then((_) => _loadFolderAssets());
                          }
                        },
                        onLongPress: () {
                          if (!isSelectionMode) {
                            ref.read(selectionProvider.notifier).enterSelectionMode(asset.id);
                          } else {
                            ref.read(selectionProvider.notifier).toggleSelection(asset.id);
                          }
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(asset.thumbnailPath),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[900],
                                    child: Center(
                                      child: Icon(
                                        isVideo ? Icons.videocam : Icons.image,
                                        color: Colors.white24,
                                        size: 28,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (_getTagToDisplay(asset, firstTags).isNotEmpty)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _getTagToDisplay(asset, firstTags),
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            if (isVideo && !isSelectionMode)
                              const Center(
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.play_arrow, color: Colors.white, size: 18),
                                ),
                              ),
                            if (isSelectionMode)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black45,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    isSelected ? Icons.check : null,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

bool _isBooleanValue(String val) {
  final lower = val.trim().toLowerCase();
  return lower == 'true' || lower == 'false' || lower == '1' || lower == '0';
}

String _getTagToDisplay(VisualAssetData asset, Map<String, String> firstTags) {
  if (asset.autoTag.isEmpty || _isBooleanValue(asset.autoTag)) {
    return firstTags[asset.id] ?? '';
  }
  return asset.autoTag;
}
