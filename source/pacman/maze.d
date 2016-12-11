module pacman.maze;

import std.random, std.algorithm, std.typecons, std.array;

enum Tile {
  wall   = '#',
  empty  = ' ',
  pill   = '.',
  ghost1 = '1',
  ghost2 = '2',
  ghost3 = '3',
  pacman = 'm',
  fruit  = 'f'
}

alias Point = Tuple!(int, "x", int, "y");

class Maze {
  Tile[][] grid;
  int rows, cols, numPills, totalPills;
  
  alias grid this;

  this(int rows, int cols, float pillDensity, float wallDensity) {
    static struct Runner {
      int x, y;

      static int tilesLeft;
      static Tile[][] grid;

      void goTowardsX(int wantedX) {
        int change = (this.x < wantedX) ? 1 : -1;

        while (this.x != wantedX && Runner.tilesLeft > 0) {
          if (grid[this.y][this.x] == Tile.wall) {
            Runner.tilesLeft--;
            grid[this.y][this.x] = Tile.empty;
          }
          this.x += change;
        }
      }

      void goTowardsY(int wantedY) {
        int change = (this.y < wantedY) ? 1 : -1;

        while (this.y != wantedY && Runner.tilesLeft > 0) {
          if (grid[this.y][this.x] == Tile.wall) {
            Runner.tilesLeft--;
            grid[this.y][this.x] = Tile.empty;
          }
          this.y += change;
        }
      }

      void walkTo(int newX, int newY) {
        if (uniform!"[]"(0, 1) == 1) {
          goTowardsX(newX);
          goTowardsY(newY);
        }
        else {
          goTowardsY(newY);
          goTowardsX(newX);
        }
      }
    }

    ////
    // set up grid and number of tiles that can be empty
    ////

    this.rows = rows;
    this.cols = cols;
    this.grid = new Tile[][](rows, cols);

    Runner.tilesLeft = cast(int) (rows*cols*(1-wallDensity));
    Runner.grid      = this.grid;

    ////
    // draw initial random path from the top left corner to bottom right corner
    // add runners that will make their own random paths every 10 steps
    ////

    Runner[] runners;

    int initX = 0, initY = 0, counter = 0;

    while (initX != cols-1 || initY != rows-1) {
      this.grid[initY][initX] = Tile.empty;
      Runner.tilesLeft--;
      counter++;

      if      (initY == rows-1)         initX++;
      else if (initX == cols-1)         initY++;
      else if (uniform!"[]"(0, 1) == 1) initX++;
      else                              initY++;

      if (counter % ((rows+cols)/4) == 0) {
        runners ~= Runner(initX/2*2, initY/2*2);
      }
    }

    this.grid[initY][initX] = Tile.empty;
    Runner.tilesLeft--;

    ////
    // Let runners go until we have no more spaces left
    ////

    while (Runner.tilesLeft > 0) {
      foreach (runner; runners) {
        runner.walkTo(uniform(0, cols-1)/2*2,
                      uniform(0, rows-1)/2*2);
      }
    }

    ////
    // place pills
    ////

    auto emptySpaces = getEmptySpaces();
    int pillsToPlace = min(cast(int) (rows*cols*pillDensity), cast(int) emptySpaces.length);
    
    totalPills = pillsToPlace;
    numPills   = pillsToPlace;

    while (pillsToPlace > 0) {
      auto chosen = uniform(0, emptySpaces.length);
      Point space = emptySpaces[chosen];
      this.grid[space.y][space.x] = Tile.pill;
      emptySpaces = emptySpaces.remove(chosen);
      pillsToPlace--;
    }
  }

  bool isValidTile(int x, int y) {
    return x >= 0 && x < this.cols && y >= 0 && y < this.rows;
  }

  Tile getTile(int x, int y) {
    if (isValidTile(x, y)) return this.grid[y][x];
    else                   return Tile.wall;
  }

  Point[] getEmptySpaces() {
    Point[] result;

    foreach (row; 0..this.rows) {
      foreach (col; 0..this.cols) {
        if (this.grid[row][col] == Tile.empty) {
          result ~= Point(col, row);
        }
      }
    }

    return result;
  }

  override string toString() {
    auto app = appender!string;

    app.put('┌');

    foreach (col; 0..this.cols) {
      app.put('─');
    }

    app.put("┐\n");

    foreach (row; this.grid) {
      app.put('│');

      foreach (c; row) {
        app.put(c);
      }

      app.put("│\n");
    }

    app.put('└');

    foreach (col; 0..this.cols) {
      app.put('─');
    }

    app.put('┘');

    return app.data;
  }

}