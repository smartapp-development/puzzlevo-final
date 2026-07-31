import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'dart:math';
import 'dart:async';

class EmberMazeScreen extends StatefulWidget {
  const EmberMazeScreen({super.key});

  @override
  State<EmberMazeScreen> createState() => _EmberMazeScreenState();
}

class _EmberMazeScreenState extends State<EmberMazeScreen>
    with SingleTickerProviderStateMixin {
  // ===== GAME CONFIG =====
  static const int CELL_SIZE = 26;
  int cols = 12;
  int rows = 16;

  // ===== GAME STATE =====
  late List<List<Cell>> grid;
  late Position player;
  late Position goal;
  Set<String> visitedSet = {};
  int moves = 0;
  int seconds = 0;
  Timer? _timer;
  bool started = false;
  bool won = false;
  bool solving = false;
  List<Position> solvePath = [];
  int drawnSolvePathIndex = 0;
  final Random _random = Random();

  // ===== ANIMATION =====
  late AnimationController _confettiController;
  List<EmberParticle> _emberParticles = [];
  bool _showEmbers = false;

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
    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _confettiController.addListener(() {
      if (_showEmbers) {
        setState(() {
          _updateEmbers();
        });
      }
    });
    _newMaze();
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

  Future<void> _showRewardedForSolve() async {
    if (_isAdsLoading) return;
    setState(() => _isAdsLoading = true);

    if (!_unityInitialized || !_rewardedReady) {
      _loadRewarded();
      final ready = await _waitForAdReady(() => _rewardedReady);
      if (!ready) {
        if (mounted) setState(() => _isAdsLoading = false);
        await _solveMaze();
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
        _solveMaze();
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
        _solveMaze();
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
  // MAZE LOGIC
  // ============================================================
  void _newMaze() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      won = false;
      solving = false;
      moves = 0;
      seconds = 0;
      started = false;
      _showEmbers = false;
      _emberParticles.clear();
      solvePath = [];
      drawnSolvePathIndex = 0;
      _confettiController.stop();
      _generateMaze();
      visitedSet = {'0,0'};
    });
  }

  void _generateMaze() {
    grid = List.generate(rows, (r) => List.generate(cols, (c) => Cell()));
    final stack = [Position(0, 0)];
    grid[0][0].visited = true;

    while (stack.isNotEmpty) {
      final current = stack.last;
      final neighbors = <Position>[];

      if (current.r > 0 && !grid[current.r - 1][current.c].visited) {
        neighbors.add(Position(current.r - 1, current.c));
      }
      if (current.c < cols - 1 && !grid[current.r][current.c + 1].visited) {
        neighbors.add(Position(current.r, current.c + 1));
      }
      if (current.r < rows - 1 && !grid[current.r + 1][current.c].visited) {
        neighbors.add(Position(current.r + 1, current.c));
      }
      if (current.c > 0 && !grid[current.r][current.c - 1].visited) {
        neighbors.add(Position(current.r, current.c - 1));
      }

      if (neighbors.isNotEmpty) {
        final next = neighbors[_random.nextInt(neighbors.length)];
        if (next.r < current.r) {
          grid[current.r][current.c].top = false;
          grid[next.r][next.c].bottom = false;
        } else if (next.r > current.r) {
          grid[current.r][current.c].bottom = false;
          grid[next.r][next.c].top = false;
        } else if (next.c < current.c) {
          grid[current.r][current.c].left = false;
          grid[next.r][next.c].right = false;
        } else if (next.c > current.c) {
          grid[current.r][current.c].right = false;
          grid[next.r][next.c].left = false;
        }
        grid[next.r][next.c].visited = true;
        stack.add(next);
      } else {
        stack.removeLast();
      }
    }

    grid[0][0].top = false;
    grid[rows - 1][cols - 1].right = false;
    player = Position(0, 0);
    goal = Position(rows - 1, cols - 1);
  }

  List<Position> _findPath() {
    final queue = <List<Position>>[
      [player]
    ];
    final visited = <String>{'${player.r},${player.c}'};

    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final current = path.last;

      if (current.r == goal.r && current.c == goal.c) {
        return path;
      }

      final cell = grid[current.r][current.c];
      final neighbors = <Position>[];

      if (!cell.top && current.r > 0) {
        neighbors.add(Position(current.r - 1, current.c));
      }
      if (!cell.right && current.c < cols - 1) {
        neighbors.add(Position(current.r, current.c + 1));
      }
      if (!cell.bottom && current.r < rows - 1) {
        neighbors.add(Position(current.r + 1, current.c));
      }
      if (!cell.left && current.c > 0) {
        neighbors.add(Position(current.r, current.c - 1));
      }

      for (final neighbor in neighbors) {
        final key = '${neighbor.r},${neighbor.c}';
        if (!visited.contains(key)) {
          visited.add(key);
          queue.add([...path, neighbor]);
        }
      }
    }
    return [];
  }

  Future<void> _solveMaze() async {
    if (won || solving) return;

    setState(() {
      solving = true;
      solvePath = _findPath();
      drawnSolvePathIndex = 0;
    });

    if (solvePath.isEmpty) {
      setState(() => solving = false);
      return;
    }

    if (!started) {
      started = true;
      _startTimer();
    }

    for (int i = 1; i < solvePath.length; i++) {
      if (!solving) break;
      final next = solvePath[i];
      setState(() {
        player = next;
        moves++;
        final key = '${next.r},${next.c}';
        if (!visitedSet.contains(key)) {
          visitedSet.add(key);
        }
        drawnSolvePathIndex = i;
      });
      await Future.delayed(const Duration(milliseconds: 180));

      if (next.r == goal.r && next.c == goal.c) {
        _winGame();
        break;
      }
    }

    setState(() => solving = false);
  }

  void _move(Direction dir) {
    if (won || solving) return;

    final cell = grid[player.r][player.c];
    int nr = player.r, nc = player.c;

    switch (dir) {
      case Direction.up:
        if (!cell.top && player.r > 0)
          nr--;
        else
          return;
        break;
      case Direction.down:
        if (!cell.bottom && player.r < rows - 1)
          nr++;
        else
          return;
        break;
      case Direction.left:
        if (!cell.left && player.c > 0)
          nc--;
        else
          return;
        break;
      case Direction.right:
        if (!cell.right && player.c < cols - 1)
          nc++;
        else
          return;
        break;
    }

    setState(() {
      player = Position(nr, nc);
      moves++;
      final key = '${nr},${nc}';
      if (!visitedSet.contains(key)) {
        visitedSet.add(key);
      }
    });

    if (!started) {
      started = true;
      _startTimer();
    }

    if (nr == goal.r && nc == goal.c) {
      _winGame();
    }
  }

  void _winGame() {
    setState(() {
      won = true;
      _timer?.cancel();
      _timer = null;
      _showEmbers = true;
      _launchEmbers();
    });
    _showWinPopup();
  }

  void _startTimer() {
    _timer?.cancel();
    if (!won) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!won && mounted) {
          setState(() => seconds++);
        } else {
          timer.cancel();
          _timer = null;
        }
      });
    }
  }

  String _formatTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  // ============================================================
  // EMBER PARTICLES
  // ============================================================
  void _launchEmbers() {
    _emberParticles.clear();
    final size = MediaQuery.of(context).size;

    for (int i = 0; i < 100; i++) {
      _emberParticles.add(
        EmberParticle(
          x: size.width / 2 + (_random.nextDouble() - 0.5) * 200,
          y: size.height / 2 + (_random.nextDouble() - 0.5) * 200,
          vx: (_random.nextDouble() - 0.5) * 8,
          vy: (_random.nextDouble() - 0.5) * 8 - 4,
          size: 3 + _random.nextDouble() * 6,
          life: 1.0,
        ),
      );
    }
    _confettiController.repeat();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showEmbers = false;
          _emberParticles.clear();
          _confettiController.stop();
        });
      }
    });
  }

  void _updateEmbers() {
    for (final p in _emberParticles) {
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.05;
      p.life -= 0.01;
    }
    _emberParticles.removeWhere((p) => p.life <= 0);
  }

  // ============================================================
  // POPUP
  // ============================================================
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
              '🔥 Out of the dark!',
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
            Text(
              '${moves} moves, ${_formatTime(seconds)} in the dark.',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3a2a1a),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _newMaze();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3a2a1a),
            ),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _newMaze();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: const Color(0xFF2c1f00),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Descend Again'),
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
    final cellSize = boardSize / cols;
    final playerSize = cellSize * 0.52;

    return Scaffold(
      backgroundColor: const Color(0xFFd6eaf8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: RichText(
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0a1a3a),
            ),
            children: [
              TextSpan(text: 'EMBER '),
              TextSpan(
                text: 'MAZE',
                style: TextStyle(color: Color(0xFFe55b1e)),
              ),
            ],
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0a1a3a)),
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
              // Top controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border:
                          Border.all(color: const Color(0xFFc9b896), width: 1),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: cols,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3b2e20),
                        ),
                        items: const [
                          DropdownMenuItem(value: 12, child: Text('Small')),
                          DropdownMenuItem(value: 16, child: Text('Medium')),
                          DropdownMenuItem(value: 20, child: Text('Large')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              cols = value;
                              rows = value + 4;
                              _newMaze();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // D-Pad
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: const Color(0x1A0a1a3a)),
                    ),
                    child: Row(
                      children: [
                        _DpadButton(
                          icon: '▲',
                          onTap:
                              _isAdsLoading ? null : () => _move(Direction.up),
                        ),
                        _DpadButton(
                          icon: '▼',
                          onTap: _isAdsLoading
                              ? null
                              : () => _move(Direction.down),
                        ),
                        _DpadButton(
                          icon: '◀',
                          onTap: _isAdsLoading
                              ? null
                              : () => _move(Direction.left),
                        ),
                        _DpadButton(
                          icon: '▶',
                          onTap: _isAdsLoading
                              ? null
                              : () => _move(Direction.right),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Maze
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: const Color(0xFF0a1a3a), width: 1.5),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        painter: MazePainter(
                          grid: grid,
                          cols: cols,
                          rows: rows,
                          cellSize: cellSize,
                          player: player,
                          goal: goal,
                          visitedSet: visitedSet,
                          solvePath: solvePath,
                          drawnSolvePathIndex: drawnSolvePathIndex,
                          won: won,
                        ),
                        child: Stack(
                          children: [
                            // Player
                            Positioned(
                              left: (player.c * cellSize + cellSize / 2) -
                                  playerSize / 2,
                              top: (player.r * cellSize + cellSize / 2) -
                                  playerSize / 2,
                              child: Container(
                                width: playerSize,
                                height: playerSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: const [
                                      Color(0xFFfff6d8),
                                      Color(0xFFe55b1e),
                                      Color(0xFF8b2e0a)
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFd4a017)
                                          .withOpacity(0.8),
                                      blurRadius: 18,
                                      spreadRadius: 4,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFFf0c75e)
                                          .withOpacity(0.4),
                                      blurRadius: 40,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Exit
                            Positioned(
                              left: (goal.c * cellSize + cellSize / 2) - 10,
                              top: (goal.r * cellSize + cellSize / 2) - 10,
                              child: const Text(
                                '🔥',
                                style: TextStyle(fontSize: 20),
                              ),
                            ),
                            // Win Overlay
                            if (won && !_showEmbers)
                              Positioned.fill(
                                child: Container(
                                  color: const Color(0xCCf5f0e6),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '🔥 Out of the dark!',
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF8b2e0a),
                                            fontFamily: 'Cinzel',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${moves} moves, ${_formatTime(seconds)} in the dark.',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF5f5346),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed:
                                              _isAdsLoading ? null : _newMaze,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF8b2e0a),
                                            foregroundColor:
                                                const Color(0xFFfff2e2),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 28,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text('Descend Again'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            // Embers
                            if (_showEmbers)
                              CustomPaint(
                                size: Size(boardSize, boardSize),
                                painter: EmberPainter(_emberParticles),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Controls
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5a7a6a),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(0, 4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _formatTime(seconds),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5a7a6a),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(0, 4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$moves',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: 'New',
                    color: const Color(0xFF2d7a5c),
                    onPressed: _isAdsLoading ? null : _newMaze,
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: 'Solve',
                    color: const Color(0xFF4a90d9),
                    onPressed: (won || solving || _isAdsLoading)
                        ? null
                        : _showRewardedForSolve,
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

class Cell {
  bool top = true;
  bool right = true;
  bool bottom = true;
  bool left = true;
  bool visited = false;
}

class Position {
  final int r;
  final int c;
  const Position(this.r, this.c);

  @override
  bool operator ==(Object other) {
    return other is Position && other.r == r && other.c == c;
  }

  @override
  int get hashCode => r.hashCode ^ c.hashCode;
}

enum Direction { up, down, left, right }

class EmberParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double life;

  EmberParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
  });
}

// ============================================================
// CUSTOM PAINTERS
// ============================================================

class MazePainter extends CustomPainter {
  final List<List<Cell>> grid;
  final int cols;
  final int rows;
  final double cellSize;
  final Position player;
  final Position goal;
  final Set<String> visitedSet;
  final List<Position> solvePath;
  final int drawnSolvePathIndex;
  final bool won;

  MazePainter({
    required this.grid,
    required this.cols,
    required this.rows,
    required this.cellSize,
    required this.player,
    required this.goal,
    required this.visitedSet,
    required this.solvePath,
    required this.drawnSolvePathIndex,
    required this.won,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw visited trail
    for (final key in visitedSet) {
      final parts = key.split(',');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      paint.color = const Color(0x40d4a017);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(c * cellSize + cellSize / 2, r * cellSize + cellSize / 2),
        cellSize * 0.3,
        paint,
      );
    }

    // Draw solve path
    if (solvePath.length > 1 && drawnSolvePathIndex > 0) {
      paint.color = const Color(0xFFd4a017);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 5;
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final path = Path();
      path.moveTo(
        solvePath[0].c * cellSize + cellSize / 2,
        solvePath[0].r * cellSize + cellSize / 2,
      );
      for (int i = 1; i <= drawnSolvePathIndex && i < solvePath.length; i++) {
        path.lineTo(
          solvePath[i].c * cellSize + cellSize / 2,
          solvePath[i].r * cellSize + cellSize / 2,
        );
      }
      canvas.drawPath(path, paint);

      paint.color = const Color(0xFFf0c75e);
      paint.strokeWidth = 3;
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, paint);

      paint.color = const Color(0xFFFFF8DC);
      paint.strokeWidth = 1.5;
      paint.maskFilter = null;
      canvas.drawPath(path, paint);
    }

    // Draw walls
    paint.color = const Color(0xFF2e241a);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.6;
    paint.maskFilter = null;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cell = grid[r][c];
        final x = c * cellSize;
        final y = r * cellSize;
        final path = Path();

        if (cell.top) {
          path.moveTo(x, y);
          path.lineTo(x + cellSize, y);
        }
        if (cell.right) {
          path.moveTo(x + cellSize, y);
          path.lineTo(x + cellSize, y + cellSize);
        }
        if (cell.bottom) {
          path.moveTo(x, y + cellSize);
          path.lineTo(x + cellSize, y + cellSize);
        }
        if (cell.left) {
          path.moveTo(x, y);
          path.lineTo(x, y + cellSize);
        }
        canvas.drawPath(path, paint);
      }
    }

    // Border
    paint.color = const Color(0xFF2e241a);
    paint.strokeWidth = 3.2;
    canvas.drawRect(
      Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class EmberPainter extends CustomPainter {
  final List<EmberParticle> particles;

  EmberPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = const Color(0xFFe55b1e).withOpacity(p.life)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================
// BUTTONS
// ============================================================

class _DpadButton extends StatelessWidget {
  final String icon;
  final VoidCallback? onTap;

  const _DpadButton({
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFfaf3e8), Color(0xFFe7d7bc)],
          ),
          border: Border.all(color: const Color(0xFFb1976e), width: 1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            icon,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF8b2e0a),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  offset: const Offset(0, 4),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
