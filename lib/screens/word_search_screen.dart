import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'dart:math';
import 'dart:async';

class WordSearchScreen extends StatefulWidget {
  const WordSearchScreen({super.key});

  @override
  State<WordSearchScreen> createState() => _WordSearchScreenState();
}

class _WordSearchScreenState extends State<WordSearchScreen> {
  // Game Constants
  static const int GRID_SIZE = 12;
  static const List<String> WORD_BANK = [
    "APPLE",
    "BANANA",
    "CHERRY",
    "GRAPE",
    "LEMON",
    "ORANGE",
    "PEACH",
    "KIWI",
    "MELON",
    "BERRY",
    "MANGO",
    "PAPAYA",
    "GUAVA",
    "LYCHEE",
    "COCONUT",
    "PINEAPPLE",
    "RASPBERRY",
    "BLUEBERRY",
    "STRAWBERRY",
    "WATERMELON",
    "APRICOT",
    "FIG",
    "PLUM",
    "DATE",
    "OLIVE",
    "LIME",
    "POMEGRANATE",
    "DRAGONFRUIT",
    "TIGER",
    "LION",
    "ELEPHANT",
    "GIRAFFE",
    "ZEBRA",
    "MONKEY",
    "KANGAROO",
    "PANDA",
    "BEAR",
    "WOLF",
    "FOX",
    "DEER",
    "RABBIT",
    "SQUIRREL",
    "DOLPHIN",
    "WHALE",
    "SHARK",
    "OCTOPUS",
    "CRAB",
    "EAGLE",
    "HAWK",
    "OWL",
    "PARROT",
    "PIGEON",
    "SPARROW",
    "CROW",
    "RAVEN",
    "FLAMINGO",
    "PELICAN"
  ];

  static const List<List<int>> DIRECTIONS = [
    [0, 1],
    [0, -1],
    [1, 0],
    [-1, 0],
    [1, 1],
    [1, -1],
    [-1, 1],
    [-1, -1]
  ];

  // Game State
  late List<List<String>> grid;
  late List<String> currentWords;
  late Map<String, List<List<int>>> wordPositions;
  Set<String> foundWords = {};
  Set<String> foundCells = {};
  bool isGameWon = false;
  bool isSolving = false;
  bool isLoading = false;

  // Selection State
  List<CellPosition> selectedCells = [];
  CellPosition? startCell;
  CellPosition? endCell;
  bool isSelecting = false;

  // Timer & Random
  final Random _random = Random();
  Timer? _hintTimer;

  // ===== UNITY ADS CONFIG =====
  static const String _gameId = '800107168';
  static const bool _testMode = false;
  static const String _bannerPlacementId = 'Banner_Android';
  static const String _interstitialPlacementId = 'Interstitial_Android';
  static const String _rewardedPlacementId = 'Rewarded_Android';

  bool _unityInitialized = false;
  bool _interstitialReady = false;
  bool _rewardedReady = false;

