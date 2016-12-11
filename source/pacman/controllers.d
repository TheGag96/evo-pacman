module pacman.controllers;

import pacman.maze, pacman.game, pacman.tree;
import std.random, std.math, std.stdio;

class PacmanController {
  Tree tree;

  float fitness      = float.nan;
  float totalFitness = 0;
  float gamesRan     = 0;
  float normFitness  = 0;

  static float parsimonyCoeff;

  this(int strategy) {
    this.tree = new Tree(strategy);
  }

  this(Tree tree) {
    this.tree = tree;
  }

  void act(Game game) {
    static immutable dirs = [Point(0, 0), Point(-1, 0), Point(0, -1), Point(1, 0), Point(0, 1)];
    Point chosenDir;
    float maxEv = float.nan;

    Point oldP = Point(game.pacman.x, game.pacman.y);

    foreach (d; dirs) {
      Point newP = Point(oldP.x+d.x, oldP.y+d.y);

      if (game.maze.getTile(newP.x, newP.y) == Tile.wall) continue;
      game.pacman = newP;

      game.curThing  = game.pacman;
      game.d2pCached = float.nan;

      float ev = this.tree.evaluate(game);
      if (isNaN(maxEv) || ev > maxEv) {
        chosenDir = d;
        maxEv = ev;
      }
    }

    game.pacman = Point(oldP.x+chosenDir.x, oldP.y+chosenDir.y);
  }

  PacmanController breed(PacmanController other) {
    return new PacmanController(this.tree.breed(other.tree));
  }
}

class GhostController {
  Tree[] trees;

  float fitness      = float.nan;
  float totalFitness = 0;
  float gamesRan     = 0;
  float normFitness  = 0; 
  
  static float parsimonyCoeff;
  static bool  treeForEachGhost;

  this(int strategy) {
    if (treeForEachGhost) {
      trees = new Tree[3];
    }
    else {
      trees = new Tree[1];
    }

    foreach (ref tree; trees) {
      tree = new Tree(strategy);
    }
  }

  this(Tree[] trees) {
    this.trees = trees;
  }

  void act(Game game) {
    static immutable dirs = [Point(-1, 0), Point(0, -1), Point(1, 0), Point(0, 1)];
    
    foreach (i, ref ghost; game.ghosts) {
      Point chosenDir;
      float maxEv = float.nan;

      Point oldP = Point(ghost.x, ghost.y);

      foreach (d; dirs) {
        Point newP = Point(oldP.x+d.x, oldP.y+d.y);

        if (game.maze.getTile(newP.x, newP.y) == Tile.wall) continue;
        ghost = newP;

        game.curThing  = ghost;
        game.d2pCached = float.nan;

        float ev = this.trees[i].evaluate(game);
        if (isNaN(maxEv) || ev > maxEv) {
          chosenDir = d;
          maxEv = ev;
        }
      }

      ghost = Point(oldP.x+chosenDir.x, oldP.y+chosenDir.y);
    }
  }

  GhostController breed(GhostController other) {
    if (treeForEachGhost) {
      Tree[] result = new Tree[3];
      auto bShuff   = other.trees.dup;
      randomShuffle(bShuff);

      foreach (i; 0..3) {
        result[i] = this.trees[i].breed(bShuff[i]);
      }

      return new GhostController(result);
    }
    else {
      return new GhostController([this.trees[0].breed(other.trees[0])]);
    }
  }
}