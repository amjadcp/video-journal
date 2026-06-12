import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/storage/database.dart';
import 'package:video_journal/features/camera/presentation/camera_screen.dart';
import 'package:video_journal/features/folders/presentation/folder_detail_screen.dart';
import 'package:video_journal/features/folders/presentation/folders_controller.dart';
import 'package:video_journal/features/folders/presentation/move_selector_sheet.dart';
import 'package:video_journal/features/journal/presentation/asset_detail_screen.dart';
import 'package:video_journal/features/journal/presentation/journal_controller.dart';
import 'package:video_journal/features/journal/presentation/search_screen.dart';
import 'package:video_journal/features/journal/presentation/selection_controller.dart';
import 'package:video_journal/features/settings/presentation/settings_screen.dart';
import 'package:video_journal/shared/enums/enums.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showCreateFolderDialog(BuildContext context, WidgetRef ref) {
    String folderName = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          autofocus: true,
          onChanged: (val) => folderName = val,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Create'),
            onPressed: () {
              if (folderName.trim().isNotEmpty) {
                ref.read(foldersControllerProvider.notifier).createFolder(folderName.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Folder created successfully.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRenameFolderDialog(BuildContext context, WidgetRef ref, FolderData folder) {
    final textController = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Rename'),
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty && newName != folder.name) {
                ref.read(foldersControllerProvider.notifier).renameFolder(folder.id, newName);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Folder renamed successfully.')),
                );
              } else if (newName.isEmpty) {
                // Ignore empty
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderDialog(BuildContext context, WidgetRef ref, FolderData folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
          'Are you sure you want to delete "${folder.name}"? '
          'Memories inside this folder will not be deleted, they will just be moved to the Home Journal list.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              ref.read(foldersControllerProvider.notifier).deleteFolder(folder.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Folder deleted successfully.')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showFolderOptions(BuildContext context, WidgetRef ref, FolderData folder) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  folder.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blueAccent),
                title: const Text('Rename Folder'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameFolderDialog(context, ref, folder);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Delete Folder'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteFolderDialog(context, ref, folder);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMoveAssetsSheet(BuildContext context, WidgetRef ref, List<String> assetIds) {
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
      }
    });
  }

  void _confirmDeleteAssets(BuildContext context, WidgetRef ref, List<String> assetIds) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsState = ref.watch(journalControllerProvider);
    final foldersState = ref.watch(foldersControllerProvider);
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.valueOrNull;

    final selectionState = ref.watch(selectionProvider);
    final isSelectionMode = selectionState.isSelectionMode;
    final firstTags = ref.watch(firstTagsProvider).valueOrNull ?? {};

    return PopScope(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(selectionProvider.notifier).exitSelectionMode();
      },
      child: DefaultTabController(
        length: 2,
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
                : const Text('Photo & Video Journal App'),
            actions: isSelectionMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.select_all),
                      tooltip: 'Select All',
                      onPressed: () {
                        assetsState.whenData((assets) {
                          ref.read(selectionProvider.notifier).selectAll(assets.map((a) => a.id).toList());
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.drive_file_move),
                      tooltip: 'Move to Folder',
                      onPressed: () => _showMoveAssetsSheet(context, ref, selectionState.selectedAssetIds.toList()),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Delete Selected',
                      onPressed: () => _confirmDeleteAssets(context, ref, selectionState.selectedAssetIds.toList()),
                    ),
                  ]
                : [
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SearchScreen()),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      ),
                    ),
                  ],
            bottom: isSelectionMode
                ? null
                : TabBar(
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.folder_outlined),
                        text: 'Folders',
                      ),
                      Tab(
                        icon: Icon(Icons.photo_library_outlined),
                        text: 'Recent Memories',
                      ),
                    ],
                  ),
          ),
          body: Column(
            children: [
              // Backup Status Indicator banner (only shown if not authenticated and not in selection mode)
              if (currentUser == null && !isSelectionMode)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_queue, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cloud Backup',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Connect Google Drive to back up memories.',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsScreen()),
                        ),
                        child: const Text('Connect'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  physics: isSelectionMode
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  children: [
                    // Tab 1: Folders
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'All Folders',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              TextButton.icon(
                                onPressed: () => _showCreateFolderDialog(context, ref),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('New Folder'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: foldersState.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (err, stack) => Center(child: Text('Error: $err')),
                            data: (folders) {
                              if (folders.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No folders yet.',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                );
                              }
                              return GridView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.25,
                                ),
                                itemCount: folders.length,
                                itemBuilder: (context, index) {
                                  final folder = folders[index];
                                  return Card(
                                    clipBehavior: Clip.antiAlias,
                                    margin: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: Theme.of(context).dividerColor.withOpacity(0.08),
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FolderDetailScreen(folder: folder),
                                          ),
                                        );
                                      },
                                      onLongPress: () => _showFolderOptions(context, ref, folder),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: Colors.orangeAccent,
                                                  child: Icon(Icons.folder, color: Colors.white, size: 18),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.more_vert, size: 20),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  onPressed: () => _showFolderOptions(context, ref, folder),
                                                ),
                                              ],
                                            ),
                                            const Spacer(),
                                            Text(
                                              folder.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${folder.sequenceCounter} items',
                                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    // Tab 2: Recent Memories
                    assetsState.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text('Error loading journal: $err')),
                      data: (assets) {
                        if (assets.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'Your journal is empty.\nTap the camera button below to save your first memory!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: assets.length,
                          itemBuilder: (context, index) {
                            final asset = assets[index];
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
                                  ).then((_) {
                                    ref.read(journalControllerProvider.notifier).loadAssets();
                                  });
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
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: isSelectionMode
              ? null
              : FloatingActionButton(
                  onPressed: () {
                    Navigator.push(context, CameraScreen.route()).then((_) {
                      ref.read(journalControllerProvider.notifier).loadAssets();
                    });
                  },
                  child: const Icon(Icons.camera_alt),
                ),
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
