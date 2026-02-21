import 'package:flutter/material.dart';

enum CellType {
  normal,
  collapsing,
  frozen,
  rift,
  stable, // Goal
  boss
}

enum GameState {
  menu,
  playing,
  won,
  lost
}

enum GameMode {
  normal,
  daily,
  blind,
  boss
}

class Position {
  final int x;
  final int y;

  const Position(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
  
  @override
  String toString() => '$x,$y';
}

class Cell {
  CellType type;
  int timer;
  int maxTimer;
  final int x;
  final int y;

  Cell({
    required this.x,
    required this.y,
    this.type = CellType.normal,
    this.timer = 0,
    this.maxTimer = 0,
  });

  // Deep copy for history
  Cell clone() {
    return Cell(x: x, y: y, type: type, timer: timer, maxTimer: maxTimer);
  }
}

class BossEntity {
  int x;
  int y;
  
  BossEntity(this.x, this.y);
  
  BossEntity clone() => BossEntity(x, y);
}

class HistoryState {
  final List<List<Cell>> grid;
  final Position playerPos;
  final int energy;
  final int steps;
  final int freezeTurns;
  final BossEntity? bossEntity;

  HistoryState({
    required this.grid,
    required this.playerPos,
    required this.energy,
    required this.steps,
    required this.freezeTurns,
    this.bossEntity,
  });
}

class GameColors {
  static const Color background = Color(0xFF1a1a1d);
  static const Color normal = Color(0xFF444444);
  static const Color collapsing = Color(0xFFff3366);
  static const Color frozen = Color(0xFF33ccff);
  static const Color rift = Color(0xFF111111);
  static const Color stable = Color(0xFF33ff66);
  static const Color player = Colors.white;
  static const Color boss = Color(0xFFff00ff);
  static const Color accent = Color(0xFF00ffcc);
  static const Color text = Colors.white;
}
