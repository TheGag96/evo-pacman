import std.stdio, std.file, std.algorithm, std.random, std.typecons, std.range.primitives, std.conv;
import pacman.game, pacman.controllers, pacman.maze, pacman.tree;
import inid;

////
// Config stuff
////

struct Config {
  struct EA {
    string outputPath, logPath, solutionPath;
    int numRuns, numEvals;
    uint randomSeed;
    int maxTreeDepth;
  }

  struct Maze {
    int rows, cols;
    float wallDensity, pillDensity;
  }

  struct Game {
    float fruitChance, timeMultiplier;
    int fruitScore;
  }

  struct Pacman {
    int populationSize, childrenPerGen;
    float parsimonyCoeff;
    string parentSelection, survivalSelection;
    int tournamentSize;
  }

  struct Ghosts {
    int populationSize, childrenPerGen;
    float parsimonyCoeff;
    string parentSelection, survivalSelection;
    int tournamentSize;
    bool treeForEachGhost;
  }

  Config.EA     ea;
  Config.Maze   maze;
  Config.Game   game;
  Config.Pacman pacman;
  Config.Ghosts ghosts;
}

Config config;
File logFile;

void main(string[] args) {
  ////
  // load config
  ////
  
  if (!loadConfig(args)) return;
  
  ////
  // run evolution and get best games
  ////

  //[best pacman, best ghost]
  Game[2] bestGames = evolve();

  ////
  // write out results and close up shop
  ////

  writeOutSolutions(bestGames);
}

bool loadConfig(string[] args) {
  if (args.length < 2) {
    writeln("Please pass in the config file as the first argument.");
    return false;
  }

  config = ConfigParser!Config(readText(args[1]));

  if (config.ea.randomSeed == 0) {
    config.ea.randomSeed = unpredictableSeed();
    rndGen.seed(config.ea.randomSeed);
  }
  else rndGen.seed(config.ea.randomSeed);

  PacmanController.parsimonyCoeff = config.pacman.parsimonyCoeff;

  GhostController.parsimonyCoeff   = config.ghosts.parsimonyCoeff;
  GhostController.treeForEachGhost = config.ghosts.treeForEachGhost;

  Game.timeMultiplier = config.game.timeMultiplier;
  Game.fruitChance    = config.game.fruitChance;
  Game.fruitScore     = config.game.fruitScore;

  Tree.maxDepth = config.ea.maxTreeDepth;

  logFile = File(config.ea.logPath, "w");
  logBasicData(args[1]);

  return true;
}

Game[2] evolve() {
  Game[2] overallBestGames;

  foreach (run; 0..config.ea.numRuns) {
    PacmanController[] popPacman;
    GhostController[]  popGhosts;
    int                evalsRan = 0;
    Game[2]            runBestGames;

    writeln("Run ", run);

    ////
    // initialize and evaluate population
    ////

    foreach (i; 0..config.pacman.populationSize) {
      if (i < config.pacman.populationSize/2) {
        popPacman ~= new PacmanController(0);
      }
      else {
        popPacman ~= new PacmanController(1);
      }
    }

    foreach (i; 0..config.ghosts.populationSize) {
      if (i < config.ghosts.populationSize/2) {
        popGhosts ~= new GhostController(0);
      }
      else {
        popGhosts ~= new GhostController(1);
      }
    }

    runEvaluations(run, evalsRan, popPacman, popGhosts);

    logFitnessData(evalsRan, popPacman);

    ////
    // continue making new generations until max evals reached
    ////

    while (evalsRan < config.ea.numEvals) {
      ////
      // make new children
      ////

      writeln("Making new children...");

      doParentSelection(popPacman);
      doParentSelection(popGhosts);

      ////
      // match up populations against each other and run games to get fitness
      ////

      writeln("Running matchups...");

      runEvaluations(run, evalsRan, popPacman, popGhosts);

      ////
      // kill some off
      ////

      writeln("Running survival selection");

      doSurvivalSelection(popPacman);
      doSurvivalSelection(popGhosts);

      ////
      // log generation data
      ////

      logFitnessData(evalsRan, popPacman);
    }

    ////
    // run extra evals to finish run and get best games
    ////

    writeln("Finding best individuals from the final generation...");

    foreach (individual; popPacman) {
      individual.totalFitness = 0;
      individual.gamesRan     = 0;
    }

    foreach (individual; popGhosts) {
      individual.totalFitness = 0;
      individual.gamesRan     = 0;
    }

    foreach (matchup; getMatchups(popPacman, popGhosts)) {
      writeln("Run ", run, " Eval ", evalsRan+1, " (Extra)");
      auto game = new Game(Yes.keepLog);

      game.maze = new Maze(config.maze.rows, config.maze.cols, config.maze.pillDensity, config.maze.wallDensity);
      game.pc   = matchup.pc;
      game.gc   = matchup.gc;

      game.run();

      evalsRan++;

      //bool keepThisGame = false;

      if (runBestGames[0] is null || game.pc.fitness > runBestGames[0].savedPCFitness) {
        //if (runBestGames[0] !is null && runBestGames[0] !is runBestGames[1]) {
        //  runBestGames[0].gameString.clear;
        //}

        game.savedPCFitness = game.pc.fitness;
        runBestGames[0] = game;
        //keepThisGame = true;
      }

      if (runBestGames[1] is null || game.gc.fitness > runBestGames[1].savedGCFitness) {
        //if (runBestGames[1] !is null && runBestGames[1] !is runBestGames[0]) {
        //  runBestGames[1].gameString.clear;
        //}

        game.savedGCFitness = game.gc.fitness;
        runBestGames[1] = game;
        //keepThisGame = true;
      }

      //if (!keepThisGame) game.gameString.clear;
    }

    ////
    // finish up run
    ////

    if (overallBestGames[0] is null || runBestGames[0].savedPCFitness > overallBestGames[0].savedPCFitness) {
      overallBestGames[0] = runBestGames[0];
    }

    if (overallBestGames[1] is null || runBestGames[1].savedGCFitness > overallBestGames[1].savedGCFitness) {
      overallBestGames[1] = runBestGames[1];
    }
  }

  return overallBestGames;
}


