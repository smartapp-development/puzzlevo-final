import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'dart:math';
import 'dart:async';

// ============================================================
// CONFETTI CLASSES
// ============================================================
class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double life;
  double rotation;
  double rotationSpeed;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.life,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.life)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      if (p.size > 8) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          paint,
        );
      } else {
        final path = Path()
          ..moveTo(0, -p.size / 2)
          ..lineTo(p.size / 2, 0)
          ..lineTo(0, p.size / 2)
          ..lineTo(-p.size / 2, 0)
          ..close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================
// ACTION BUTTON
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

// ============================================================
// NUMBER PUZZLE SCREEN
// ============================================================
class NumberPuzzleScreen extends StatefulWidget {
  const NumberPuzzleScreen({super.key});

  @override
  State<NumberPuzzleScreen> createState() => _NumberPuzzleScreenState();
}

class _NumberPuzzleScreenState extends State<NumberPuzzleScreen>
    with SingleTickerProviderStateMixin {
  int _size = 3;
  late List<int> _board;
  int _emptyIndex = 0;
  int _moveCount = 0;
  int _timerSeconds = 0;
  Timer? _timer;
  bool _gameWon = false;
  final Random _random = Random();

  late AnimationController _confettiController;
  List<ConfettiParticle> _confettiParticles = [];
  bool _showConfetti = false;
  bool _isAdsLoading = false;

  // ============================================================
  // UNITY ADS CONFIG
  // ============================================================
  // TODO: Replace with YOUR real Unity Dashboard Game ID before release,
  // and set testMode to false before you upload to the Play Store.
  // Leaving testMode: true in a production build means Unity will only
  // ever serve test creatives and Google may flag the listing.
  static const String _gameId = '800107168';
  static const bool _testMode = false; // <-- set to false for release build

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
    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _confettiController.addListener(() {
      if (_showConfetti) {
        setState(() {
          _updateConfetti();
        });
      }
    });
    _newGame();
    _initAds();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiController.dispose();
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
      },
    );
  }

  Future<void> _showInterstitial() async {
    if (_isAdsLoading) return;

    // If the ad never loaded (e.g. no network), just leave the screen
    // instead of getting stuck.
    if (!_unityInitialized || !_interstitialReady) {
      Navigator.pop(context);
      return;
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
        _showSnackBar('Ad error. Please try again.');
      },
    );
  }

  Future<void> _showRewardedForShuffle() async {
    if (_isAdsLoading) return;

    if (!_unityInitialized || !_rewardedReady) {
      _showSnackBar('Ad not ready yet — try again in a moment.');
      _loadRewarded();
      return;
    }

    setState(() => _isAdsLoading = true);

    UnityAds.showVideoAd(
      placementId: _rewardedPlacementId,
      onStart: (placementId) => debugPrint('Rewarded started: $placementId'),
      onClick: (placementId) => debugPrint('Rewarded clicked: $placementId'),
      onSkipped: (placementId) {
        // Only grant the reward on full completion, never on skip —
        // required by Unity/AdMob rewarded-ad policy.
        if (mounted) {
          setState(() {
            _isAdsLoading = false;
            _rewardedReady = false;
          });
        }
        _loadRewarded();
        _showSnackBar('Watch the full ad to get a new puzzle.');
      },
      onComplete: (placementId) {
        if (mounted) {
          setState(() {
            _isAdsLoading = false;
            _rewardedReady = false;
          });
        }
        _loadRewarded();
        _newGame();
        _showSnackBar('🎉 New puzzle started!');
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
        _showSnackBar('Ad error. Please try again.');
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
    _timer?.cancel();
    _timer = null;
    setState(() {
      _gameWon = false;
      _moveCount = 0;
      _timerSeconds = 0;
      _showConfetti = false;
      _confettiParticles.clear();
      _confettiController.stop();
      _generateSolvablePuzzle();
    });
    _startTimer();
  }

  void _resetGame() {
    if (_gameWon) {
      _newGame();
      return;
    }
    _timer?.cancel();
    _timer = null;
    setState(() {
      _moveCount = 0;
      _timerSeconds = 0;
      _gameWon = false;
      _showConfetti = false;
      _confettiParticles.clear();
      _confettiController.stop();
      _generateSolvablePuzzle();
    });
    _startTimer();
  }

  void _generateSolvablePuzzle() {
    final total = _size * _size;
    _board = List.generate(total, (i) => (i + 1) % total);
    do {
      _board.shuffle(_random);
    } while (!_isSolvable(_board) || _board == _getGoalState());
    _emptyIndex = _board.indexOf(0);
  }

  List<int> _getGoalState() {
    final total = _size * _size;
    return List.generate(total, (i) => (i + 1) % total);
  }

  bool _isSolvable(List<int> arr) {
    int invCount = 0;
    for (int i = 0; i < arr.length; i++) {
      for (int j = i + 1; j < arr.length; j++) {
        if (arr[i] != 0 && arr[j] != 0 && arr[i] > arr[j]) invCount++;
      }
    }
    if (_size % 2 == 1) return invCount % 2 == 0;
    final zeroRow = arr.indexOf(0) ~/ _size;
    return (invCount + zeroRow) % 2 == 1;
  }

  void _startTimer() {
    _timer?.cancel();
    if (!_gameWon) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_gameWon && mounted) {
          setState(() {
            _timerSeconds++;
          });
        } else {
          timer.cancel();
          _timer = null;
        }
      });
    }
  }

  void _moveTile(int index) {
    if (_gameWon) return;

    final emptyRow = _emptyIndex ~/ _size;
    final emptyCol = _emptyIndex % _size;
    final tileRow = index ~/ _size;
    final tileCol = index % _size;

    final isAdjacent =
        (tileRow - emptyRow).abs() + (tileCol - emptyCol).abs() == 1;

    if (isAdjacent) {
      setState(() {
        _board[_emptyIndex] = _board[index];
        _board[index] = 0;
        _emptyIndex = index;
        _moveCount++;
        if (_moveCount == 1) _startTimer();
      });

      if (_board == _getGoalState()) {
        setState(() {
          _gameWon = true;
          _timer?.cancel();
          _timer = null;
          _showConfetti = true;
          _launchConfetti();
        });
        _showWinPopup();
      }
    }
  }

  void _launchConfetti() {
    _confettiParticles.clear();
    final size = MediaQuery.of(context).size;
    final colors = [
      const Color(0xFFff6b6b),
      const Color(0xFFffd93d),
      const Color(0xFF6bcb77),
      const Color(0xFF4d96ff),
      const Color(0xFFff922b),
      const Color(0xFFa66cff),
      const Color(0xFFff6b9d),
    ];

    for (int i = 0; i < 150; i++) {
      _confettiParticles.add(
        ConfettiParticle(
          x: size.width / 2 + (_random.nextDouble() - 0.5) * 200,
          y: size.height / 2 + (_random.nextDouble() - 0.5) * 200,
          vx: (_random.nextDouble() - 0.5) * 16,
          vy: (_random.nextDouble() - 0.5) * 16 - 12,
          size: 4 + _random.nextDouble() * 12,
          color: colors[_random.nextInt(colors.length)],
          life: 1.0,
          rotation: _random.nextDouble() * 6.28,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.3,
        ),
      );
    }
    _confettiController.repeat();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showConfetti = false;
          _confettiParticles.clear();
          _confettiController.stop();
        });
      }
    });
  }

  void _updateConfetti() {
    for (final p in _confettiParticles) {
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.25;
      p.life -= 0.008;
      p.rotation += p.rotationSpeed;
    }
    _confettiParticles.removeWhere((p) => p.life <= 0);
  }

  void _showWinPopup() {
    final m = _timerSeconds ~/ 60;
    final s = _timerSeconds % 60;
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
              '🎉 Complete!',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Moves: $_moveCount',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3a2a1a),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Time: ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3a2a1a),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFFFB300), size: 20),
                  const SizedBox(width: 4),
                  Text(
                    _getRating(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3a2a1a),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _newGame();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3a2a1a),
            ),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _newGame();
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

  String _getRating() {
    final ratio = _moveCount / (_size * _size - 1);
    if (ratio <= 1.5) return '⭐ Perfect!';
    if (ratio <= 2.5) return '⭐⭐ Great!';
    if (ratio <= 4) return '⭐⭐⭐ Good!';
    return 'Keep practicing! 💪';
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize =
        (screenWidth - 40 > 500 ? 500 : screenWidth - 40).toDouble();
    final cellSize = boardSize / _size;
    final gap = cellSize * 0.065 > 2 ? cellSize * 0.065 : 2;
    final tileSize = cellSize - gap * 2;

    return Scaffold(
      backgroundColor: const Color(0xFFf5f0e8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFf5f0e8),
        elevation: 0,
        title: const Text(
          'Number Puzzle',
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
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Header Row
              Row(
                children: [
                  Container(
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
                      child: DropdownButton<int>(
                        value: _size,
                        onChanged: _gameWon || _isAdsLoading
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() {
                                    _size = value;
                                    _newGame();
                                  });
                                }
                              },
                        dropdownColor: const Color(0xFFf0e8d8),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF000000),
                        ),
                        items: const [
                          DropdownMenuItem(value: 3, child: Text('3x3')),
                          DropdownMenuItem(value: 4, child: Text('4x4')),
                          DropdownMenuItem(value: 5, child: Text('5x5')),
                          DropdownMenuItem(value: 6, child: Text('6x6')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Moves:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF000000),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_moveCount',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF000000),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Time:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF000000),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(_timerSeconds ~/ 60).toString().padLeft(2, '0')}:${(_timerSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF000000),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Board
              Container(
                width: boardSize,
                height: boardSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF3e2723),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Empty space indicator
                    Positioned(
                      left: (_emptyIndex % _size) * cellSize + gap,
                      top: (_emptyIndex ~/ _size) * cellSize + gap,
                      child: Container(
                        width: tileSize,
                        height: tileSize,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(tileSize * 0.1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Tiles
                    for (int i = 0; i < _board.length; i++)
                      if (_board[i] != 0)
                        Positioned(
                          left: (i % _size) * cellSize + gap,
                          top: (i ~/ _size) * cellSize + gap,
                          child: GestureDetector(
                            onTap: _isAdsLoading ? null : () => _moveTile(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              width: tileSize,
                              height: tileSize,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFFE082),
                                    Color(0xFFFFB300),
                                    Color(0xFFF9A825),
                                  ],
                                ),
                                borderRadius:
                                    BorderRadius.circular(tileSize * 0.12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.5),
                                    blurRadius: 2,
                                    offset: const Offset(0, 2),
                                  ),
                                  if (_gameWon)
                                    BoxShadow(
                                      color: const Color(0xFFFFB300)
                                          .withOpacity(0.7),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '${_board[i]}',
                                  style: TextStyle(
                                    fontSize: tileSize * 0.38,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF2c1f00),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    // Confetti overlay
                    if (_showConfetti)
                      CustomPaint(
                        size: Size(boardSize, boardSize),
                        painter: ConfettiPainter(_confettiParticles),
                      ),
                    // Win overlay
                    if (_gameWon && !_showConfetti)
                      Container(
                        color: Colors.black.withOpacity(0.55),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '🎉 Complete!',
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
                                '$_moveCount moves - ${(_timerSeconds ~/ 60).toString().padLeft(2, '0')}:${(_timerSeconds % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFFE0B2),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _isAdsLoading ? null : _newGame,
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
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  ActionButton(
                    label: 'Back',
                    color: const Color(0xFF5a7a6a),
                    onPressed: _isAdsLoading ? null : _showInterstitial,
                  ),
                  const SizedBox(width: 10),
                  ActionButton(
                    label: 'Shuffle',
                    color: const Color(0xFFFF9800),
                    textColor: const Color(0xFF2c1f00),
                    onPressed: _isAdsLoading ? null : _showRewardedForShuffle,
                  ),
                  const SizedBox(width: 10),
                  ActionButton(
                    label: 'Reset',
                    color: const Color(0xFFc06c3e),
                    onPressed: _isAdsLoading ? null : _resetGame,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Real Unity Banner Ad (falls back to a placeholder while
              // the SDK/network hasn't delivered a creative yet)
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
