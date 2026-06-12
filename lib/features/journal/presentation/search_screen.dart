import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/storage/database.dart';
import 'package:video_journal/features/journal/presentation/asset_detail_screen.dart';
import 'package:video_journal/features/journal/presentation/journal_controller.dart';
import 'package:video_journal/shared/enums/enums.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<VisualAssetData> _searchResults = [];
  bool _isSearching = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final repo = ref.read(journalRepositoryProvider);
      final results = await repo.searchAssetsByTag(query.trim().toLowerCase());
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to search tags.')),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firstTags = ref.watch(firstTagsProvider).valueOrNull ?? {};
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by tag name...',
            border: InputBorder.none,
            filled: false,
          ),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
              ),
          onChanged: _performSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _performSearch('');
              },
            ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty
              ? Center(
                  child: Text(
                    _searchController.text.isEmpty
                        ? 'Type a tag above to start searching'
                        : 'No matching memories found',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final asset = _searchResults[index];
                    final isVideo = asset.assetType == AssetType.video;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AssetDetailScreen(asset: asset),
                          ),
                        ).then((_) {
                          // Refresh search if query is still active
                          _performSearch(_searchController.text);
                        });
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
