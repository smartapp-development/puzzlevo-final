import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const Text(
          'View our privacy policy at:\n'
          'https://smartapp-development.github.io/puzzlevo-privacy-policy/',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth <= 540;

    return Scaffold(
      backgroundColor: const Color(0xFFf5f7fa),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              Column(
                children: [
                  Text(
                    'Puzzlevo',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 38 : 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      color: const Color(0xFF1a237e),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Challenge your mind with 5 classic games',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 14 : 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748b),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Game Buttons
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _GameButton(
                        title: 'Sudoku',
                        color: const Color(0xFF059669),
                        onTap: () => Navigator.pushNamed(context, '/sudoku'),
                      ),
                      const SizedBox(height: 12),
                      _GameButton(
                        title: 'Number Puzzle',
                        color: const Color(0xFFd97706),
                        onTap: () =>
                            Navigator.pushNamed(context, '/numberpuzzle'),
                      ),
                      const SizedBox(height: 12),
                      _GameButton(
                        title: 'Word Search',
                        color: const Color(0xFF7c3aed),
                        onTap: () =>
                            Navigator.pushNamed(context, '/wordsearch'),
                      ),
                      const SizedBox(height: 12),
                      _GameButton(
                        title: 'Ember Maze',
                        color: const Color(0xFFe55b1e),
                        onTap: () => Navigator.pushNamed(context, '/embermaze'),
                      ),
                      const SizedBox(height: 12),
                      _GameButton(
                        title: 'Tic-Tac-Toe',
                        color: const Color(0xFF1f6fb0),
                        onTap: () => Navigator.pushNamed(context, '/tictactoe'),
                      ),
                      // Jigsaw REMOVED
                    ],
                  ),
                ),
              ),

              // Footer
              const SizedBox(height: 8),
              Text(
                'Select a game to start playing',
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 12.5 : 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94a3b8),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _showPrivacyPolicyDialog(context),
                child: Text(
                  'Privacy Policy',
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 14.7 : 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1a237e),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameButton extends StatefulWidget {
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _GameButton({
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  State<_GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<_GameButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 540;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 28,
          vertical: isMobile ? 20 : 22,
        ),
        decoration: BoxDecoration(
          color: _isPressed ? widget.color.withOpacity(0.8) : widget.color,
          borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.25),
              blurRadius: _isPressed ? 8 : 12,
              offset: Offset(0, _isPressed ? 2 : 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: isMobile
                    ? (MediaQuery.of(context).size.width <= 380 ? 15 : 16)
                    : 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              '›',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(_isPressed ? 0.6 : 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
