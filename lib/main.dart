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
  List<String> memes = [];
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

      final List<String> collected = [];
      for (final item in metaList) {
        if (item is Map<String, dynamic>) {
          // prefer an already-optimized local path, then thumb, then construct from url
          String? local = item['local'] as String?;
          String? thumb = item['thumb'] as String?;
          String? url = item['url'] as String?;

          if (local != null && local.isNotEmpty) {
            collected.add(local);
          } else if (thumb != null && thumb.isNotEmpty) {
            collected.add(thumb);
          } else if (url != null && url.isNotEmpty) {
            final basename = url.split('?')[0].split('/').last;
            collected.add('assets/memes/' + basename);
          }
        }
      }

      // filter to assets that are likely to exist and dedupe
      final seen = <String>{};
      final memePaths = <String>[];
      for (var p in collected) {
        if (!p.startsWith('assets/')) {
          p = p.replaceAll('\\', '/');
        }
        if (seen.add(p)) memePaths.add(p);
      }

      if (memePaths.isEmpty) {
        // fallback to scanning AssetManifest if metadata is missing or empty
        final manifestContent = await rootBundle.loadString(
          'AssetManifest.json',
        );
        final Map<String, dynamic> manifestMap = json.decode(manifestContent);
        final paths =
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
            memes = paths;
            isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          memes = memePaths;
          isLoading = false;
        });
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
            memes = memePaths;
            isLoading = false;
          });
        }
      } catch (e2) {
        debugPrint('Fallback AssetManifest error: $e2');
        if (mounted) {
          setState(() {
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
                  final memePath = memes[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MemeDetailScreen(assetPath: memePath),
                        ),
                      );
                    },
                    child: Hero(
                      tag: memePath,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          memePath,
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
  final List<String> memes;

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
    final results = memes.where((m) => m.contains(query)).toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final path = results[index];
        return ListTile(
          leading: SizedBox(
            width: 56,
            child: Image.asset(path, fit: BoxFit.cover),
          ),
          title: Text(path.split('/').last),
          onTap: () => close(context, path),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = query.isEmpty
        ? memes.take(20).toList()
        : memes.where((m) => m.contains(query)).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final path = suggestions[index];
        return ListTile(
          leading: SizedBox(
            width: 56,
            child: Image.asset(path, fit: BoxFit.cover),
          ),
          title: Text(path.split('/').last),
          onTap: () => close(context, path),
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
