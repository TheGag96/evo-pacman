module pacman.tree;

import std.random, std.algorithm, std.math, std.container, std.typecons, std.string, std.conv, std.stdio;
import pacman.game, pacman.maze;

class Tree {
  union Data {
    float value;
    float function(Game) terminal;
    float function(float, float) operator;
  }

  enum DataType {
    value, operator, terminal
  }

  Tree     left = null, right = null;
  Data     data;
  DataType type;

  static int maxDepth;
  //static float[float function(Game)] cache;

  static operators     = [&plus,  &minus,  &multiply,  &divide,  &rand];
  static terminals     = [&d2p,  &d2m,  &d2g,  &d2f,  &tws];

  static string[float function(float, float)] operatorNames;
  static string[float function(Game)]         terminalNames;

  shared static this() {
    operatorNames = [&plus : "plus", &minus : "minus", &multiply : "multiply", &divide : "divide", &rand : "rand"];
    terminalNames = [&d2p : "d2p", &d2m : "d2m", &d2g : "d2g", &d2f : "d2f", &tws : "tws"];
  }

  this(int strategy, int depth = 0) {
    if (strategy == 0) {
      if (depth >= maxDepth || uniform!"[]"(0, 1) == 1) {
        if (uniform!"[]"(0, 1) == 1) {
          this.data.terminal = terminals[uniform(0, terminals.length)];
          this.type          = DataType.terminal;
        }
        else {
          this.data.value = uniform!"[]"(1.0, 9.0);
          this.type       = DataType.value;
        }
      }
      else {
        this.data.operator  = operators[uniform(0, operators.length)];
        this.type           = DataType.operator; 
        this.left           = new Tree(strategy, depth+1);
        this.right          = new Tree(strategy, depth+1);
      }
    }
    else { // == 1: full
      if (depth >= maxDepth) {
        if (uniform!"[]"(0, 1) == 1) {
          this.data.terminal = terminals[uniform(0, terminals.length)];
          this.type          = DataType.terminal;
        }
        else {
          this.data.value = uniform!"[]"(1.0, 9.0);
          this.type       = DataType.value;
        }
      }
      else {
        this.data.operator = operators[uniform(0, operators.length)];
        this.type          = DataType.operator; 
        this.left          = new Tree(strategy, depth+1);
        this.right         = new Tree(strategy, depth+1);
      }
    }

    writeln("creation");
    this.verify();
    writeln("creation done");
  }

  this(Tree left, Tree right, Data data, DataType type) {
    this.left  = left;
    this.right = right;
    this.data  = data;
    this.type  = type;
  }

  float evaluate(Game game, bool topLevel = true) {
    if (topLevel) {
      d2pCached = float.nan;
    }

    if (this.type == DataType.operator) {
      return this.data.operator(this.left.evaluate(game, false), this.right.evaluate(game, false));
    }
    else if (this.type == DataType.value) {
      return this.data.value;
    }
    else { // == DataType.terminal
      return this.data.terminal(game);
    }
  }

  /*
    For testing purposes. Since each tree node should either be a terminal or a binary function,
    The right node should ALWAYS be null if the left one is and vice versa.
  */
  void verify() {
    assert((this.left is null) == (this.right is null));

    if (this.left !is null) {
      this.left.verify();
      this.right.verify();
    }
  }

  Tree breed(Tree other) {
    Tree child = this.dup;
    Node[] childNodeList = [];

    this.getNodeList(0, childNodeList);

    if (uniform!"[]"(0, 1) == 1) {
      ////
      // crossover
      ////

      Node[] otherNodeList = [];
      other.getNodeList(0, otherNodeList);

      auto childCrossPoint = childNodeList[uniform(0, childNodeList.length)].tree;
      auto otherCrossPoint = otherNodeList[uniform(0, otherNodeList.length)].tree;


      if (otherCrossPoint.left is null) {
        childCrossPoint.left  = null;
        childCrossPoint.right = null;
      }
      else {
        writeln("how");

        //things are fine before here
        otherCrossPoint.verify(); 

        writeln("is ");

        //left side is duplicated by calling .dup(), a const function.
        childCrossPoint.left  = otherCrossPoint.left.dup;
        
        writeln("this ");

        //assertion fails here. somehow, .dup() modifies the calling object despite being const!
        otherCrossPoint.verify();
        writeln("happening");

        //if i leave out verification, this will fail because dup expects left and right to have the same "nullness"
        childCrossPoint.right = otherCrossPoint.right.dup;
      }

      childCrossPoint.data = otherCrossPoint.data;
      childCrossPoint.type = otherCrossPoint.type;
    }
    else {
      ////
      // mutate
      ////

      auto mutatePoint = childNodeList[uniform(0, childNodeList.length)];
      auto newTree = new Tree(0, mutatePoint.depth);

      mutatePoint.tree.left  = newTree.left;
      mutatePoint.tree.right = newTree.right;
      mutatePoint.tree.data  = newTree.data;
      mutatePoint.tree.type  = newTree.type;
    }

    return child;
  }

