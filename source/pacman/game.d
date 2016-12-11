module pacman.game;

import std.array, std.typecons, std.algorithm, std.string, std.random, std.math, std.stdio;
import pacman.controllers, pacman.maze;

class Game {
  Point   pacman;
  Point[] ghosts;
  Point   curThing;
  Point   fruit = Point(-1, -1);

  Maze maze;

  PacmanController pc;
  GhostController  gc;

  float savedPCFitness, savedGCFitness;

  Appender!string gameString;

  int time;
  int score;

  Point[] emptySpaces;
  float   d2pCached = float.nan;

  static float timeMultiplier;
  static float fruitChance;
  static int   fruitScore;

  Flag!"keepLog" keepLog;

  this(Flag!"keepLog" keepLog = No.keepLog) {
    this.keepLog = keepLog;
    if (this.keepLog) gameString = appender!string;
  }

  void run() {
    pacman   = Point(0, 0);
    ghosts   = new Point[3];
    ghosts[] = Point(maze.cols-1, maze.rows-1);
    time     = cast(int) (maze.rows*maze.cols*timeMultiplier);

    this.emptySpaces = maze.getEmptySpaces();

    writeInitialData();

    while (time > 0) {
      ////
      // move everyone
      ////

      Point pacmanPrev  = pacman;
      Point[] ghostPrev = ghosts.dup;

      pc.act(this);
      gc.act(this);
      time--;

      ////
      // Check game over conditions
      ////

      bool gameOver = false;

      foreach (i, ghost; ghosts) {
        if (ghost == pacman || pacmanPrev == ghost || ghostPrev[i] == pacman) {
          gameOver = true;
          break;
        }
      }

      if (gameOver) break;

      ////
      // eat pill
      ////

      if (maze.getTile(pacman.x, pacman.y) == Tile.pill) {
        maze[pacman.y][pacman.x] = Tile.empty;
        maze.numPills--;

        if (maze.numPills == 0) {
          int totalTime = cast(int) (maze.rows*maze.cols*timeMultiplier);
          score += cast(int) (100.0*time/totalTime);
        }

        emptySpaces ~= pacman;
      }

      if (time == 0) {
        break;
      }

      ////
      // handle fruit
      ////

      if (fruit.x == -1) {
        if (uniform!"[]"(0.0, 1.0) < fruitChance) {
          ////
          // spawn fruit
          ////

          bool placed = false;

          while (!placed && emptySpaces.length > 0) {
            auto choice = uniform(0, emptySpaces.length);
            auto spot   = emptySpaces[choice];

            if (spot != pacman) {
              fruit = spot;
              placed = true;
            }

            emptySpaces = emptySpaces.remove(choice);  
          }

          if (keepLog) gameString.put(format("f %d %d\n", fruit.x, fruit.y));
        }
      }
      else {
        if (fruit == pacman) {
          foreach (i, space; emptySpaces) {
            if (fruit == space) {
              emptySpaces = emptySpaces.remove(i);
              break;
            }
          }

          fruit = Point(-1, -1);
          score += fruitScore;
        }
      }

      ////
      // write out current game state
      ////

      writeGameState();
    }

    ////
    // close up game
    ////

    score           += cast(int) (100.0 * (maze.totalPills-maze.numPills) / maze.totalPills);
    pc.fitness       = score - pc.tree.length*PacmanController.parsimonyCoeff;
    pc.totalFitness += pc.fitness;
    pc.gamesRan++;

    //primary ghost fitness is the time left when they killed pacman
    gc.fitness = time;

    if (gc.fitness == 0) {
      gc.fitness = maze.rows+maze.cols;

      foreach (ghost; ghosts) {
        gc.fitness = min(gc.fitness, abs(ghost.x-pacman.x) + abs(ghost.y-pacman.y));
      }
    }

    float penalty = 0;

    foreach (tree; gc.trees) {
      penalty += tree.length*GhostController.parsimonyCoeff;
    }

    gc.fitness      -= penalty / gc.trees.length;
    gc.totalFitness += gc.fitness;
    gc.gamesRan++;

    writeGameState();
  }

  void writeInitialData() {
    if (!keepLog) return;

    gameString.put(format("%d\n%d\n", maze.cols, maze.rows));
    gameString.put(format("m 0 %d\n", maze.rows-1));
    gameString.put(format("1 %d 0\n", maze.cols-1));
    gameString.put(format("2 %d 0\n", maze.cols-1));
    gameString.put(format("3 %d 0\n", maze.cols-1));

    foreach (r; 0..maze.rows) {
      foreach (c; 0..maze.cols) {
        if      (maze[r][c] == Tile.wall) gameString.put(format("w %d %d\n", c, maze.rows-1-r));
        else if (maze[r][c] == Tile.pill) gameString.put(format("p %d %d\n", c, maze.rows-1-r));
      }
    }

    gameString.put(format("t %d 0\n", cast(int) (maze.rows*maze.cols*timeMultiplier)));
  }

  void writeGameState() {
    if (!keepLog) return;

    gameString.put(format("m %d %d\n", pacman.x, maze.rows-1-pacman.y));

    foreach (i, ghost; ghosts) {
      gameString.put(format("%d %d %d\n", i+1, ghost.x, maze.rows-1-ghost.y));
    }

    gameString.put(format("t %d %d\n", time, score));
  }
}