  // ============================================================
  // LIFECYCLE
  // ============================================================
  @override
  void initState() {
    super.initState();
    _loadNewGame();
    _initAds();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // UNITY ADS
  // ============================================================
  Future<void> _initAds() async {
    await UnityAds.init(
      gameId: _gameId,
      testMode: _testMode,
      onComplete: () {
        debugPrint('✅ Unity Ads initialized successfully!');
        if (mounted) setState(() => _unityInitialized = true);
        _loadInterstitial();
        _loadRewarded();
      },
      onFailed: (error, message) {
        debugPrint('❌ Ad init error: $error $message');
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && !_unityInitialized) _initAds();
        });
      },
    );
  }

  void _loadInterstitial() {
    UnityAds.load(
      placementId: _interstitialPlacementId,
      onComplete: (placementId) {
        debugPrint('Interstitial loaded: $placementId');
        if (mounted) setState(() => _interstitialReady = true);
      },
      onFailed: (placementId, error, message) {
        debugPrint('Interstitial load failed: $error $message');
        if (mounted) setState(() => _interstitialReady = false);
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && !_interstitialReady) _loadInterstitial();
        });
      },
    );
  }

  void _loadRewarded() {
    UnityAds.load(
      placementId: _rewardedPlacementId,
      onComplete: (placementId) {
        debugPrint('Rewarded loaded: $placementId');
        if (mounted) setState(() => _rewardedReady = true);
      },
      onFailed: (placementId, error, message) {
        debugPrint('Rewarded load failed: $error $message');
        if (mounted) setState(() => _rewardedReady = false);
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && !_rewardedReady) _loadRewarded();
        });
      },
    );
  }

  Future<bool> _waitForAdReady(bool Function() isReady,
      {int timeoutMs = 4000}) async {
    final start = DateTime.now();
    while (!isReady() &&
        DateTime.now().difference(start).inMilliseconds < timeoutMs) {
      await Future.delayed(const Duration(milliseconds: 250));
    }
    return isReady();
  }

  Future<void> _showInterstitial() async {
    if (isLoading) return;

    if (!_unityInitialized || !_interstitialReady) {
      setState(() => isLoading = true);
      _loadInterstitial();
      final ready =
          await _waitForAdReady(() => _interstitialReady, timeoutMs: 2500);
      if (mounted) setState(() => isLoading = false);
      if (!ready) {
        if (mounted) Navigator.pop(context);
        return;
      }
    }

    setState(() => isLoading = true);

    void finishAndLeave() {
      if (mounted) {
        setState(() {
          isLoading = false;
          _interstitialReady = false;
        });
      }
      _loadInterstitial();
      if (mounted) Navigator.pop(context);
    }

    UnityAds.showVideoAd(
      placementId: _interstitialPlacementId,
      onStart: (placementId) =>
          debugPrint('Interstitial started: $placementId'),
      onClick: (placementId) =>
          debugPrint('Interstitial clicked: $placementId'),
      onSkipped: (placementId) => finishAndLeave(),
      onComplete: (placementId) => finishAndLeave(),
      onFailed: (placementId, error, message) {
        debugPrint('Interstitial show failed: $error $message');
        finishAndLeave();
      },
    );
  }

  Future<void> _showRewardedForHint() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    if (!_unityInitialized || !_rewardedReady) {
      _loadRewarded();
      final ready = await _waitForAdReady(() => _rewardedReady);
      if (!ready) {
        if (mounted) setState(() => isLoading = false);
        _activateHint();
        return;
      }
    }

    UnityAds.showVideoAd(
      placementId: _rewardedPlacementId,
      onStart: (placementId) => debugPrint('Rewarded started: $placementId'),
      onClick: (placementId) => debugPrint('Rewarded clicked: $placementId'),
      onSkipped: (placementId) {
        if (mounted) {
          setState(() {
            isLoading = false;
            _rewardedReady = false;
          });
        }
        _loadRewarded();
      },
      onComplete: (placementId) {
        if (mounted) {
          setState(() {
            isLoading = false;
            _rewardedReady = false;
          });
        }
        _loadRewarded();
        _activateHint();
        _showSnackBar('🎉 You earned a hint!');
      },
      onFailed: (placementId, error, message) {
        debugPrint('Rewarded show failed: $error $message');
        if (mounted) {
          setState(() {
            isLoading = false;
            _rewardedReady = false;
          });
        }
        _loadRewarded();
        _activateHint();
      },
    );
  }

  Future<void> _showRewardedForSolve() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    if (!_unityInitialized || !_rewardedReady) {
      _loadRewarded();
      final ready = await _waitForAdReady(() => _rewardedReady);
      if (!ready) {
        if (mounted) setState(() => isLoading = false);
        await _solvePuzzle();
        return;
      }
    }

    UnityAds.showVideoAd(
      placementId: _rewardedPlacementId,
      onStart: (placementId) => debugPrint('Rewarded started: $placementId'),
      onClick: (placementId) => debugPrint('Rewarded clicked: $placementId'),
      onSkipped: (placementId) {
        if (mounted) {
          setState(() {
            isLoading = false;
            _rewardedReady = false;
          });
        }
        _loadRewarded();
      },
      onComplete: (placementId) {
        if (mounted) {
          setState(() {
            isLoading = false;
            _rewardedReady = false;
          });
        }
        _loadRewarded();
        _solvePuzzle();
        _showSnackBar('🎉 You earned a full solve!');
      },
      onFailed: (placementId, error, message) {
        debugPrint('Rewarded show failed: $error $message');
        if (mounted) {
          setState(() {
            isLoading = false;
            _rewardedReady = false;
          });
        }
        _loadRewarded();
        _solvePuzzle();
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF3a2a1a),
      ),
    );
  }

  // ============================================================
  // GAME LOGIC
  // ============================================================
  void _loadNewGame() {
    setState(() {
      isGameWon = false;
      isSolving = false;
      foundWords.clear();
      foundCells.clear();
      selectedCells.clear();
      startCell = null;
      endCell = null;
      isSelecting = false;
      _generatePuzzle();
    });
  }

  void _resetGame() {
    setState(() {
      isGameWon = false;
      isSolving = false;
      foundWords.clear();
      foundCells.clear();
      selectedCells.clear();
      startCell = null;
      endCell = null;
      isSelecting = false;
    });
  }

  void _generatePuzzle() {
    final shuffled = List<String>.from(WORD_BANK)..shuffle();
    final selectedWords = <String>[];
    for (int i = 0; i < 10 && i < shuffled.length; i++) {
      if (!selectedWords.contains(shuffled[i])) {
        selectedWords.add(shuffled[i]);
      }
    }

    while (selectedWords.length < 8) {
      final extra = WORD_BANK[_random.nextInt(WORD_BANK.length)];
      if (!selectedWords.contains(extra)) {
        selectedWords.add(extra);
      }
    }

    final newGrid = List.generate(GRID_SIZE, (_) => List.filled(GRID_SIZE, ''));
    final positions = <String, List<List<int>>>{};
    final placedWords = <String>[];

    final sortedWords = List<String>.from(selectedWords)
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final word in sortedWords) {
      bool placed = false;
      for (int attempt = 0; attempt < 300 && !placed; attempt++) {
        final dir = DIRECTIONS[_random.nextInt(DIRECTIONS.length)];
        final row = _random.nextInt(GRID_SIZE);
        final col = _random.nextInt(GRID_SIZE);

        if (_canPlaceWord(newGrid, word, row, col, dir[0], dir[1])) {
          final pos = _placeWord(newGrid, word, row, col, dir[0], dir[1]);
          positions[word] = pos;
          placedWords.add(word);
          placed = true;
        }
      }
    }

    for (int i = 0; i < GRID_SIZE; i++) {
      for (int j = 0; j < GRID_SIZE; j++) {
        if (newGrid[i][j] == '') {
          newGrid[i][j] = String.fromCharCode(65 + _random.nextInt(26));
        }
      }
    }

    grid = newGrid;
    currentWords = placedWords;
    wordPositions = positions;
  }

  bool _canPlaceWord(
      List<List<String>> grid, String word, int row, int col, int dr, int dc) {
    for (int i = 0; i < word.length; i++) {
      final r = row + i * dr;
      final c = col + i * dc;
      if (r < 0 || r >= GRID_SIZE || c < 0 || c >= GRID_SIZE) return false;
      if (grid[r][c] != '' && grid[r][c] != word[i]) return false;
    }
    return true;
  }

  List<List<int>> _placeWord(
      List<List<String>> grid, String word, int row, int col, int dr, int dc) {
    final positions = <List<int>>[];
    for (int i = 0; i < word.length; i++) {
      final r = row + i * dr;
      final c = col + i * dc;
      grid[r][c] = word[i];
      positions.add([r, c]);
    }
    return positions;
  }

  List<CellPosition> _getCellsInLine(CellPosition start, CellPosition end) {
    final cells = <CellPosition>[];
    final dr = end.row - start.row;
    final dc = end.col - start.col;

    if (dr == 0 && dc == 0) {
      cells.add(start);
      return cells;
    }

    final stepR = dr == 0 ? 0 : dr ~/ dr.abs();
    final stepC = dc == 0 ? 0 : dc ~/ dc.abs();

    if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) {
      return [start];
    }

    final steps = max(dr.abs(), dc.abs());
    for (int i = 0; i <= steps; i++) {
      final row = start.row + i * stepR;
      final col = start.col + i * stepC;
      if (row >= 0 && row < GRID_SIZE && col >= 0 && col < GRID_SIZE) {
        cells.add(CellPosition(row, col));
      }
    }
    return cells;
  }

  void _checkWordSelection(CellPosition start, CellPosition end) {
    final cells = _getCellsInLine(start, end);
    if (cells.length < 2) return;

    final letters = <String>[];
    final positions = <List<int>>[];
    for (final cell in cells) {
      letters.add(grid[cell.row][cell.col]);
      positions.add([cell.row, cell.col]);
    }

    final wordAttempt = letters.join();
    final reversedAttempt = letters.reversed.join();

    String? matchedWord;
    for (final word in currentWords) {
      if (!foundWords.contains(word) &&
          (wordAttempt == word || reversedAttempt == word)) {
        matchedWord = word;
        break;
      }
    }

    if (matchedWord != null) {
      final foundWord = matchedWord;
      setState(() {
        foundWords.add(foundWord);
        for (final pos in positions) {
          foundCells.add('${pos[0]},${pos[1]}');
        }
        selectedCells.clear();
        startCell = null;
        endCell = null;
        isSelecting = false;
      });

      if (foundWords.length == currentWords.length) {
        _winGame();
      }
    }
  }

  void _winGame() {
    setState(() {
      isGameWon = true;
    });
    _showWinPopup();
  }

  void _activateHint() {
    if (isSolving || foundWords.length == currentWords.length) return;

    final missingWords =
        currentWords.where((w) => !foundWords.contains(w)).toList();
    if (missingWords.isEmpty) return;

    final hintWord = missingWords[_random.nextInt(missingWords.length)];
    final positions = wordPositions[hintWord] ?? [];

    setState(() {
      selectedCells =
          positions.map((pos) => CellPosition(pos[0], pos[1])).toList();
    });

    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          selectedCells.clear();
        });
      }
    });
  }

  Future<void> _solvePuzzle() async {
    if (isSolving || foundWords.length == currentWords.length) return;

    setState(() {
      isSolving = true;
    });

    final missingWords =
        currentWords.where((w) => !foundWords.contains(w)).toList();

    for (final word in missingWords) {
      if (!isSolving) break;

      final positions = wordPositions[word] ?? [];
      if (positions.isEmpty) continue;

      for (final pos in positions) {
        if (!isSolving) break;
        setState(() {
          selectedCells = [CellPosition(pos[0], pos[1])];
        });
        await Future.delayed(const Duration(milliseconds: 120));
      }

      setState(() {
        foundWords.add(word);
        for (final pos in positions) {
          foundCells.add('${pos[0]},${pos[1]}');
        }
      });

      await Future.delayed(const Duration(milliseconds: 150));
    }

    setState(() {
      selectedCells.clear();
      isSolving = false;
    });

    if (foundWords.length == currentWords.length) {
      _winGame();
    }
  }

  void _showWinPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFf5f0e8),
        title: Row(
          children: const [
            Icon(Icons.emoji_events, color: Color(0xFFFFB300), size: 32),
            SizedBox(width: 8),
            Text(
              '🎉 VICTORY!',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: Color(0xFF3a2a1a),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Words Found: ${foundWords.length}/${currentWords.length}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3a2a1a),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadNewGame();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3a2a1a),
            ),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadNewGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: const Color(0xFF2c1f00),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize =
        (screenWidth - 40 > 500 ? 500 : screenWidth - 40).toDouble();
    final cellSize = boardSize / GRID_SIZE;

    return Scaffold(
      backgroundColor: const Color(0xFFf5f0e8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFf5f0e8),
        elevation: 0,
        title: const Text(
          'Word Search',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF3a2a1a),
            letterSpacing: -0.3,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3a2a1a)),
          onPressed: isLoading ? null : _showInterstitial,
        ),
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3a2a1a)),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Grid
              Container(
                width: boardSize,
                height: boardSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Grid cells
                    Positioned.fill(
                      child: GestureDetector(
                        onPanStart: (details) {
                          if (!isGameWon && !isSolving) {
                            final local = details.localPosition;
                            final row = (local.dy / cellSize).floor();
                            final col = (local.dx / cellSize).floor();

                            if (row >= 0 &&
                                row < GRID_SIZE &&
                                col >= 0 &&
                                col < GRID_SIZE) {
                              setState(() {
                                isSelecting = true;
                                startCell = CellPosition(row, col);
                                endCell = CellPosition(row, col);
                                selectedCells = [CellPosition(row, col)];
                              });
                            }
                          }
                        },
                        onPanUpdate: (details) {
                          if (isSelecting &&
                              startCell != null &&
                              !isGameWon &&
                              !isSolving) {
                            final local = details.localPosition;
                            final row = (local.dy / cellSize).floor();
                            final col = (local.dx / cellSize).floor();

                            if (row >= 0 &&
                                row < GRID_SIZE &&
                                col >= 0 &&
                                col < GRID_SIZE) {
                              final newCell = CellPosition(row, col);
                              if (endCell != newCell) {
                                setState(() {
                                  endCell = newCell;
                                  selectedCells =
                                      _getCellsInLine(startCell!, endCell!);
                                });
                              }
                            }
                          }
                        },
                        onPanEnd: (details) {
                          if (isSelecting &&
                              startCell != null &&
                              endCell != null &&
                              !isGameWon &&
                              !isSolving) {
                            _checkWordSelection(startCell!, endCell!);
                          }
                          setState(() {
                            isSelecting = false;
                            if (!isGameWon) {
                              selectedCells.clear();
                            }
                          });
                        },
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: GRID_SIZE,
                          ),
                          itemCount: GRID_SIZE * GRID_SIZE,
                          itemBuilder: (context, index) {
                            final row = index ~/ GRID_SIZE;
                            final col = index % GRID_SIZE;
                            final cellKey = '$row,$col';
                            final isFound = foundCells.contains(cellKey);
                            final isHinted = selectedCells
                                .any((c) => c.row == row && c.col == col);
                            final letter = grid[row][col];

                            return Container(
                              margin: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                color: isFound
                                    ? const Color(0xFF9fd3a3)
                                    : isHinted
                                        ? const Color(0xFFFFB347)
                                        : const Color(0xFFfef7e0),
                                borderRadius: BorderRadius.circular(4),
                                border: isHinted
                                    ? Border.all(color: Colors.orange, width: 2)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  letter,
                                  style: TextStyle(
                                    fontSize: cellSize * 0.5,
                                    fontWeight: FontWeight.w800,
                                    color: isFound
                                        ? const Color(0xFF1f3a1a)
                                        : isHinted
                                            ? const Color(0xFF2c2b1f)
                                            : const Color(0xFF3a2a1a),
                                    decoration: isFound
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: const Color(0xFF2b6e2a),
                                    decorationThickness: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Win overlay
                    if (isGameWon)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.55),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '🎉 VICTORY!',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    shadows: [
                                      BoxShadow(
                                        color: Colors.black,
                                        blurRadius: 12,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${foundWords.length}/${currentWords.length} words found',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFFE0B2),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: isLoading ? null : _loadNewGame,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFB300),
                                    foregroundColor: const Color(0xFF2c1f00),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Play Again'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Words panel
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: currentWords.map((word) {
                    final isFound = foundWords.contains(word);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFound
                            ? const Color(0xFFc8e6c9)
                            : const Color(0xFFf8f3ea),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        word,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isFound
                              ? const Color(0xFF1b5e20)
                              : const Color(0xFF3a2a1a),
                          decoration:
                              isFound ? TextDecoration.lineThrough : null,
                          decorationColor: const Color(0xFF1b5e20),
                          decorationThickness: 2,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 10),

              // Buttons
              Row(
                children: [
                  // Progress
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      '${foundWords.length}/${currentWords.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3a2a1a),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        ActionButton(
                          label: 'Back',
                          color: const Color(0xFF5a7a6a),
                          onPressed: isLoading ? null : _showInterstitial,
                        ),
                        const SizedBox(width: 4),
                        ActionButton(
                          label: 'Hint',
                          color: const Color(0xFFd4a13e),
                          textColor: const Color(0xFF2c2418),
                          onPressed: (isLoading || isSolving || isGameWon)
                              ? null
                              : _showRewardedForHint,
                        ),
                        const SizedBox(width: 4),
                        ActionButton(
                          label: 'Solve',
                          color: const Color(0xFF4a90d9),
                          onPressed: (isLoading || isSolving || isGameWon)
                              ? null
                              : _showRewardedForSolve,
                        ),
                        const SizedBox(width: 4),
                        ActionButton(
                          label: 'Reset',
                          color: const Color(0xFFc06c3e),
                          onPressed: isLoading ? null : _resetGame,
                        ),
                        const SizedBox(width: 4),
                        ActionButton(
                          label: 'New',
                          color: const Color(0xFF2d7a5c),
                          onPressed: isLoading ? null : _loadNewGame,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Banner Ad
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFe8dfcf),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _unityInitialized
                      ? UnityBannerAd(
                          placementId: _bannerPlacementId,
                          onLoad: (placementId) =>
                              debugPrint('Banner loaded: $placementId'),
                          onClick: (placementId) =>
                              debugPrint('Banner clicked: $placementId'),
                          onShown: (placementId) =>
                              debugPrint('Banner shown: $placementId'),
                          onFailed: (placementId, error, message) =>
                              debugPrint('Banner failed: $error $message'),
                        )
                      : const Center(
                          child: Text(
                            'Banner Ad',
                            style: TextStyle(
                              color: Color(0xFF8a7a6a),
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HELPER CLASSES
// ============================================================

class CellPosition {
  final int row;
  final int col;

  const CellPosition(this.row, this.col);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CellPosition && other.row == row && other.col == col;
  }

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

// ============================================================
// ACTION BUTTON (PUBLIC)
// ============================================================
class ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final VoidCallback? onPressed;

  const ActionButton({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 380;

    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null ? 0.5 : 1.0,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  offset: const Offset(0, 4),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? 11 : 14,
                  fontWeight: FontWeight.w700,
                  color: textColor ?? Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
