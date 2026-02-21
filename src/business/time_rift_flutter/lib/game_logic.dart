import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class GameLogic extends ChangeNotifier {
  static const int gridSize = 6;
  
  // State
  int level = 1;
  int energy = 100;
  int steps = 0;
  List<List<Cell>> grid = [];
  Position playerPos = const Position(0, 0);
  Position goalPos = const Position(gridSize - 1, 0);
  
  // Abilities
  int rewindCount = 0;
  int swapCount = 0;
  int freezeCount = 0;
  int freezeTurns = 0;
  
  // Game Status
  GameState state = GameState.menu;
  GameMode mode = GameMode.normal;
  List<HistoryState> history = [];
  BossEntity? boss;
  
  // Leaderboard
  Map<String, int> bestScores = {};
  String? message; // UI Feedback

  GameLogic() {
    loadScores();
  }

  void startGame(GameMode gameMode) {
    mode = gameMode;
    startLevel(1);
  }

  void startLevel(int lvl) {
    level = lvl;
    state = GameState.playing;
    steps = 0;
    freezeTurns = 0;
    history.clear();
    boss = null;
    
    // Ability Calculation
    rewindCount = 1 + (level ~/ 3);
    swapCount = 1 + (level ~/ 5);
    freezeCount = 1 + (level ~/ 5);

    // Boss Spawn
    if (mode == GameMode.boss || (mode == GameMode.normal && level % 5 == 0)) {
      boss = BossEntity(gridSize ~/ 2, gridSize ~/ 2);
    }

    generateLevel();
    saveHistory();
    notifyListeners();
  }

  void generateLevel() {
    // Initialize Grid
    grid = List.generate(gridSize, (y) => List.generate(gridSize, (x) => Cell(x: x, y: y)));
    playerPos = Position(0, gridSize - 1);
    goalPos = Position(gridSize - 1, 0);
    grid[goalPos.y][goalPos.x].type = CellType.stable;

    // Guaranteed Path
    Random rng = _getSeededRandom();
    bool pathFound = false;
    Set<String> pathSet = {};
    int attempts = 0;

    while (!pathFound && attempts < 50) {
      pathSet.clear();
      Position walker = Position(playerPos.x, playerPos.y);
      pathSet.add(walker.toString());
      int maxSteps = gridSize * gridSize;

      while (walker != goalPos && maxSteps > 0) {
        List<Position> moves = [];
        if (walker.x < goalPos.x) moves.add(Position(walker.x + 1, walker.y));
        if (walker.x > goalPos.x) moves.add(Position(walker.x - 1, walker.y));
        if (walker.y < goalPos.y) moves.add(Position(walker.x, walker.y + 1));
        if (walker.y > goalPos.y) moves.add(Position(walker.x, walker.y - 1));

        // Randomness
        if (rng.nextDouble() < 0.4) {
           double r = rng.nextDouble();
           if (r < 0.25) moves.add(Position(walker.x + 1, walker.y));
           else if (r < 0.5) moves.add(Position(walker.x - 1, walker.y));
           else if (r < 0.75) moves.add(Position(walker.x, walker.y + 1));
           else moves.add(Position(walker.x, walker.y - 1));
        }

        // Filter valid
        moves = moves.where((p) => p.x >= 0 && p.x < gridSize && p.y >= 0 && p.y < gridSize).toList();

        if (moves.isNotEmpty) {
          walker = moves[rng.nextInt(moves.length)];
          pathSet.add(walker.toString());
        }
        maxSteps--;
      }
      if (walker == goalPos) pathFound = true;
      attempts++;
    }

    // Fallback path if failed
    if (!pathFound) {
      for (int x = playerPos.x; x <= goalPos.x; x++) pathSet.add('$x,${playerPos.y}');
      for (int y = playerPos.y; y >= goalPos.y; y--) pathSet.add('${goalPos.x},$y');
    }

    // Fill Grid
    double difficulty = min(level * 0.1, 0.9);
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if ((x == playerPos.x && y == playerPos.y) || (x == goalPos.x && y == goalPos.y)) continue;
        
        bool isPath = pathSet.contains('$x,$y');
        Cell cell = grid[y][x];
        double r = rng.nextDouble();

        if (isPath) {
           if (r < 0.3 + (difficulty * 0.1)) {
             cell.type = CellType.collapsing;
             int dist = (x - playerPos.x).abs() + (y - playerPos.y).abs();
             cell.maxTimer = dist + 5 + rng.nextInt(3);
             cell.timer = cell.maxTimer;
           }
        } else {
           if (r < 0.3 + (difficulty * 0.2)) {
             cell.type = CellType.collapsing;
             cell.maxTimer = 2 + rng.nextInt(4);
             cell.timer = cell.maxTimer;
           } else if (r < 0.45 + (difficulty * 0.1)) {
             cell.type = CellType.frozen;
           } else if (r < 0.6 + (difficulty * 0.1)) {
             cell.type = CellType.rift;
           }
        }
      }
    }

    // Ensure Connectivity
    if (!checkConnectivity()) {
      for (String key in pathSet) {
        List<String> parts = key.split(',');
        int px = int.parse(parts[0]);
        int py = int.parse(parts[1]);
        if (grid[py][px].type == CellType.rift) {
          grid[py][px].type = CellType.normal;
        }
      }
    }

    // Energy Calculation
    int minSteps = getShortestPathDistance();
    int buffer = (mode == GameMode.boss) ? 8 : 3;
    energy = minSteps + buffer;
    if (energy < minSteps + 2) energy = minSteps + 2;
  }

  Random _getSeededRandom() {
    if (mode == GameMode.daily) {
      String today = DateTime.now().toIso8601String().split('T')[0];
      int seed = today.hashCode;
      return Random(seed);
    }
    return Random();
  }

  bool checkConnectivity([Position? ignore]) {
    List<Position> queue = [playerPos];
    Set<String> visited = {playerPos.toString()};
    
    while (queue.isNotEmpty) {
      Position current = queue.removeAt(0);
      if (current == goalPos) return true;
      
      List<Position> moves = [
        Position(current.x + 1, current.y),
        Position(current.x - 1, current.y),
        Position(current.x, current.y + 1),
        Position(current.x, current.y - 1),
      ];
      
      for (var m in moves) {
        if (m.x >= 0 && m.x < gridSize && m.y >= 0 && m.y < gridSize) {
          if (ignore != null && m == ignore) continue;
          if (!visited.contains(m.toString())) {
             if (grid[m.y][m.x].type != CellType.rift) {
               visited.add(m.toString());
               queue.add(m);
             }
          }
        }
      }
    }
    return false;
  }

  int getShortestPathDistance() {
    List<Map<String, dynamic>> queue = [{'pos': playerPos, 'dist': 0}];
    Set<String> visited = {playerPos.toString()};
    
    while (queue.isNotEmpty) {
      var current = queue.removeAt(0);
      Position p = current['pos'];
      int dist = current['dist'];
      
      if (p == goalPos) return dist;
      
      List<Position> moves = [
        Position(p.x + 1, p.y),
        Position(p.x - 1, p.y),
        Position(p.x, p.y + 1),
        Position(p.x, p.y - 1),
      ];

      for (var m in moves) {
        if (m.x >= 0 && m.x < gridSize && m.y >= 0 && m.y < gridSize) {
          if (!visited.contains(m.toString())) {
            if (grid[m.y][m.x].type != CellType.rift) {
              visited.add(m.toString());
              queue.add({'pos': m, 'dist': dist + 1});
            }
          }
        }
      }
    }
    return 999;
  }

  void movePlayer(int dx, int dy) {
    if (state != GameState.playing) return;

    int nx = playerPos.x + dx;
    int ny = playerPos.y + dy;

    if (nx < 0 || nx >= gridSize || ny < 0 || ny >= gridSize) return;

    Cell target = grid[ny][nx];
    if (target.type == CellType.rift) {
       // Cannot move into rift (visual shake needed)
       return;
    }
    
    if (boss != null && boss!.x == nx && boss!.y == ny) {
       // Cannot walk into boss
       return;
    }

    saveHistory();
    playerPos = Position(nx, ny);
    steps++;
    energy--;

    processTurn();
    _checkAndFixTrap(); // Auto-detect and fix impossible situations
    checkWinLoss();
    notifyListeners();
  }

  void _checkAndFixTrap() {
    // Check if player has NO valid moves (stuck)
    List<Position> moves = [
        Position(playerPos.x + 1, playerPos.y),
        Position(playerPos.x - 1, playerPos.y),
        Position(playerPos.x, playerPos.y + 1),
        Position(playerPos.x, playerPos.y - 1),
    ];
    
    bool stuck = true;
    for (var m in moves) {
        if (m.x >= 0 && m.x < gridSize && m.y >= 0 && m.y < gridSize) {
            if (grid[m.y][m.x].type != CellType.rift) {
                stuck = false;
                break;
            }
        }
    }

    if (stuck && energy > 5) {
        // "Time Paradox Detected" -> Fix it
        // Find a neighbor that is a Rift and turn it to Normal
        for (var m in moves) {
             if (m.x >= 0 && m.x < gridSize && m.y >= 0 && m.y < gridSize) {
                 if (grid[m.y][m.x].type == CellType.rift) {
                     grid[m.y][m.x].type = CellType.normal; // Restore path
                     message = "TIMELINE STABILIZED!";
                     notifyListeners();
                     
                     // Clear message after delay
                     Future.delayed(const Duration(seconds: 2), () {
                        message = null;
                        notifyListeners();
                     });
                     return;
                 }
             }
        }
    }
  }

  void processTurn() {
    if (freezeTurns > 0) {
      freezeTurns--;
      return;
    }

    // Boss Move
    if (boss != null) {
      if (Random().nextBool()) { // 50% chance to move? Or every 2 turns. Let's do random for now.
         int dx = playerPos.x - boss!.x;
         int dy = playerPos.y - boss!.y;
         int mx = 0, my = 0;
         if (dx.abs() > dy.abs()) {
           mx = dx > 0 ? 1 : -1;
         } else {
           my = dy > 0 ? 1 : -1;
         }
         int bx = boss!.x + mx;
         int by = boss!.y + my;
         
         if (bx >= 0 && bx < gridSize && by >= 0 && by < gridSize && !(bx == goalPos.x && by == goalPos.y)) {
           boss!.x = bx;
           boss!.y = by;
         }
      }
    }

    // Collapse
    for (var row in grid) {
      for (var cell in row) {
        if (cell.type == CellType.collapsing) {
          if (cell.timer > 0) {
            cell.timer--;
            if (cell.timer == 0) {
              cell.type = CellType.rift;
            }
          }
        }
      }
    }

    // Entropy (Random Rift generation)
    if (Random().nextDouble() < 0.15) {
       int rx = Random().nextInt(gridSize);
       int ry = Random().nextInt(gridSize);
       Cell cell = grid[ry][rx];
       
       if (!((rx == playerPos.x && ry == playerPos.y) || (rx == goalPos.x && ry == goalPos.y) || cell.type == CellType.rift)) {
         if (cell.type == CellType.normal && Random().nextDouble() < 0.4) {
            // Check if blocking path
            // Deep copy not needed for connectivity check unless we modify grid temporarily
            // We can pass the cell to ignore/modify
            // Let's modify and revert if false
            CellType oldType = cell.type;
            cell.type = CellType.rift; // Temporarily block
            if (checkConnectivity()) {
               cell.type = CellType.collapsing;
               cell.maxTimer = 4;
               cell.timer = 4;
            } else {
               cell.type = oldType; // Revert
            }
         }
       }
    }
  }

  void checkWinLoss() {
    if (playerPos == goalPos) {
      state = GameState.won;
      saveScore();
    } else if (energy <= 0) {
      state = GameState.lost;
    } else if (grid[playerPos.y][playerPos.x].type == CellType.rift) {
      state = GameState.lost;
    } else if (boss != null && playerPos.x == boss!.x && playerPos.y == boss!.y) {
      state = GameState.lost;
    }
  }

  // Abilities
  void useRewind() {
    if (rewindCount > 0 && history.isNotEmpty) {
      rewindCount--;
      HistoryState prev = history.removeLast();
      
      // Restore
      grid = prev.grid.map((row) => row.map((c) => c.clone()).toList()).toList();
      playerPos = prev.playerPos;
      energy = prev.energy;
      steps = prev.steps;
      freezeTurns = prev.freezeTurns;
      if (prev.bossEntity != null) {
        boss = prev.bossEntity!.clone();
      }
      notifyListeners();
    }
  }

  void useFreeze() {
    if (freezeCount > 0) {
      freezeCount--;
      freezeTurns = 5;
      saveHistory();
      notifyListeners();
    }
  }

  void useSwap() {
    if (swapCount > 0) {
      // Try random swap
      bool success = false;
      int attempts = 0;
      
      // Deep copy grid for restoration
      String originalGrid = _gridToString(); // Simple serialization for restore
      
      while (!success && attempts < 20) {
         if (attempts > 0) {
           _stringToGrid(originalGrid);
         }
         
         Position? c1 = _getRandomSwapCandidate();
         Position? c2 = _getRandomSwapCandidate();
         
         if (c1 != null && c2 != null && c1 != c2) {
            Cell cell1 = grid[c1.y][c1.x];
            Cell cell2 = grid[c2.y][c2.x];
            
            // Swap Data
            CellType tempType = cell1.type;
            int tempTimer = cell1.timer;
            int tempMax = cell1.maxTimer;
            
            cell1.type = cell2.type;
            cell1.timer = cell2.timer;
            cell1.maxTimer = cell2.maxTimer;
            
            cell2.type = tempType;
            cell2.timer = tempTimer;
            cell2.maxTimer = tempMax;
            
            if (checkConnectivity()) {
               success = true;
            }
         }
         attempts++;
      }
      
      if (success) {
        swapCount--;
        saveHistory();
        notifyListeners();
      } else {
        _stringToGrid(originalGrid); // Restore
      }
    }
  }

  Position? _getRandomSwapCandidate() {
    int x = Random().nextInt(gridSize);
    int y = Random().nextInt(gridSize);
    if ((x == playerPos.x && y == playerPos.y) || (x == goalPos.x && y == goalPos.y)) return null;
    return Position(x, y);
  }

  void saveHistory() {
    if (history.length > 10) history.removeAt(0);
    
    // Deep copy grid
    List<List<Cell>> gridCopy = grid.map((row) => row.map((c) => c.clone()).toList()).toList();
    
    history.add(HistoryState(
      grid: gridCopy,
      playerPos: playerPos,
      energy: energy,
      steps: steps,
      freezeTurns: freezeTurns,
      bossEntity: boss?.clone()
    ));
  }

  // Helpers for Swap (Naive serialization)
  String _gridToString() {
     // Just save types/timers
     return grid.map((row) => row.map((c) => "${c.type.index}:${c.timer}:${c.maxTimer}").join(",")).join("|");
  }
  
  void _stringToGrid(String s) {
     List<String> rows = s.split("|");
     for (int y = 0; y < gridSize; y++) {
       List<String> cols = rows[y].split(",");
       for (int x = 0; x < gridSize; x++) {
          List<String> data = cols[x].split(":");
          grid[y][x].type = CellType.values[int.parse(data[0])];
          grid[y][x].timer = int.parse(data[1]);
          grid[y][x].maxTimer = int.parse(data[2]);
       }
     }
  }

  // Persistence
  Future<void> loadScores() async {
    final prefs = await SharedPreferences.getInstance();
    // Assuming JSON string or simple keys
    // Let's use simple keys "score_level_X"
    // But for map, we can just load one by one or store JSON
    // Simplest: store JSON string
    String? json = prefs.getString('time_rift_scores');
    if (json != null) {
       // Manual parse since jsonDecode returns dynamic
       // "1:10,2:15"
       List<String> entries = json.split(",");
       for (var e in entries) {
          if (e.isNotEmpty) {
             var parts = e.split(":");
             bestScores[parts[0]] = int.parse(parts[1]);
          }
       }
    }
    notifyListeners();
  }

  Future<void> saveScore() async {
    String key = level.toString();
    if (!bestScores.containsKey(key) || steps < bestScores[key]!) {
      bestScores[key] = steps;
      final prefs = await SharedPreferences.getInstance();
      String data = bestScores.entries.map((e) => "${e.key}:${e.value}").join(",");
      await prefs.setString('time_rift_scores', data);
      notifyListeners();
    }
  }
}
