import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'dart:async';
import 'dart:math';

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  // ===== GAME STATE =====
  List<String> _board = List.filled(9, '');
  String _currentPlayer = 'X';
  bool _gameActive = true;
  List<int>? _winCombo;
  bool _gameEnded = false;
  bool _isComputerMode = false;
  bool _isComputerThinking = false;
  String _difficulty = 'medium';
  final Random _random = Random();

  // ===== UNITY ADS =====
  static const String _gameId = '800107168';
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
    _resetGame();
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
    if (_isAdsLoading) return;

    if (!_unityInitialized || !_interstitialReady) {
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
        finishAndLeave();
      },
    );
  }

  Future<void> _showRewardedForHint() async {
    if (_isAdsLoading) return;
    setState(() => _isAdsLoading = true);

    if (!_unityInitialized || !_rewardedReady) {
      _loadRewarded();
      final ready = await _waitForAdReady(() => _rewardedReady);
      if (!ready) {
        if (mounted) setState(() => _isAdsLoading = false);
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
  void _resetGame() {
    setState(() {
      _board = List.filled(9, '');
      _currentPlayer = 'X';
      _gameActive = true;
      _winCombo = null;
      _gameEnded = false;
      _isComputerThinking = false;
    });
    if (_isComputerMode && _currentPlayer == 'O') {
      _computerMove();
    }
  }

  void _makeMove(int index) {
    if (!_gameActive) return;
    if (_board[index] != '') return;
    if (_isComputerThinking) return;
    if (_isComputerMode && _currentPlayer != 'X') return;

    setState(() {
      _board[index] = _currentPlayer;
    });

    _checkWinner();

    if (_gameActive) {
      setState(() {
        _currentPlayer = (_currentPlayer == 'X') ? 'O' : 'X';
      });
    }

    if (_isComputerMode && _gameActive && _currentPlayer == 'O') {
      _computerMove();
    }
  }

  void _checkWinner() {
    const winPatterns = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6]
    ];

    for (final pattern in winPatterns) {
      final a = pattern[0];
      final b = pattern[1];
      final c = pattern[2];
      if (_board[a] != '' && _board[a] == _board[b] && _board[a] == _board[c]) {
        setState(() {
          _gameActive = false;
          _winCombo = pattern;
          _gameEnded = true;
        });
        _showWinPopup(_board[a]);
        return;
      }
    }

    if (_board.every((cell) => cell != '')) {
      setState(() {
        _gameActive = false;
        _gameEnded = true;
      });
      _showWinPopup('draw');
    }
  }

  // ============================================================
  // COMPUTER AI
  // ============================================================
  void _computerMove() {
    if (!_gameActive || _isComputerThinking) return;
    if (_currentPlayer != 'O') return;

    setState(() {
      _isComputerThinking = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_gameActive || _currentPlayer != 'O') {
        setState(() => _isComputerThinking = false);
        return;
      }

      int bestMove = -1;

      if (_difficulty == 'easy') {
        final emptyIndices = [];
        for (int i = 0; i < 9; i++) {
          if (_board[i] == '') emptyIndices.add(i);
        }
        if (emptyIndices.isNotEmpty) {
          bestMove = emptyIndices[_random.nextInt(emptyIndices.length)];
        }
      } else if (_difficulty == 'medium') {
        if (_random.nextDouble() < 0.5) {
          final emptyIndices = [];
          for (int i = 0; i < 9; i++) {
            if (_board[i] == '') emptyIndices.add(i);
          }
          if (emptyIndices.isNotEmpty) {
            bestMove = emptyIndices[_random.nextInt(emptyIndices.length)];
          }
        } else {
          bestMove = _getBestMove();
        }
      } else {
        bestMove = _getBestMove();
      }

      if (bestMove != -1) {
        setState(() {
          _board[bestMove] = 'O';
        });
        setState(() => _isComputerThinking = false);
        _checkWinner();
        if (_gameActive) {
          setState(() {
            _currentPlayer = 'X';
          });
        }
      } else {
        setState(() => _isComputerThinking = false);
      }
    });
  }

  int _getBestMove() {
    int bestScore = -1000;
    int bestMove = -1;

    for (int i = 0; i < 9; i++) {
      if (_board[i] == '') {
        _board[i] = 'O';
        int score = _minimax(_board, 0, false);
        _board[i] = '';
        if (score > bestScore) {
          bestScore = score;
          bestMove = i;
        }
      }
    }
    return bestMove;
  }

  int _minimax(List<String> board, int depth, bool isMaximizing) {
    final result = _checkWinnerStatic(board);
    if (result == 'O') return 10 - depth;
    if (result == 'X') return depth - 10;
    if (result == 'draw') return 0;

    if (isMaximizing) {
      int best = -1000;
      for (int i = 0; i < 9; i++) {
        if (board[i] == '') {
          board[i] = 'O';
          best = max(best, _minimax(board, depth + 1, false));
          board[i] = '';
        }
      }
      return best;
    } else {
      int best = 1000;
      for (int i = 0; i < 9; i++) {
        if (board[i] == '') {
          board[i] = 'X';
          best = min(best, _minimax(board, depth + 1, true));
          board[i] = '';
        }
      }
      return best;
    }
  }

  String? _checkWinnerStatic(List<String> board) {
    const winPatterns = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6]
    ];

    for (final pattern in winPatterns) {
      final a = pattern[0];
      final b = pattern[1];
      final c = pattern[2];
      if (board[a] != '' && board[a] == board[b] && board[a] == board[c]) {
        return board[a];
      }
    }

    if (board.every((cell) => cell != '')) {
      return 'draw';
    }
    return null;
  }

  void _showWinPopup(String winner) {
    String title, subtitle;
    if (winner == 'X') {
      title = 'Player X Wins!';
      subtitle = '🎉 Congratulations!';
    } else if (winner == 'O') {
      title = 'Player O Wins!';
      subtitle = '🎉 Congratulations!';
    } else {
      title = 'Draw!';
      subtitle = 'Well played!';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: Colors.white.withOpacity(0.92),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0a2a44),
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1f4b70),
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: _isAdsLoading
                  ? null
                  : () {
                      Navigator.pop(context);
                      _resetGame();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1f6fb0),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Play Again',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
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

    return Scaffold(
      backgroundColor: const Color(0xFFd4e9ff),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Tic-Tac-Toe',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0a2a44),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0a2a44)),
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
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Mode & Difficulty
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ModeRadio(
                    label: 'Human',
                    value: false,
                    groupValue: _isComputerMode,
                    onChanged: (val) {
                      setState(() {
                        _isComputerMode = false;
                        _resetGame();
                      });
                    },
                  ),
                  const SizedBox(width: 20),
                  _ModeRadio(
                    label: 'Computer',
                    value: true,
                    groupValue: _isComputerMode,
                    onChanged: (val) {
                      setState(() {
                        _isComputerMode = true;
                        _resetGame();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Difficulty Dropdown (only visible in Computer mode)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isComputerMode
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _difficulty,
                            dropdownColor: Colors.white,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF124072),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'easy', child: Text('Easy')),
                              DropdownMenuItem(
                                  value: 'medium', child: Text('Medium')),
                              DropdownMenuItem(
                                  value: 'hard', child: Text('Hard')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _difficulty = value;
                                  _resetGame();
                                });
                              }
                            },
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),

              // Board
              Container(
                width: boardSize,
                height: boardSize,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, index) {
                    final symbol = _board[index];
                    final isWinCell = _winCombo?.contains(index) ?? false;

                    return GestureDetector(
                      onTap: _isComputerThinking || _isAdsLoading
                          ? null
                          : () => _makeMove(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isWinCell
                              ? const Color(0x40ffd700)
                              : Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isWinCell
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFf5c542)
                                        .withOpacity(0.6),
                                    blurRadius: 20,
                                    spreadRadius: 4,
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: symbol == 'X'
                                ? Text(
                                    'X',
                                    key: const ValueKey('X'),
                                    style: TextStyle(
                                      fontSize: boardSize * 0.35,
                                      fontWeight: FontWeight.w700,
                                      color: isWinCell
                                          ? const Color(0xFF1a5f9e)
                                          : const Color(0xFF1a5f9e),
                                      shadows: [
                                        BoxShadow(
                                          color: const Color(0xFF1a5f9e)
                                              .withOpacity(0.2),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                  )
                                : symbol == 'O'
                                    ? Text(
                                        'O',
                                        key: const ValueKey('O'),
                                        style: TextStyle(
                                          fontSize: boardSize * 0.35,
                                          fontWeight: FontWeight.w700,
                                          color: isWinCell
                                              ? const Color(0xFFb8702a)
                                              : const Color(0xFFb8702a),
                                          shadows: [
                                            BoxShadow(
                                              color: const Color(0xFFb8702a)
                                                  .withOpacity(0.2),
                                              blurRadius: 12,
                                            ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('empty')),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Turn Indicator & Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    label: 'New Game',
                    color: const Color(0xFF1f6fb0),
                    onPressed: _isAdsLoading ? null : _resetGame,
                  ),
                  const SizedBox(width: 12),
                  _ActionButton(
                    label: 'Hint',
                    color: const Color(0xFFd4a13e),
                    onPressed: _isAdsLoading ? null : _showRewardedForHint,
                    textColor: const Color(0xFF2c2418),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  _isComputerThinking
                      ? 'Computer is thinking...'
                      : !_gameActive
                          ? 'Game Over'
                          : _isComputerMode && _currentPlayer == 'O'
                              ? 'Computer\'s turn'
                              : 'Your turn - $_currentPlayer',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0a2a44),
                  ),
                ),
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
// HELPER WIDGETS
// ============================================================

class _ModeRadio extends StatelessWidget {
  final String label;
  final bool value;
  final bool groupValue;
  final ValueChanged<bool> onChanged;

  const _ModeRadio({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: groupValue == value
                    ? const Color(0xFF1f6fb0)
                    : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: groupValue == value
                ? Container(
                    margin: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1f6fb0),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: groupValue == value
                  ? const Color(0xFF0a2a44)
                  : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    this.textColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor ?? Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 4,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
