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
      final manifestContent = await DefaultAssetBundle.of(context).loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      
      final memePaths = manifestMap.keys
          .where((String key) => key.startsWith('assets/memes/') && 
                (key.endsWith('.png') || key.endsWith('.jpg') || key.endsWith('.jpeg')))
          .toList();
      
      // Sort to keep order if named sequentially, but not strictly required
      memePaths.sort();

      if (mounted) {
        setState(() {
          memes = memePaths;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading meme assets: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('500 Memes'),
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.0,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: memes.length,
        itemBuilder: (context, index) {
          final memePath = memes[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MemeDetailScreen(assetPath: memePath),
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
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MemeDetailScreen extends StatelessWidget {
  final String assetPath;

  const MemeDetailScreen({super.key, required this.assetPath});

  Future<void> _shareMeme(BuildContext context) async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      
      // Load asset
      final byteData = await rootBundle.load(assetPath);
      final list = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final fileName = assetPath.split('/').last;
      final file = File('${tempDir.path}/$fileName');
      
      await file.writeAsBytes(list);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Found this funny meme on 500 Memes app! 😂',
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
          ),
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
