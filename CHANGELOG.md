# Changelog

All notable changes to this package are listed here. Versions follow [semantic versioning](https://semver.org); while the major version is 0, a minor version (0.x.0) can change behaviour.

## 0.2.0

### Upgrading from 0.1.0

These changes can affect code written for 0.1.0:

- **Swift 6.1 or later is required** (on Apple platforms, Xcode 16.3 or later). 0.1.0 supported Swift 5.9. The package uses `swift-tools-version: 6.1` and the Swift 6 language mode; your own code can use either language mode. In the Swift 6 language mode, operator closures can't be global or static constants, because a closure isn't `Sendable`: declare them inside a function, as instance properties, or at the top level of `main.swift`.
- **Operators and termination checks receive each individual with its fitness.** The solver now calls `fitness()` once for each new individual and passes the result along with it as an `EvaluatedElement`, which has the individual as `element` and its `fitness`. Before, every operator and check that needed fitness called `fitness()` again, often several times per individual and generation.
  - A `SelectionOperator` takes `[EvaluatedElement<Element>]` and returns two of its members. Read `$0.fitness` instead of calling `$0.fitness()`.
  - A `ReplacementOperator` takes and returns `[EvaluatedElement<Element>]`. To add an individual of your own, wrap it in `EvaluatedElement(_:)`, which evaluates it once.
  - A `TerminationCheck` takes `[EvaluatedElement<Element>]`.
  - `currentPopulation`, the result of `solve(maxGenerations:)` and `bestElement` are evaluated too: use `.element` for the individual and `.fitness` for its fitness.
  - In a `GeneticOperators` type, `selectionOperator(population:)`, `replacementOperator(old:new:)` and `fixedGenerationTermination(maxGenerations:)` use the same types. **Implementations with the 0.1.0 types still compile, but they no longer match the requirements, so the solver silently uses the default implementations instead.** Update their parameter and return types.
  - The crossover and mutation operators and `newElement` don't change.
  - Because the result is kept, `fitness()` should depend only on the individual.
- **`solve(maxGenerations:)` continues instead of starting over.** It used to create a new population on every call, discarding the one from `init` and any progress made with `step()`. It now continues from the current state, and `maxGenerations` limits the total generation count rather than the generations run by that call. Call `reset()` first to start a new run.
- **The termination check runs once per population.** It used to run up to three times per generation. It now runs exactly once for the population created by `init` or `reset()` and once after each generation, so `init` calls it for the starting population. Checks that keep their own state (for example, counting generations without improvement) now see each generation once.
- **`step()` no longer calls the termination check before running a generation.** It uses `isTerminated`, the result of the latest call. So a check that depends on something outside the solver, such as a cancel flag or a deadline, sees a change only after the next generation, and once it has stopped the run, changing that state doesn't let the run continue. Call `checkTermination()` after changing the state to apply it right away.
- **Invalid input stops the program with a message.** A `populationSize` below 1, a `crossoverRate` or `mutationRate` outside 0…1 (including NaN), an `eliteCount` that is negative or not less than `populationSize`, a replacement operator that returns no individuals, and selection from an empty population used to crash with unrelated errors or be accepted silently. The parameters are checked in `init` and whenever one is set, so an out-of-range value stops the program at the line that sets it.
- **`GeneticOperators.Element` must conform to `GeneticElement`.** Types that didn't couldn't be used with the solver anyway.
- **Code that uses `GeneticElement` as a type must write `any GeneticElement`.** `GeneticElement` now includes `FitnessEvaluatable`, and with it the `Fitness` associated type, so `[GeneticElement]` becomes `[any GeneticElement]` and `value is GeneticElement` becomes `value is any GeneticElement`. Without `any`, Swift 6.1 and later warn that this will be an error in a future language mode. Types that conform to `GeneticElement`, and generic code such as `<T: GeneticElement>`, don't change.
- **No minimum OS versions.** The package required macOS 13, iOS 17, tvOS 17 and visionOS 1; it now supports every deployment target the Swift toolchain supports, including watchOS, and packages that use it no longer have to declare `platforms`.

### Added

- `EvaluatedElement` pairs an individual with its fitness, evaluated once.
- `GeneticSolver(populationSize:crossoverRate:mutationRate:eliteCount:operators:terminationCheck:)` creates a solver from a `GeneticOperators` type.
- `reset()` starts a new run with a new population.
- `isTerminated` keeps the latest result of the termination check, and `checkTermination()` calls the check again for the current population.
- `bestElement` returns the fittest individual of the current population.
- `eliteCount`, an initializer parameter and property, carries the fittest individuals into the next generation unchanged, so the best solution found is never lost; only `populationSize - eliteCount` offspring are created.
- `GeneticSolver.tournamentSelection(tournamentSize:using:)` offers tournament selection with any size and random number generator.
- `SeededRandomNumberGenerator` and the solver's `randomNumberGenerator` make runs reproducible. The generator is `Sendable`, so Swift 6 code can keep it in a static property or pass it to another task.

### Changed

- `GeneticElement` includes `FitnessEvaluatable`, so conforming to `GeneticElement` is enough. Types that list both still compile; code that uses `GeneticElement` as a type needs `any` (see above).
- Each individual's fitness is evaluated once, when it is created, instead of by every operator that needs it; a parent copied unchanged into the next generation keeps its fitness.
- `solve(maxGenerations:)` is `@discardableResult`.
- The solver is faster, with the same results for the same seeds. The code that runs for every generation and individual is `@inlinable`, so your compiler specializes it for your element type, and the crossover and mutation decisions and the draws of `tournamentSelection(tournamentSize:using:)` no longer run the standard library's random functions unspecialized for `any RandomNumberGenerator`. Tournaments copy only their winners, not every individual they draw, and each generation builds fewer temporary arrays. In `scripts/benchmark.sh`, its three scenarios run 9 to 25 times faster than before these changes.

### Fixed

- `step()` no longer loops forever when the crossover operator returns no children; the parents are copied instead.
- A NaN fitness ranks below every other fitness. Before, a NaN drawn first won its tournament, because no value is greater than NaN.
- README: the quick start ran no generations, the install snippet named a version that didn't exist, the protocol-based example selected the same parent twice, and the roulette wheel, elitism and Traveling Salesman examples crashed or didn't compile. Each complete example is now covered by a test.

## 0.1.0

`GeneticSolver` with closure operators, `step()` and `solve(maxGenerations:)`, and the `GeneticOperators` protocol with default implementations.
