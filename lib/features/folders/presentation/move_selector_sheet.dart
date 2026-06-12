import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_journal/features/folders/presentation/folders_controller.dart';
import 'package:video_journal/features/journal/presentation/journal_controller.dart';

class MoveSelectorSheet extends ConsumerStatefulWidget {
  final List<String> assetIds;

  const MoveSelectorSheet({
    super.key,
    required this.assetIds,
  });

  @override
  ConsumerState<MoveSelectorSheet> createState() => _MoveSelectorSheetState();
}

class _MoveSelectorSheetState extends ConsumerState<MoveSelectorSheet> {
  bool _isMoving = false;

  Future<void> _moveToHome() async {
    setState(() => _isMoving = true);
    try {
      await ref.read(journalControllerProvider.notifier).moveAssetsToFolder(
            widget.assetIds,
            null,
          );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to move memories.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isMoving = false);
    }
  }

  Future<void> _moveToFolder(String folderId) async {
    setState(() => _isMoving = true);
    try {
      await ref.read(journalControllerProvider.notifier).moveAssetsToFolder(
            widget.assetIds,
            folderId,
          );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to move memories.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isMoving = false);
    }
  }

  void _showCreateFolderDialog() {
    String folderName = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Folder'),
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
            child: const Text('Create & Move'),
            onPressed: () async {
              if (folderName.trim().isNotEmpty) {
                Navigator.pop(context); // close dialog
                setState(() => _isMoving = true);
                try {
                  final newFolder = await ref
                      .read(foldersControllerProvider.notifier)
                      .createFolder(folderName.trim());
                  await _moveToFolder(newFolder.id);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to create folder.')),
                    );
                  }
                  setState(() => _isMoving = false);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foldersState = ref.watch(foldersControllerProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Move Memories',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          _isMoving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.greenAccent,
                        child: Icon(Icons.book, color: Colors.black),
                      ),
                      title: const Text('Move to Home Journal'),
                      subtitle: const Text('Remove from all folders'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _moveToHome,
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Move to a Folder:',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        TextButton.icon(
                          onPressed: _showCreateFolderDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New Folder'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: foldersState.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(child: Text('Error loading folders: $err')),
                        data: (folders) {
                          if (folders.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No folders created yet.\nTap "New Folder" to create one.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: folders.length,
                            itemBuilder: (context, index) {
                              final folder = folders[index];
                              return ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.orangeAccent,
                                  child: Icon(Icons.folder, color: Colors.white),
                                ),
                                title: Text(folder.name),
                                subtitle: Text('${folder.sequenceCounter} items'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _moveToFolder(folder.id),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}