void normalizeFitness(T)(T[] population) {
  float lowest = population.map!"a.normFitness".fold!min(float.max);
  population.each!(x => x.normFitness = x.fitness - lowest);
}

/**
 * O(n) Fitness Proportional Selection brought to you by Wikipedia
 */
T fps(T)(T[] population) {
  float weightSum = population.map!"a.normFitness".sum;

  float value = uniform!"[]"(0.0, 1.0) * weightSum;

  foreach (individual; population) {
    value -= individual.normFitness;
    if (value < 0) return individual;
  }

  return population[0];
}

alias Matchup = Tuple!(PacmanController, "pc", GhostController, "gc");

Matchup[] getMatchups(PacmanController[] popPacman, GhostController[] popGhosts) {
  randomShuffle(popPacman);
  randomShuffle(popGhosts);

  Matchup[] result = new Matchup[](max(config.pacman.populationSize, config.ghosts.populationSize));

  foreach (i; 0..result.length) {
    //create at least one matchup for each member of the population, wrapping around the smaller array
    result[i] = Matchup(popPacman[i % popPacman.length], popGhosts[i % popGhosts.length]);
  }

  return result;
}

void runEvaluations(int run, ref int evalsRan, PacmanController[] popPacman, GhostController[] popGhosts) {
  foreach (individual; popPacman) {
    individual.totalFitness = 0;
    individual.gamesRan     = 0;
  }

  foreach (individual; popGhosts) {
    individual.totalFitness = 0;
    individual.gamesRan     = 0;
  }

  foreach (matchup; getMatchups(popPacman, popGhosts)) {
    writeln("Run ", run, " Eval ", evalsRan+1);
    auto game = new Game(No.keepLog);

    game.maze = new Maze(config.maze.rows, config.maze.cols, config.maze.pillDensity, config.maze.wallDensity);
    game.pc   = matchup.pc;
    game.gc   = matchup.gc;

    game.run();

    evalsRan++;
  }

  foreach (individual; popPacman) {
    individual.fitness = individual.totalFitness / individual.gamesRan;
  }

  foreach (individual; popGhosts) {
    individual.fitness = individual.totalFitness / individual.gamesRan;
  }
}

