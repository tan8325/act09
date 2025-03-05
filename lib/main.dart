import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:flutter_svg/flutter_svg.dart';

final Map<String, SvgPicture> _svgCache = {};

void main() => runApp(const CardOrganizerApp());

class CardOrganizerApp extends StatelessWidget {
  const CardOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card Organizer',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const FoldersScreen(),
    );
  }
}

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  _FoldersScreenState createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> folders = [];
  Map<int, int> cardCounts = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadFolders();
  }

  Future<void> loadFolders() async {
    setState(() => isLoading = true);
    try {
      folders = await dbHelper.getFolders();
      cardCounts = {
        for (var folder in folders)
          folder['id']: await dbHelper.getCardCountInFolder(folder['id']),
      };
      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      print('Error loading folders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Card Organizer')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                final count = cardCounts[folder['id']] ?? 0;
                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CardsScreen(
                          folderId: folder['id'],
                          folderName: folder['name'],
                        ),
                      ),
                    );
                    loadFolders();
                  },
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (count > 0)
                            FutureBuilder<String>(
                              future: dbHelper.getFirstCardImage(folder['id']),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const CircularProgressIndicator();
                                }
                                if (snapshot.hasError) {
                                  return const Icon(Icons.error);
                                }
                                if (_svgCache.containsKey(snapshot.data!)) {
                                  return _svgCache[snapshot.data!]!;
                                } else {
                                  final picture = SvgPicture.network(
                                    snapshot.data!,
                                    width: 80,
                                    height: 80,
                                    placeholderBuilder: (context) => const CircularProgressIndicator(),
                                  );
                                  _svgCache[snapshot.data!] = picture;
                                  return picture;
                                }
                              },
                            ),
                          if (count == 0) const Icon(Icons.image, size: 80, color: Colors.grey),
                          const SizedBox(height: 10),
                          Text('Cards: $count/6'),
                          if (count < 3)
                            const Text('Needs at least 3 cards',
                                style: TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class CardsScreen extends StatefulWidget {
  final int folderId;
  final String folderName;

  const CardsScreen({super.key, required this.folderId, required this.folderName});

  @override
  _CardsScreenState createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> cardsInFolder = [];
  List<Map<String, dynamic>> availableCards = [];
  bool isLoading = true;
  Set<int> selectedCards = {};

  @override
  void initState() {
    super.initState();
    loadCards();
  }

  Future<void> loadCards() async {
    setState(() => isLoading = true);
    try {
      cardsInFolder = await dbHelper.getCardsInFolder(widget.folderId);
      availableCards = await dbHelper.getAvailableCardsBySuit(widget.folderName);
      selectedCards = cardsInFolder.map((card) => card['id'] as int).toSet();
      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      print('Error loading cards: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.folderName} Cards')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildSection('Cards in Folder', cardsInFolder, _removeCard),
                  _buildSection('Available ${widget.folderName} Cards', availableCards, _addCard),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> cards, Future<void> Function(int) onCardAction) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (cards.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('No cards available'),
            ),
          GridView.builder(
            padding: const EdgeInsets.all(10),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              final isSelected = selectedCards.contains(card['id']);
              return Card(
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.network(
                        card['imageUrl'],
                        width: 80,
                        height: 80,
                        placeholderBuilder: (context) => const CircularProgressIndicator(),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildActionButton(card['id'], isSelected, onCardAction),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(int cardId, bool isSelected, Future<void> Function(int) onCardAction) {
    return IconButton(
      onPressed: () async {
        await onCardAction(cardId);
      },
      icon: Icon(
        isSelected ? Icons.remove : Icons.add,
        color: isSelected ? Colors.red : Colors.green,
      ),
      iconSize: 15,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Future<void> _addCard(int cardId) async {
    final result = await dbHelper.addCardToFolder(cardId, widget.folderId);
    if (result == -1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum cards reached (6)!'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    loadCards();
  }

  Future<void> _removeCard(int cardId) async {
    await dbHelper.removeCardFromFolder(cardId);
    loadCards();
  }
}
