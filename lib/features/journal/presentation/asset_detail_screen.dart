import 'dart:io';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/storage/database.dart';
import 'package:video_journal/features/folders/presentation/folders_controller.dart';
import 'package:video_journal/features/journal/presentation/journal_controller.dart';
import 'package:video_journal/shared/enums/enums.dart';

class AssetDetailScreen extends ConsumerStatefulWidget {
  final VisualAssetData asset;

  const AssetDetailScreen({
    super.key,
    required this.asset,
  });

  @override
  ConsumerState<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends ConsumerState<AssetDetailScreen> {
  VideoPlayerController? _videoPlayerController;
  List<TagData> _tags = [];
  bool _isLoadingTags = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
    if (widget.asset.assetType == AssetType.video) {
      _initVideo();
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.file(File(widget.asset.localPath));
    _videoPlayerController = controller;
    await controller.initialize();
    controller.setLooping(true);
    controller.play();
    setState(() {});
  }

  Future<void> _loadTags() async {
    setState(() => _isLoadingTags = true);
    final repo = ref.read(journalRepositoryProvider);
    final tags = await repo.getTagsForAsset(widget.asset.id);
    setState(() {
      _tags = tags;
      _isLoadingTags = false;
    });
  }

  Future<void> _addTag() async {
    String name = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          autofocus: true,
          onChanged: (val) => name = val,
          decoration: const InputDecoration(hintText: 'Tag label'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Add'),
            onPressed: () async {
              if (name.trim().isNotEmpty) {
                final repo = ref.read(journalRepositoryProvider);
                final newTag = TagData(
                  id: const Uuid().v4(),
                  visualAssetId: widget.asset.id,
                  name: name.trim().toLowerCase(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await repo.addTag(newTag);
                Navigator.pop(context);
                _loadTags();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editOrDeleteTag(TagData tag) async {
    String name = tag.name;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Tag'),
        content: TextField(
          autofocus: true,
          controller: TextEditingController(text: tag.name),
          onChanged: (val) => name = val,
          decoration: const InputDecoration(hintText: 'Tag label'),
        ),
        actions: [
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              final repo = ref.read(journalRepositoryProvider);
              await repo.deleteTag(tag.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tag deleted.')),
                );
              }
              _loadTags();
            },
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () async {
              if (name.trim().isNotEmpty) {
                final repo = ref.read(journalRepositoryProvider);
                await repo.updateTag(tag.id, name.trim().toLowerCase());
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tag updated.')),
                  );
                }
                _loadTags();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _moveAsset() async {
    final foldersAsync = ref.read(foldersControllerProvider);
    final repo = ref.read(journalRepositoryProvider);

    foldersAsync.whenData((folders) {
      showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Move to Location',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.book, color: Colors.greenAccent),
                title: const Text('Home Journal'),
                onTap: () async {
                  final updatedAsset = widget.asset.copyWith(folderId: const Value(null));
                  await repo.updateAsset(updatedAsset);
                  ref.read(journalControllerProvider.notifier).loadAssets();
                  if (mounted) {
                    Navigator.pop(context); // Close sheet
                    Navigator.pop(context); // Return to home
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Memory moved to Home Journal.')),
                    );
                  }
                },
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return ListTile(
                      leading: const Icon(Icons.folder, color: Colors.orangeAccent),
                      title: Text(folder.name),
                      onTap: () async {
                        final updatedAsset = widget.asset.copyWith(folderId: Value(folder.id));
                        await repo.updateAsset(updatedAsset);
                        ref.read(journalControllerProvider.notifier).loadAssets();
                        if (mounted) {
                          Navigator.pop(context);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Memory moved to folder "${folder.name}".')),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _confirmDelete() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Memory?'),
        content: const Text('This memory will be removed from your device.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await ref.read(journalControllerProvider.notifier).deleteAsset(widget.asset.id);
              if (mounted) {
                Navigator.pop(context); // Return to home
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Memory deleted successfully.')),
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
    final isVideo = widget.asset.assetType == AssetType.video;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.drive_file_move_outlined),
            onPressed: _moveAsset,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: Column(
        children: [
          // Media Player / Preview Area
          Expanded(
            child: Center(
              child: isVideo
                  ? (_videoPlayerController != null && _videoPlayerController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoPlayerController!.value.aspectRatio,
                          child: VideoPlayer(_videoPlayerController!),
                        )
                      : const CircularProgressIndicator())
                  : Image.file(File(widget.asset.localPath)),
            ),
          ),

          // Metadata and Custom Tags Area
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? const Color(0xFF1E211F),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Auto Tag',
                            style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.asset.autoTag,
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.asset.syncStatus.name,
                            style: TextStyle(
                              color: widget.asset.syncStatus == SyncStatus.synced
                                  ? Colors.green
                                  : Colors.orangeAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Custom Tags',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: _addTag,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _isLoadingTags
                      ? const Center(child: LinearProgressIndicator())
                      : _tags.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'No tags added yet. Tap (+) to organize this memory.',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _tags.map((tag) {
                                return GestureDetector(
                                  onTap: () => _editOrDeleteTag(tag),
                                  child: Chip(
                                    label: Text(tag.name),
                                    deleteIcon: const Icon(Icons.edit, size: 14),
                                    onDeleted: () => _editOrDeleteTag(tag),
                                  ),
                                );
                              }).toList(),
                            ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