  Tree dup() const {
    Tree result = new Tree(null, null, this.data, this.type);

    if (this.left !is null) {
      result.left  = this.left.dup;
      result.right = this.right.dup;
    }

    return result;
  }

  alias Node = Tuple!(Tree, "tree", int, "depth");

  protected void getNodeList(int depth, ref Node[] curList) {
    curList ~= Node(this, depth);

    if (this.left !is null) {
      this.left.getNodeList(depth+1, curList);
      this.right.getNodeList(depth+1, curList);
    }
  }

  override string toString() {
    if (this.type == DataType.value) {
      return this.data.value.to!string;
    }
    else if (this.type == DataType.terminal) {
      return format("(%s)", terminalNames[this.data.terminal]);
    }
    else { // == DataType.operator   
      return format("(%s %s %s)", operatorNames[this.data.operator], this.left.toString(), this.right.toString());
    }
  }

  @property int length() {
    if (this.left is null) return 1;
    else                   return 1 + this.left.length + this.right.length;
  }

  private:

  static int distance(int x1, int y1, int x2, int y2) {
    return abs(x1-x2) + abs(y1-y2);
  }

  static int distance(Point a, Point b) {
    return abs(a.x-b.x) + abs(a.y-b.y);
  }

  ////
  // Operators
  ////

  static float plus(float a, float b) {
    return a + b;
  }

  static float minus(float a, float b) {
    return a - b;
  }

  static float multiply(float a, float b) {
    return a * b;
  }

  static float divide(float a, float b) {
    if (b == 0) return 100;
    return a / b;
  }

  static float rand(float a, float b) {
    return uniform!"[]"(min(a,b), max(a,b));
  }

  ////
  // Terminals
  ////

  static immutable dirs = [Point(-1, 0), Point(1, 0), Point(0, -1), Point(0, 1)];
  static float d2pCached = float.nan;

  static float d2p(Game game) {
    if (!isNaN(game.d2pCached)) return game.d2pCached;

    float result            = 100;
    static bool[][] visited = null;
    auto queue              = make!(SList!Point);

    if (visited == null || visited.length != game.maze.rows || visited[0].length != game.maze.cols) {
      visited = new bool[][](game.maze.rows, game.maze.cols);
    }
    else visited.each!((ref row) => row[] = false);

    queue.insertFront(game.curThing);

    while (!queue.empty) {
      auto candidate = queue.front;
      queue.removeFront;

      int distToCand = distance(game.curThing, candidate);

      if (game.maze.getTile(candidate.x, candidate.y) == Tile.pill) {
        game.d2pCached = distToCand;
        return distToCand;
      }

      foreach (d; dirs) {
        auto newTile = Point(candidate.x + d.x, candidate.y + d.y);
        if (game.maze.isValidTile(newTile.x, newTile.y) && !visited[newTile.y][newTile.x]) {
          queue.insertFront(newTile);
          visited[newTile.y][newTile.x] = true;
        }
      }
    }

    //shouldn't reach here
    game.d2pCached = result;
    return result;
  }

  static float d2g(Game game) {
    int minDist = int.max;

    foreach (ghost; game.ghosts) {
      if (ghost != game.curThing) {
        minDist = min(minDist, distance(game.curThing, ghost));
      }
    }

    return minDist;
  }

  static float d2f(Game game) {
    if (game.fruit.x == -1) return 1000;
    return distance(game.curThing, game.fruit);
  }

  static float tws(Game game) {
    float result = 0;

    foreach (d; dirs) {
      if (game.maze.getTile(game.curThing.x + d.x, game.curThing.y + d.y) == Tile.wall) {
        result++;
      }
    }

    return result;
  }

  static float d2m(Game game) {
    return distance(game.curThing, game.pacman);
  }
}
