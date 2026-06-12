import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_journal/features/folders/presentation/folders_controller.dart';
import 'package:video_journal/features/journal/presentation/journal_controller.dart';
import 'package:video_journal/shared/enums/enums.dart';

class FolderSelectorSheet extends ConsumerStatefulWidget {
  final String mediaPath;
  final AssetType mediaType;
  final bool selectOnly;

  const FolderSelectorSheet({
    super.key,
    required this.mediaPath,
    required this.mediaType,
    this.selectOnly = false,
  });

  @override
  ConsumerState<FolderSelectorSheet> createState() => _FolderSelectorSheetState();
}

class _FolderSelectorSheetState extends ConsumerState<FolderSelectorSheet> {
  bool _isSaving = false;

  Future<void> _saveToHome() async {
    if (widget.selectOnly) {
      Navigator.pop(context, {'id': null, 'name': 'Home Journal'});
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(journalControllerProvider.notifier).saveAssetToHomeList(
            mediaPath: widget.mediaPath,
            type: widget.mediaType,
          );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save to journal.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveToFolder(String folderId, String folderName) async {
    if (widget.selectOnly) {
      Navigator.pop(context, {'id': folderId, 'name': folderName});
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(journalControllerProvider.notifier).saveAssetToFolder(
            mediaPath: widget.mediaPath,
            type: widget.mediaType,
            folderId: folderId,
          );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save to folder.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
            child: Text(widget.selectOnly ? 'Create & Select' : 'Create & Save'),
            onPressed: () async {
              if (folderName.trim().isNotEmpty) {
                Navigator.pop(context); // close dialog
                setState(() => _isSaving = true);
                try {
                  final newFolder = await ref
                      .read(foldersControllerProvider.notifier)
                      .createFolder(folderName.trim());
                  if (widget.selectOnly) {
                    if (mounted) {
                      Navigator.pop(context, {'id': newFolder.id, 'name': newFolder.name});
                    }
                  } else {
                    await _saveToFolder(newFolder.id, newFolder.name);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to create folder.')),
                    );
                  }
                  setState(() => _isSaving = false);
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
            widget.selectOnly ? 'Select Destination' : 'Save Memory',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          _isSaving
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
                      title: const Text('Save to Home Journal'),
                      subtitle: const Text('Auto-tags with current timestamp'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _saveToHome,
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Save to a Folder:',
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
                                onTap: () => _saveToFolder(folder.id, folder.name),
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
