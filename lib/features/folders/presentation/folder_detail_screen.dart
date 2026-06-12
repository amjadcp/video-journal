import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/storage/database.dart';
import 'package:video_journal/features/journal/presentation/asset_detail_screen.dart';
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
  }

  Future<void> _loadFolderAssets() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(journalRepositoryProvider);
      final assets = await repo.getAssetsInFolder(widget.folder.id);
      setState(() {
        _assets = assets;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load folder memories.')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        actions: [
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

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AssetDetailScreen(asset: asset),
                          ),
                        ).then((_) => _loadFolderAssets());
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
                                asset.autoTag,
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          if (isVideo)
                            const Center(
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.play_arrow, color: Colors.white, size: 18),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
