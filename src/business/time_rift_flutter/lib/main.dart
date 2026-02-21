import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'models.dart';
import 'game_logic.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => GameLogic(),
      child: const TimeRiftApp(),
    ),
  );
}

class TimeRiftApp extends StatelessWidget {
  const TimeRiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Time Rift: One Step Away',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: GameColors.background,
        textTheme: GoogleFonts.courierPrimeTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: GameColors.text,
          displayColor: GameColors.text,
        ),
        colorScheme: const ColorScheme.dark(
          primary: GameColors.accent,
          secondary: GameColors.collapsing,
        ),
      ),
      home: const MainMenuScreen(),
    );
  }
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TIME RIFT',
              style: GoogleFonts.orbitron(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: GameColors.accent,
                shadows: [
                  const Shadow(blurRadius: 10, color: GameColors.accent),
                ],
              ),
            ).animate().fadeIn().scale(),
            const SizedBox(height: 10),
            Text(
              'ONE STEP AWAY',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 50),
            _buildMenuButton(context, 'START GAME', GameMode.normal),
            _buildMenuButton(context, 'DAILY CHALLENGE', GameMode.daily),
            _buildMenuButton(context, 'BLIND MODE', GameMode.blind),
            _buildMenuButton(context, 'BOSS RUSH', GameMode.boss),
            const SizedBox(height: 30),
            const LeaderboardWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String label, GameMode mode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: GameColors.accent, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          Provider.of<GameLogic>(context, listen: false).startGame(mode);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GameScreen()),
          );
        },
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, color: GameColors.accent, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Gesture Debounce
  bool _canMove = true;

  @override
  Widget build(BuildContext context) {
    final logic = Provider.of<GameLogic>(context);

    // Handle Win/Loss Navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (logic.state == GameState.won) {
        _showOverlay(context, "LEVEL CLEARED", "Press Next", () {
           logic.startLevel(logic.level + 1);
           Navigator.pop(context); 
        });
      } else if (logic.state == GameState.lost) {
        _showOverlay(context, "GAME OVER", "Retry", () {
           logic.startLevel(logic.level);
           Navigator.pop(context);
        });
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // HUD
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStat("LEVEL", "${logic.level}"),
                  _buildStat("ENERGY", "${logic.energy}", color: logic.energy < 10 ? Colors.red : GameColors.accent),
                  _buildStat("STEPS", "${logic.steps}"),
                ],
              ),
            ),
            
            if (logic.freezeTurns > 0)
              Text("TIME FROZEN: ${logic.freezeTurns}", style: TextStyle(color: GameColors.frozen, fontWeight: FontWeight.bold)),
            
            if (logic.message != null)
               Padding(
                 padding: const EdgeInsets.all(8.0),
                 child: Text(logic.message!, style: const TextStyle(color: GameColors.accent, fontWeight: FontWeight.bold)).animate().fadeIn().fadeOut(delay: 2.seconds),
               ),

            // Game Grid
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Listener(
                    onPointerDown: (_) => _canMove = true,
                    onPointerMove: (details) {
                      if (!_canMove || logic.state != GameState.playing) return;
                      
                      // Sensitivity Threshold
                      const double sensitivity = 10.0; 
                      
                      if (details.delta.dx.abs() > details.delta.dy.abs()) {
                        if (details.delta.dx.abs() > sensitivity) {
                          _handleMove(logic, details.delta.dx > 0 ? 1 : -1, 0);
                        }
                      } else {
                        if (details.delta.dy.abs() > sensitivity) {
                          _handleMove(logic, 0, details.delta.dy > 0 ? 1 : -1);
                        }
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: GameColors.accent, width: 2),
                        boxShadow: [BoxShadow(color: GameColors.accent.withOpacity(0.2), blurRadius: 20)],
                      ),
                      child: Stack(
                        children: [
                           // Grid Cells
                           GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              crossAxisSpacing: 2,
                              mainAxisSpacing: 2,
                            ),
                            itemCount: 36,
                            itemBuilder: (context, index) {
                              int x = index % 6;
                              int y = index ~/ 6;
                              return _buildCell(context, logic, x, y);
                            },
                          ),
                          // Animated Player Layer
                          _buildAnimatedPlayer(logic),
                          // Animated Boss Layer
                          if (logic.boss != null) _buildAnimatedBoss(logic),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Abilities
            Padding(
              padding: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAbilityBtn(context, "REWIND", logic.rewindCount, logic.useRewind, Icons.replay),
                  _buildAbilityBtn(context, "SWAP", logic.swapCount, logic.useSwap, Icons.swap_horiz),
                  _buildAbilityBtn(context, "FREEZE", logic.freezeCount, logic.useFreeze, Icons.ac_unit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMove(GameLogic logic, int dx, int dy) {
    logic.movePlayer(dx, dy);
    HapticFeedback.lightImpact();
    _canMove = false; // Debounce until next touch down/pause? 
    // Actually for swipe, we want to allow rapid swipes but not "one long drag triggers 10 moves".
    // "Listener" with "onPointerMove" triggers every frame.
    // So we MUST lock it.
    // We can unlock it after a short delay or require lifting finger?
    // Let's unlock after 200ms to allow rapid subsequent swipes?
    // Better: Only one move per "fling".
    Future.delayed(const Duration(milliseconds: 150), () => _canMove = true);
  }

  Widget _buildAnimatedPlayer(GameLogic logic) {
     return AnimatedAlign(
      duration: 150.ms,
      curve: Curves.easeOutQuad,
      alignment: Alignment(
        (logic.playerPos.x / 5) * 2 - 1, // Map 0..5 to -1..1
        (logic.playerPos.y / 5) * 2 - 1
      ),
      child: Container(
        width: MediaQuery.of(context).size.width / 7, // Approx cell size
        height: MediaQuery.of(context).size.width / 7,
        decoration: BoxDecoration(
          color: GameColors.player,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 10)]
        ),
        margin: const EdgeInsets.all(4), // visual adjustment
      ),
    );
  }
  
  Widget _buildAnimatedBoss(GameLogic logic) {
     if (logic.boss == null) return const SizedBox.shrink();
     return AnimatedAlign(
      duration: 300.ms,
      curve: Curves.easeInOut,
      alignment: Alignment(
        (logic.boss!.x / 5) * 2 - 1,
        (logic.boss!.y / 5) * 2 - 1
      ),
      child: const Icon(Icons.android, color: GameColors.boss, size: 30),
    );
  }

  Widget _buildCell(BuildContext context, GameLogic logic, int x, int y) {
    Cell cell = logic.grid[y][x];
    // isPlayer/isBoss logic removed here as they are now overlay layers
    bool isGoal = logic.goalPos.x == x && logic.goalPos.y == y;

    Color bg = GameColors.normal;
    Widget? content;

    // Cell Type Styling
    switch (cell.type) {
      case CellType.collapsing:
        bg = GameColors.collapsing.withOpacity(0.3);
        if (logic.mode == GameMode.blind) bg = GameColors.normal; 
        break;
      case CellType.frozen:
        bg = GameColors.frozen.withOpacity(0.3);
        break;
      case CellType.rift:
        bg = GameColors.rift;
        break;
      case CellType.stable:
        bg = GameColors.stable.withOpacity(0.3);
        break;
      case CellType.normal:
        bg = GameColors.normal;
        break;
      case CellType.boss:
        break; 
    }

    if (isGoal) {
      content = const Icon(Icons.flag, color: GameColors.stable);
    }

    if (cell.type == CellType.collapsing && logic.mode != GameMode.blind) {
      content = Center(
        child: Text(
          "${cell.timer}", 
          style: const TextStyle(color: GameColors.collapsing, fontWeight: FontWeight.bold)
        ),
      );
    }
    
    // We don't render player/boss here anymore to allow smooth animation on top

    return Container(
      color: bg,
      child: content,
    );
  }
  
  // ... _buildStat, _buildAbilityBtn, _showOverlay ... (keep as is, or assume they are part of the class)
  
  Widget _buildStat(String label, String value, {Color color = Colors.white}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildAbilityBtn(BuildContext context, String label, int count, VoidCallback onTap, IconData icon) {
    bool disabled = count <= 0;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.3 : 1.0,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10),
                color: Colors.black45,
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 5),
            Text("$label ($count)", style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _showOverlay(BuildContext context, String title, String btnLabel, VoidCallback onBtn) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        title: Text(title, style: const TextStyle(color: GameColors.accent), textAlign: TextAlign.center),
        content: const Text("Keep going!", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: onBtn,
              style: ElevatedButton.styleFrom(backgroundColor: GameColors.accent),
              child: Text(btnLabel, style: const TextStyle(color: Colors.black)),
            ),
          )
        ],
      ),
    );
  }
}


class LeaderboardWidget extends StatelessWidget {
  const LeaderboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Provider.of<GameLogic>(context);
    var entries = logic.bestScores.entries.toList();
    entries.sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

    return Container(
      height: 150,
      width: 300,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Text("BEST RUNS", style: TextStyle(color: Colors.grey)),
          const Divider(color: Colors.white12),
          Expanded(
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (ctx, i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Level ${entries[i].key}", style: const TextStyle(color: GameColors.accent)),
                      Text("${entries[i].value} steps", style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
