import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'dart:math';
import 'dart:async';

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  static const int BOARD_SIZE = 9;
  late List<List<int>> _board;
  late List<List<bool>> _fixed;
  int _selectedRow = 0;
  int _selectedCol = 0;
  bool _gameWon = false;
  String _difficulty = 'easy';
  bool _isSolving = false;
  final Random _random = Random();

  // ===== UNITY ADS CONFIG =====
  static const String _gameId = '800107168';
  // Test mode must be OFF for a Play Store release build, otherwise only
  // test creatives are served (no real fill, and it violates store policy).
  static const bool _testMode = false;
  static const String _bannerPlacementId = 'Banner_Android';
  static const String _interstitialPlacementId = 'Interstitial_Android';
  static const String _rewardedPlacementId = 'Rewarded_Android';

  bool _unityInitialized = false;
  bool _interstitialReady = false;
  bool _rewardedReady = false;
  bool _isAdsLoading = false;

  // ============================================================
  // LIFECYCLE
  // ============================================================
  @override
  void initState() {
    super.initState();
    _newGame();
    _initAds();
  }

  @override
  void dispose() {
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
        // Retry init silently in the background instead of leaving ads dead
        // for the rest of the session.
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
        // Silent retry so it's ready next time it's needed, without
        // ever surfacing a failure to the player.
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

  /// Waits briefly for an ad to finish loading instead of failing instantly.
  /// Gives Unity a real chance to serve a fill before we fall back.
  Future<bool> _waitForAdReady(bool Function() isReady,
      {int timeoutMs = 4000}) async {
    final start = DateTime.now();
    while (!isReady() &&
        DateTime.now().difference(start).inMilliseconds < timeoutMs) {
      await Future.delayed(const Duration(milliseconds: 250));
    }
    return isReady();
  }

  void _showInterstitial() async {
    if (_isAdsLoading) return;

    if (!_unityInitialized || !_interstitialReady) {
      // Give it a brief window to become ready; otherwise leave quietly.
      setState(() => _isAdsLoading = true);
      _loadInterstitial();
      final ready =
          await _waitForAdReady(() => _interstitialReady, timeoutMs: 2500);
      if (mounted) setState(() => _isAdsLoading = false);
      if (!ready) {
        if (mounted) Navigator.pop(context);
        return;
      }
    }

    setState(() => _isAdsLoading = true);

    void finishAndLeave() {
      if (mounted) {
        setState(() {
          _isAdsLoading = false;
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
        // No error surfaced to the player — just leave the screen as expected.
        finishAndLeave();
      },
    );
  }

  void _showRewardedForHint() async {
    if (_isAdsLoading) return;
    setState(() => _isAdsLoading = true);

    if (!_unityInitialized || !_rewardedReady) {
      _loadRewarded();
      final ready = await _waitForAdReady(() => _rewardedReady);
      if (!ready) {
        // Ad genuinely unavailable — grant the hint anyway so the feature
        // still "works" from the player's perspective, no error shown.
        if (mounted) setState(() => _isAdsLoading = false);
        _performHint();
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
            _isAdsLoading = false;
            _rewardedReady = false;
          });
        }
        _loadRewarded();
        // Skipped before completion — no reward, consistent with a real
        // rewarded-ad flow, but no error message needed either.
      },
      onComplete: (placementId) {
        if (mounted) {
          setState(() {
            _isAdsLoading = false;
            _rewardedReady = false;
          });
        }
        _loadRewarded();
        _performHint();
        _showSnackBar('🎉 You earned a hint!');
      },
      onFailed: (placementId, error, message) {
        debugPrint('Rewarded show failed: $error $message');
        if (mounted) {
          setState(() {
            _isAdsLoading = false;
            _rewardedReady = false;
          });
        }
        _loadRewarded();
        // Fall back gracefully instead of showing an error.
        _performHint();
      },
    );
  }

  void _showRewardedForSolve() async {
    if (_isAdsLoading) return;
    setState(() => _isAdsLoading = true);

    if (!_unityInitialized || !_rewardedReady) {
      _loadRewarded();
      final ready = await _waitForAdReady(() => _rewardedReady);
      if (!ready) {
        if (mounted) setState(() => _isAdsLoading = false);
        _performSolve();
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
            _isAdsLoading = false;
            _rewardedReady = false;
          });
        }
        _loadRewarded();
      },
      onComplete: (placementId) {
        if (mounted) {
          setState(() {
            _isAdsLoading = false;
            _rewardedReady = false;
          });
        }
        _loadRewarded();
        _performSolve();
        _showSnackBar('🎉 You earned a full solve!');
      },
      onFailed: (placementId, error, message) {
        debugPrint('Rewarded show failed: $error $message');
        if (mounted) {
          setState(() {
            _isAdsLoading = false;
            _rewardedReady = false;
          });
        }
        _loadRewarded();
        _performSolve();
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
  void _newGame() {
    if (_isSolving) return;
    setState(() {
      _gameWon = false;
      _board = _generatePuzzle(_difficulty);
      _fixed = List.generate(
        BOARD_SIZE,
        (i) => List.generate(BOARD_SIZE, (j) => _board[i][j] != 0),
      );
      _selectedRow = 0;
      _selectedCol = 0;
      _isSolving = false;
    });
  }

  void _resetGame() {
    if (_isSolving) return;
    if (_gameWon) {
      _newGame();
      return;
    }
    setState(() {
      _board = _board.map((row) => List<int>.from(row)).toList();
      for (int i = 0; i < BOARD_SIZE; i++) {
        for (int j = 0; j < BOARD_SIZE; j++) {
          if (!_fixed[i][j]) _board[i][j] = 0;
        }
      }
      _gameWon = false;
      _isSolving = false;
    });
  }

  List<List<int>> _generatePuzzle(String difficulty) {
    final board = List.generate(BOARD_SIZE, (_) => List.filled(BOARD_SIZE, 0));
    _fillBoard(board);
    final puzzle = board.map((row) => List<int>.from(row)).toList();

    int cellsToRemove = difficulty == 'easy'
        ? 46
        : difficulty == 'medium'
            ? 56
            : 64;
    final positions = <int>[];
    for (int i = 0; i < BOARD_SIZE; i++) {
      for (int j = 0; j < BOARD_SIZE; j++) {
        positions.add(i * BOARD_SIZE + j);
      }
    }
    positions.shuffle(_random);
    for (int k = 0; k < cellsToRemove && k < positions.length; k++) {
      final index = positions[k];
      puzzle[index ~/ BOARD_SIZE][index % BOARD_SIZE] = 0;
    }
    return puzzle;
  }

  bool _fillBoard(List<List<int>> board) {
    for (int row = 0; row < BOARD_SIZE; row++) {
      for (int col = 0; col < BOARD_SIZE; col++) {
        if (board[row][col] == 0) {
          final numbers = List.generate(BOARD_SIZE, (i) => i + 1)
            ..shuffle(_random);
          for (final num in numbers) {
            if (_isSafe(board, row, col, num)) {
              board[row][col] = num;
              if (_fillBoard(board)) return true;
              board[row][col] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  bool _isSafe(List<List<int>> board, int row, int col, int num) {
    for (int x = 0; x < BOARD_SIZE; x++) {
      if (board[row][x] == num && x != col) return false;
      if (board[x][col] == num && x != row) return false;
    }
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        final rr = boxRow + i;
        final cc = boxCol + j;
        if ((rr != row || cc != col) && board[rr][cc] == num) return false;
      }
    }
    return true;
  }

  bool _isCompleteValid(List<List<int>> board) {
    for (int r = 0; r < BOARD_SIZE; r++) {
      for (int c = 0; c < BOARD_SIZE; c++) {
        final val = board[r][c];
        if (val == 0) return false;
        if (!_isSafeWithIgnore(board, r, c, val)) return false;
      }
    }
    return true;
  }

  bool _isSafeWithIgnore(List<List<int>> board, int row, int col, int num) {
    for (int x = 0; x < BOARD_SIZE; x++) {
      if (x != col && board[row][x] == num) return false;
      if (x != row && board[x][col] == num) return false;
    }
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        final rr = boxRow + i;
        final cc = boxCol + j;
        if ((rr != row || cc != col) && board[rr][cc] == num) return false;
      }
    }
    return true;
  }

  List<List<bool>> _getConflicts() {
    final conflicts =
        List.generate(BOARD_SIZE, (_) => List.filled(BOARD_SIZE, false));
    for (int r = 0; r < BOARD_SIZE; r++) {
      for (int c = 0; c < BOARD_SIZE; c++) {
        final val = _board[r][c];
        if (val != 0 && !_isSafeWithIgnore(_board, r, c, val)) {
          conflicts[r][c] = true;
        }
      }
    }
    return conflicts;
  }

  List<List<int>>? _getSolution() {
    final working = List.generate(
        BOARD_SIZE,
        (i) => List.generate(BOARD_SIZE, (j) {
              return _fixed[i][j] ? _board[i][j] : 0;
            }));

    bool solve(List<List<int>> board) {
      for (int r = 0; r < BOARD_SIZE; r++) {
        for (int c = 0; c < BOARD_SIZE; c++) {
          if (board[r][c] == 0) {
            for (int num = 1; num <= BOARD_SIZE; num++) {
              if (_isSafe(board, r, c, num)) {
                board[r][c] = num;
                if (solve(board)) return true;
                board[r][c] = 0;
              }
            }
            return false;
          }
        }
      }
      return true;
    }

    if (solve(working)) return working;
    return null;
  }

  void _setCell(int val) {
    if (_isSolving || _gameWon || _fixed[_selectedRow][_selectedCol]) return;
    setState(() {
      _board[_selectedRow][_selectedCol] = val == 0 ? 0 : val;
      if (!_gameWon && _isCompleteValid(_board)) {
        _gameWon = true;
        _showSnackBar('🎉 Puzzle Complete!');
      }
    });
  }

  void _giveHint() {
    if (_isSolving || _gameWon) return;
    _showRewardedForHint();
  }

  void _performHint() {
    final solution = _getSolution();
    if (solution == null) return;

    setState(() {
      if (!_fixed[_selectedRow][_selectedCol] &&
          _board[_selectedRow][_selectedCol] == 0) {
        _board[_selectedRow][_selectedCol] =
            solution[_selectedRow][_selectedCol];
        if (_isCompleteValid(_board)) _gameWon = true;
        return;
      }
      for (int i = 0; i < BOARD_SIZE; i++) {
        for (int j = 0; j < BOARD_SIZE; j++) {
          if (!_fixed[i][j] && _board[i][j] == 0) {
            _selectedRow = i;
            _selectedCol = j;
            _board[i][j] = solution[i][j];
            if (_isCompleteValid(_board)) _gameWon = true;
            return;
          }
        }
      }
    });
  }

  void _solveFull() {
    if (_isSolving || _gameWon) return;
    _showRewardedForSolve();
  }

  void _performSolve() async {
    final solution = _getSolution();
    if (solution == null) {
      _showSnackBar('Unable to solve this puzzle.');
      return;
    }

    final changes = <Map<String, int>>[];
    for (int i = 0; i < BOARD_SIZE; i++) {
      for (int j = 0; j < BOARD_SIZE; j++) {
        if (!_fixed[i][j] && _board[i][j] != solution[i][j]) {
          changes.add({'row': i, 'col': j, 'value': solution[i][j]});
        }
      }
    }

    if (changes.isEmpty) {
      if (_isCompleteValid(_board)) {
        setState(() => _gameWon = true);
      }
      return;
    }

    setState(() => _isSolving = true);

    for (int box = 0; box < 9; box++) {
      final startRow = (box ~/ 3) * 3;
      final startCol = (box % 3) * 3;

      final changesInBlock = changes.where((c) =>
          c['row']! >= startRow &&
          c['row']! < startRow + 3 &&
          c['col']! >= startCol &&
          c['col']! < startCol + 3);

      for (final change in changesInBlock) {
        setState(() {
          _board[change['row']!][change['col']!] = change['value']!;
        });
        await Future.delayed(const Duration(milliseconds: 160));
      }
      await Future.delayed(const Duration(milliseconds: 80));
    }

    if (_isCompleteValid(_board)) {
      setState(() => _gameWon = true);
    }
    setState(() => _isSolving = false);
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize =
        (screenWidth - 60 > 500 ? 500 : screenWidth - 60).toDouble();
    final cellSize = boardSize / BOARD_SIZE;
    final conflicts = _getConflicts();

    return Scaffold(
      backgroundColor: const Color(0xFFf5f0e8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFf5f0e8),
        elevation: 0,
        title: const Text(
          'Sudoku',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF3a2a1a),
            letterSpacing: -0.3,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3a2a1a)),
          onPressed: _isAdsLoading ? null : _showInterstitial,
        ),
        actions: [
          if (_isAdsLoading)
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
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFf0e8d8),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _difficulty,
                onChanged: _isSolving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _difficulty = value;
                            _newGame();
                          });
                        }
                      },
                dropdownColor: const Color(0xFFf0e8d8),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3a2a1a),
                ),
                items: const [
                  DropdownMenuItem(value: 'easy', child: Text('Easy')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'hard', child: Text('Hard')),
                ],
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
              // Board
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFede3d0),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Container(
                  width: boardSize,
                  height: boardSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFFfffaf2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onTapDown: (details) {
                      if (_gameWon || _isSolving) return;
                      final offset = details.localPosition;
                      final row = (offset.dy / cellSize).floor();
                      final col = (offset.dx / cellSize).floor();
                      if (row >= 0 &&
                          row < BOARD_SIZE &&
                          col >= 0 &&
                          col < BOARD_SIZE) {
                        setState(() {
                          _selectedRow = row;
                          _selectedCol = col;
                        });
                      }
                    },
                    child: CustomPaint(
                      painter: SudokuBoardPainter(
                        board: _board,
                        fixed: _fixed,
                        conflicts: conflicts,
                        selectedRow: _selectedRow,
                        selectedCol: _selectedCol,
                        gameWon: _gameWon,
                        isSolving: _isSolving,
                        cellSize: cellSize,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  ActionButton(
                    label: 'Back',
                    color: const Color(0xFF5a7a6a),
                    onPressed: _isAdsLoading ? null : _showInterstitial,
                  ),
                  const SizedBox(width: 10),
                  ActionButton(
                    label: 'Hint',
                    color: const Color(0xFFd4a13e),
                    textColor: const Color(0xFF2c2418),
                    onPressed: _isAdsLoading ? null : _showRewardedForHint,
                  ),
                  const SizedBox(width: 10),
                  ActionButton(
                    label: 'Solve',
                    color: const Color(0xFF4a90d9),
                    onPressed: _isAdsLoading ? null : _showRewardedForSolve,
                  ),
                  const SizedBox(width: 10),
                  ActionButton(
                    label: 'Reset',
                    color: const Color(0xFFc06c3e),
                    onPressed: _isAdsLoading ? null : _resetGame,
                  ),
                  const SizedBox(width: 10),
                  ActionButton(
                    label: 'New',
                    color: const Color(0xFF2d7a5c),
                    onPressed: _isAdsLoading ? null : _newGame,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Numpad
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.5,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (int i = 1; i <= 9; i++)
                    _NumpadButton(
                      label: '$i',
                      onPressed: () => _setCell(i),
                    ),
                  _NumpadButton(
                    label: 'Del',
                    isDelete: true,
                    onPressed: () => _setCell(0),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Real Unity Banner Ad
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
// CUSTOM PAINTER
// ============================================================
class SudokuBoardPainter extends CustomPainter {
  final List<List<int>> board;
  final List<List<bool>> fixed;
  final List<List<bool>> conflicts;
  final int selectedRow;
  final int selectedCol;
  final bool gameWon;
  final bool isSolving;
  final double cellSize;

  SudokuBoardPainter({
    required this.board,
    required this.fixed,
    required this.conflicts,
    required this.selectedRow,
    required this.selectedCol,
    required this.gameWon,
    required this.isSolving,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final x = col * cellSize;
        final y = row * cellSize;
        final rect = Rect.fromLTWH(x, y, cellSize, cellSize);

        // Background
        if (gameWon) {
          paint.color = const Color(0xFFa8e6a0).withOpacity(0.3);
          canvas.drawRect(rect, paint);
        } else if (selectedRow == row && selectedCol == col) {
          paint.color = const Color(0xFFc8dfff);
          canvas.drawRect(rect, paint);
        } else if (conflicts[row][col] && board[row][col] != 0 && !gameWon) {
          paint.color = const Color(0xFFffe0db);
          canvas.drawRect(rect, paint);
        } else if ((row + col) % 2 == 0) {
          paint.color = const Color(0xFFfef7ea);
          canvas.drawRect(rect, paint);
        } else {
          paint.color = const Color(0xFFf7efdf);
          canvas.drawRect(rect, paint);
        }

        // Number
        final val = board[row][col];
        if (val != 0) {
          final isFixed = fixed[row][col];
          final hasConflict = conflicts[row][col] && !gameWon;

          textPainter.text = TextSpan(
            text: val.toString(),
            style: TextStyle(
              fontSize: cellSize * 0.44,
              fontWeight: FontWeight.bold,
              color: isFixed
                  ? const Color(0xFF1a5080)
                  : (hasConflict
                      ? const Color(0xFFc7362b)
                      : const Color(0xFF2c6e41)),
            ),
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(
              x + (cellSize - textPainter.width) / 2,
              y + (cellSize - textPainter.height) / 2,
            ),
          );
        }

        // Cell border
        paint.color = const Color(0xFFd4c4a8);
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 0.8;
        canvas.drawRect(rect, paint);
      }
    }

    // Grid lines
    paint.style = PaintingStyle.stroke;
    for (int i = 0; i <= 9; i++) {
      final pos = i * cellSize;
      final isBold = i % 3 == 0;
      paint.color = isBold ? const Color(0xFF3b5a4e) : const Color(0xFFc4b49a);
      paint.strokeWidth = isBold ? 3.2 : 1;

      canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), paint);
      canvas.drawLine(Offset(0, pos), Offset(size.width, pos), paint);
    }

    // Selected cell highlight
    if (!gameWon && !isSolving) {
      paint.color = const Color(0xFFf5a142);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 3.5;
      canvas.drawRect(
        Rect.fromLTWH(
          selectedCol * cellSize + 2,
          selectedRow * cellSize + 2,
          cellSize - 4,
          cellSize - 4,
        ),
        paint,
      );
    }

    // Win overlay
    if (gameWon) {
      textPainter.text = TextSpan(
        text: '✓ WINNER ✓',
        style: TextStyle(
          fontSize: cellSize * 0.85,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1d7542),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================
// NUMPAD BUTTON
// ============================================================
class _NumpadButton extends StatelessWidget {
  final String label;
  final bool isDelete;
  final VoidCallback onPressed;

  const _NumpadButton({
    required this.label,
    this.isDelete = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          gradient: isDelete
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFe08f5e), Color(0xFFd47a48)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFe8dfce), Color(0xFFddd2bd)],
                ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: isDelete
                  ? const Color(0xFF9b5a38).withOpacity(0.5)
                  : const Color(0xFFb0a07c).withOpacity(0.5),
              offset: const Offset(0, 3),
              blurRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isDelete ? 14 : 20,
              fontWeight: FontWeight.w800,
              color: isDelete ? Colors.white : const Color(0xFF2d4a3a),
              fontFamily: isDelete ? null : 'monospace',
            ),
          ),
        ),
      ),
    );
  }
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