void doParentSelection(T)(ref T[] population) {
  static if (is(T==PacmanController)) {
    auto popConfig = &config.pacman;
  }
  else {
    auto popConfig = &config.ghosts;
  }

  normalizeFitness(population);

  ////
  // select parents
  ////

  if (popConfig.parentSelection == "fitness-proportional") {
    T[] parents;

    while (parents.length < popConfig.childrenPerGen*2) {
      parents ~= fps(population);
    }

    foreach (i; 0..popConfig.childrenPerGen) {
      population ~= parents[2*i].breed(parents[2*i+1]);
    }
  }
  else { // == "over-selection"
    population.sort!"a.normFitness > b.normFitness";
    auto cutoff = cast(size_t) (population.length * 0.8);

    auto topPop = population[0..cutoff], bottomPop = population[cutoff..$];
    T[] topParents, bottomParents;

    int numTop    = cast(int) (popConfig.childrenPerGen*0.8*2),
        numBottom = popConfig.childrenPerGen*2 - numTop; 


    while (topParents.length    < numTop)    topParents    ~= fps(topPop);
    while (bottomParents.length < numBottom) bottomParents ~= fps(bottomPop);

    foreach (i; 0..numTop/2) {
      population ~= topParents[2*i].breed(topParents[2*i+1]);
    }

    foreach (i; 0..numBottom/2) {
      population ~= bottomParents[2*i].breed(bottomParents[2*i+1]);
    }
  }
}

void doSurvivalSelection(T)(ref T[] population) {
  static if (is(T==PacmanController)) {
    auto popConfig = &config.pacman;
  }
  else {
    auto popConfig = &config.ghosts;
  }

  normalizeFitness(population);

  if (popConfig.survivalSelection == "truncation") {
    population.sort!"a.normFitness > b.normFitness";
    population = population[0..popConfig.populationSize];
  }
  else { // == k-tournament
    T[] newPop;
    T[] tourney = new T[](popConfig.tournamentSize);

    while (newPop.length < popConfig.populationSize) {
      auto tourneyRef = tourney[];
      tourneyRef.put(population.randomSample(popConfig.tournamentSize));
      tourney.sort!"a.normFitness > b.normFitness";
      auto winner = tourney[0];

      newPop ~= winner;
      
      foreach (i, individual; population) {
        if (individual is winner) {
          population = population.remove(i);
          break;
        }
      }
    }

    population = newPop;
  }
}

void logBasicData(string configPath) {
  logFile.writefln("Result Log");
  logFile.writefln("Config file: %s", configPath);
  logFile.writefln("Random seed: %d", config.ea.randomSeed);
  logFile.writefln("Max tree depth: %d", config.ea.maxTreeDepth);
  
  logFile.writefln("\nPacman:");
  logFile.writefln("  Mu: %d",                    config.pacman.populationSize);
  logFile.writefln("  Lambda: %d",                config.pacman.childrenPerGen);
  logFile.writefln("  Parsimony coefficient: %f", config.pacman.parsimonyCoeff);
  logFile.writefln("  Parent selection: %s",      config.pacman.parentSelection);
  logFile.writefln("  Survival selection: %s",    config.pacman.survivalSelection);
  
  if (config.pacman.survivalSelection == "k-tournament") {
    logFile.writefln("    Tournament size: %d", config.pacman.tournamentSize);
  }

  logFile.writefln("\nGhosts:");
  logFile.writefln("  Mu: %d",                    config.ghosts.populationSize);
  logFile.writefln("  Lambda: %d",                config.ghosts.childrenPerGen);
  logFile.writefln("  Parsimony coefficient: %f", config.ghosts.parsimonyCoeff);
  logFile.writefln("  Parent selection: %s",      config.ghosts.parentSelection);
  logFile.writefln("  Survival selection: %s",    config.ghosts.survivalSelection);
     
  if (config.ghosts.survivalSelection == "k-tournament") {
    logFile.writefln("    Tournament size: %d", config.ghosts.tournamentSize);
  }

  logFile.writefln("Each ghost has their own expression tree: %s\n", config.ghosts.treeForEachGhost.to!string);

  logFile.writefln("Grid size: %d x %d", config.maze.rows, config.maze.rows);
  logFile.writefln("Wall density: %f", config.maze.wallDensity);
  logFile.writefln("Pill density: %f", config.maze.pillDensity);
}

void logFitnessData(int evalsRan, PacmanController[] popPacman) {
  auto avgFit  = popPacman.map!"a.fitness".sum / popPacman.length,
       bestFit = popPacman.map!"a.fitness".fold!max(-float.max);

       logFile.writefln("%d\t%f\t%f", evalsRan, avgFit, bestFit); 
}

void writeOutSolutions(Game[2] bestGames) {
  File solution = File(config.ea.solutionPath, "w");
  solution.write("Pacman:\n");
  solution.write(bestGames[0].pc.tree);
  solution.write("\n\nGhosts:");
  bestGames[1].gc.trees.each!(x => solution.writeln(x));

  std.file.write(config.ea.outputPath ~ "_pacman", bestGames[0].gameString.data);
  std.file.write(config.ea.outputPath ~ "_ghosts", bestGames[1].gameString.data);
}