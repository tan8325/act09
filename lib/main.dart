import 'package:flutter/material.dart';
import 'database_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CardOrganizerApp());
}

class CardOrganizerApp extends StatelessWidget {
  const CardOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card Organizer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const FoldersScreen(),
    );
  }
}

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
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
    
    folders = await dbHelper.getFolders();
    cardCounts = {};
    
    // Get card count for each folder
    for (var folder in folders) {
      int count = await dbHelper.getCardCountInFolder(folder['id']);
      cardCounts[folder['id']] = count;
    }
    
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Organizer'),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.0,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              final id = folder['id'];
              final count = cardCounts[id] ?? 0;
              
              return GestureDetector(
                onTap: () {
                  // Navigate to cards screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CardsScreen(
                        folderId: id,
                        folderName: folder['name'],
                      ),
                    ),
                  ).then((_) => loadFolders());
                },
                child: Card(
                  color: _getSuitColor(folder['name']),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _getSuitSymbol(folder['name']),
                        style: const TextStyle(fontSize: 40),
                      ),
                      Text(
                        folder['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('Cards: $count/6'),
                      if (count < 3)
                        const Text(
                          'Needs at least 3 cards',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  String _getSuitSymbol(String suit) {
    switch (suit) {
      case 'Hearts': return '♥️';
      case 'Diamonds': return '♦️';
      case 'Spades': return '♠️';
      case 'Clubs': return '♣️';
      default: return '?';
    }
  }

  Color _getSuitColor(String suit) {
    switch (suit) {
      case 'Hearts': 
      case 'Diamonds': 
        return Colors.red.shade100;
      case 'Spades': 
      case 'Clubs': 
        return Colors.grey.shade300;
      default: 
        return Colors.blue.shade100;
    }
  }
}

class CardsScreen extends StatefulWidget {
  final int folderId;
  final String folderName;

  const CardsScreen({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> cardsInFolder = [];
  List<Map<String, dynamic>> availableCards = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCards();
  }

  Future<void> loadCards() async {
    setState(() => isLoading = true);
    
    // Get cards in this folder
    cardsInFolder = await dbHelper.getCardsInFolder(widget.folderId);
    
    // Get available cards of this suit
    availableCards = await dbHelper.getAvailableCardsBySuit(widget.folderName);
    
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.folderName} Cards'),
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Cards in folder
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Cards in Folder (${cardsInFolder.length}/6)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              cardsInFolder.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('No cards in this folder'),
                  )
                : Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 5,
                        mainAxisSpacing: 5,
                      ),
                      itemCount: cardsInFolder.length,
                      itemBuilder: (context, index) {
                        final card = cardsInFolder[index];
                        return _buildCardItem(
                          card, 
                          canRemove: cardsInFolder.length > 3,
                          onAction: () => _removeCard(card['id']),
                          actionIcon: Icons.remove,
                          actionColor: Colors.red,
                        );
                      },
                    ),
                  ),
              
              const Divider(thickness: 2),
              
              // Available cards
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Available ${widget.folderName} Cards',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              availableCards.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('No available cards'),
                  )
                : Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 5,
                        mainAxisSpacing: 5,
                      ),
                      itemCount: availableCards.length,
                      itemBuilder: (context, index) {
                        final card = availableCards[index];
                        return _buildCardItem(
                          card, 
                          canRemove: true,
                          onAction: () => _addCard(card['id']),
                          actionIcon: Icons.add,
                          actionColor: Colors.green,
                        );
                      },
                    ),
                  ),
            ],
          ),
    );
  }

  Widget _buildCardItem(
    Map<String, dynamic> card, {
    required bool canRemove,
    required VoidCallback onAction,
    required IconData actionIcon,
    required Color actionColor,
  }) {
    return Card(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                _getCardEmoji(card['suit'], card['name']),
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              card['name'],
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (canRemove)
            IconButton(
              icon: Icon(actionIcon, color: actionColor),
              onPressed: onAction,
              iconSize: 20,
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  String _getCardEmoji(String suit, String name) {
    String symbol = '';
    switch (suit) {
      case 'Hearts': symbol = '♥️'; break;
      case 'Diamonds': symbol = '♦️'; break;
      case 'Spades': symbol = '♠️'; break;
      case 'Clubs': symbol = '♣️'; break;
      default: symbol = '?';
    }
    
    // Get first character of name for rank
    String rank = name.split(' ').first[0];
    return '$rank$symbol';
  }

  Future<void> _addCard(int cardId) async {
    // Check if folder has max cards (6)
    if (cardsInFolder.length >= 6) {
      _showMessage('This folder can only hold 6 cards');
      return;
    }
    
    // Add card to folder
    await dbHelper.addCardToFolder(cardId, widget.folderId);
    loadCards();
  }

  Future<void> _removeCard(int cardId) async {
    // Check if folder has min cards (3)
    if (cardsInFolder.length <= 3) {
      _showMessage('You need at least 3 cards in this folder');
      return;
    }
    
    // Remove card from folder
    await dbHelper.removeCardFromFolder(cardId);
    loadCards();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
