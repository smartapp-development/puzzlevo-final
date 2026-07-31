import 'package:flutter/material.dart';
import 'screens/intro_screen.dart';
import 'screens/main_screen.dart';
import 'screens/sudoku_screen.dart';
import 'screens/number_puzzle_screen.dart';
import 'screens/word_search_screen.dart';
import 'screens/ember_maze_screen.dart';
import 'screens/tictactoe_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Puzzlevo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0a1928)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const IntroScreen(),
        '/main': (context) => const MainScreen(),
        '/sudoku': (context) => const SudokuScreen(),
        '/numberpuzzle': (context) => const NumberPuzzleScreen(),
        '/wordsearch': (context) => const WordSearchScreen(),
        '/embermaze': (context) => const EmberMazeScreen(),
        '/tictactoe': (context) => const TicTacToeScreen(),
      },
    );
  }
}