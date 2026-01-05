import 'dart:convert'; // Added for json decode
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const FiveHundredMemesApp());
}

class FiveHundredMemesApp extends StatelessWidget {
  const FiveHundredMemesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '500 Memes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      home: const MemeGridScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MemeGridScreen extends StatefulWidget {
  const MemeGridScreen({super.key});

  @override
  State<MemeGridScreen> createState() => _MemeGridScreenState();
}

class _MemeGridScreenState extends State<MemeGridScreen> {
  // Each entry: {'full': <full asset path>, 'thumb': <thumbnail path or null>, 'title': <title>}
  List<Map<String, String?>> memes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemes();
  }

  Future<void> _loadMemes() async {
    try {
      // Prefer using the curated metadata file if present
      final metaContent = await rootBundle.loadString('memes.json');
      final Map<String, dynamic> metaMap = json.decode(metaContent);
      final List<dynamic> metaList = metaMap['memes'] ?? [];

      final entries = <Map<String, String?>>[];
      for (final item in metaList) {
        if (item is Map<String, dynamic>) {
          final local = (item['local'] as String?)?.replaceAll('\\', '/');
          final thumb = (item['thumb'] as String?)?.replaceAll('\\', '/');
          final url = item['url'] as String?;
          final title = item['title'] as String? ?? '';

          String? fullPath;
          if (local != null && local.isNotEmpty) {
            fullPath = local;
          } else if (url != null && url.isNotEmpty) {
            final basename = url.split('?')[0].split('/').last;
            fullPath = 'assets/memes/$basename';
          }

          if (fullPath != null) {
            entries.add({'full': fullPath, 'thumb': thumb, 'title': title});
          }
        }
      }

      // dedupe while preserving order
      final seen = <String>{};
      final memePaths = <Map<String, String?>>[];
      for (var e in entries) {
        final key = e['full'] ?? e['thumb'] ?? e['title'] ?? '';
        if (key.isNotEmpty && seen.add(key)) memePaths.add(e);
      }

      // Load AssetManifest once so we can validate which metadata paths
      // actually exist in the bundled assets. This avoids attempting to load
      // assets that were never added to `flutter` (causing 404s on web).
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      final manifestKeys = manifestMap.keys.toSet();

      // Keep only entries whose `full` or `thumb` exists in the manifest.
      final validated = <Map<String, String?>>[];
      for (var e in memePaths) {
        final full = e['full'];
        final thumb = e['thumb'];
        if ((full != null && manifestKeys.contains(full)) ||
            (thumb != null && manifestKeys.contains(thumb))) {
          validated.add(e);
        }
      }

      if (validated.isEmpty) {
        // If none of the metadata entries map to actual bundled files,
        // fall back to using whatever is present in the AssetManifest.
        final paths =
            manifestMap.keys
                .where(
                  (String key) =>
                      key.startsWith('assets/memes/') &&
                      (key.endsWith('.png') ||
                          key.endsWith('.jpg') ||
                          key.endsWith('.jpeg') ||
                          key.endsWith('.webp') ||
                          key.endsWith('.gif')),
                )
                .toList()
              ..sort();

        debugPrint(
          'Loaded ${paths.length} memes from AssetManifest; sample: ${paths.take(5).toList()}',
        );
        if (mounted) {
          setState(() {
            memes = paths
                .map(
                  (p) => {'full': p, 'thumb': null, 'title': p.split('/').last},
                )
                .toList();
            isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          memes = validated.isNotEmpty ? validated : memePaths;
          isLoading = false;
        });
        debugPrint(
          'Loaded ${memePaths.length} memes from metadata; sample: ${memePaths.take(5).toList()}',
        );
      }
    } catch (e) {
      debugPrint('Error loading meme metadata: $e');
      // fallback: try the AssetManifest approach
      try {
        final manifestContent = await rootBundle.loadString(
          'AssetManifest.json',
        );
        final Map<String, dynamic> manifestMap = json.decode(manifestContent);

        final memePaths =
            manifestMap.keys
                .where(
                  (String key) =>
                      key.startsWith('assets/memes/') &&
                      (key.endsWith('.png') ||
                          key.endsWith('.jpg') ||
                          key.endsWith('.jpeg') ||
                          key.endsWith('.webp')),
                )
                .toList()
              ..sort();

        if (mounted) {
          setState(() {
            memes = memePaths
                .map(
                  (p) => {'full': p, 'thumb': null, 'title': p.split('/').last},
                )
                .toList();
            isLoading = false;
          });
        }
      } catch (e2) {
        debugPrint('Fallback AssetManifest error: $e2');
        // As a last resort (e.g. running on web where AssetManifest isn't
        // available), probe for numbered placeholder assets that exist in
        // the repo (meme_001.png, meme_002.png, ...).
        // Limit probing to avoid massive 404 spam in the browser console.
        final probed = <String>[];
        try {
          const maxProbe = 100; // keep this small to avoid noise
          const stopAfterFound = 60; // stop once we found a reasonable set
          for (var i = 1; i <= maxProbe; i++) {
            final padded = i.toString().padLeft(3, '0');
            final candidate = 'assets/memes/meme_$padded.png';
            try {
              await rootBundle.load(candidate);
              probed.add(candidate);
              if (probed.length >= stopAfterFound) break;
            } catch (_) {
              // ignore missing candidate
            }
          }

          // also probe a few non-padded names if nothing found yet
          if (probed.isEmpty) {
            for (var i = 1; i <= 50; i++) {
              final candidate = 'assets/memes/meme_$i.png';
              try {
                await rootBundle.load(candidate);
                probed.add(candidate);
                if (probed.length >= stopAfterFound) break;
              } catch (_) {}
            }
          }
        } catch (probeErr) {
          debugPrint('Probing assets failed: $probeErr');
        }

        if (mounted) {
          setState(() {
            if (probed.isNotEmpty) {
              memes = probed
                  .map(
                    (p) => {
                      'full': p,
                      'thumb': null,
                      'title': p.split('/').last,
                    },
                  )
                  .toList();
            }
            isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _refresh() async {
    await _loadMemes();
  }

  void _shuffle() {
    setState(() {
      memes.shuffle();
    });
  }

  void _openSearch() async {
    final result = await showSearch<String?>(
      context: context,
      delegate: MemeSearch(memes),
    );

    if (!mounted) return;
    if (result != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MemeDetailScreen(assetPath: result)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width ~/ 180).clamp(2, 6);

    return Scaffold(
      appBar: AppBar(
        title: Text(isLoading ? '500 Memes' : '500 Memes (${memes.length})'),
        actions: [
          IconButton(onPressed: _openSearch, icon: const Icon(Icons.search)),
          IconButton(onPressed: _shuffle, icon: const Icon(Icons.shuffle)),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: GridView.builder(
                padding: const EdgeInsets.all(12.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 12.0,
                  mainAxisSpacing: 12.0,
                ),
                itemCount: memes.length,
                itemBuilder: (context, index) {
                  final entry = memes[index];
                  final fullPath = entry['full'] ?? '';
                  final thumbPath = entry['thumb'] ?? fullPath;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MemeDetailScreen(assetPath: fullPath),
                        ),
                      );
                    },
                    child: Hero(
                      tag: fullPath,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          thumbPath,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class MemeSearch extends SearchDelegate<String?> {
  final List<Map<String, String?>> memes;

  MemeSearch(this.memes);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = memes
        .where(
          (m) => (m['title'] ?? m['full'] ?? '').toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final entry = results[index];
        final full = entry['full'] ?? '';
        final thumb = entry['thumb'] ?? full;
        final title = entry['title']?.isNotEmpty == true
            ? entry['title']!
            : full.split('/').last;

        return ListTile(
          leading: SizedBox(
            width: 56,
            child: Image.asset(thumb, fit: BoxFit.cover),
          ),
          title: Text(title),
          onTap: () => close(context, full),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestionEntries = query.isEmpty
        ? memes.take(20).toList()
        : memes
              .where(
                (m) => (m['title'] ?? m['full'] ?? '').toLowerCase().contains(
                  query.toLowerCase(),
                ),
              )
              .toList();

    return ListView.builder(
      itemCount: suggestionEntries.length,
      itemBuilder: (context, index) {
        final entry = suggestionEntries[index];
        final full = entry['full'] ?? '';
        final thumb = entry['thumb'] ?? full;
        final title = entry['title']?.isNotEmpty == true
            ? entry['title']!
            : full.split('/').last;

        return ListTile(
          leading: SizedBox(
            width: 56,
            child: Image.asset(thumb, fit: BoxFit.cover),
          ),
          title: Text(title),
          onTap: () => close(context, full),
        );
      },
    );
  }
}

class MemeDetailScreen extends StatelessWidget {
  final String assetPath;

  const MemeDetailScreen({super.key, required this.assetPath});

  Future<void> _shareMeme(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;

    try {
      final byteData = await rootBundle.load(assetPath);
      final list = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final fileName = assetPath.split('/').last;
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(list);

      final origin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : Rect.zero;

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Found this funny meme on 500 Memes app! 😂',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error sharing meme: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: Hero(
          tag: assetPath,
          child: Image.asset(assetPath, fit: BoxFit.contain),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _shareMeme(context),
        icon: const Icon(Icons.share),
        label: const Text('Share'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
    );
  }
}
