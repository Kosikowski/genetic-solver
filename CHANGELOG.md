# Changelog

All notable changes to this package are listed here. Versions follow [semantic versioning](https://semver.org); while the major version is 0, a minor version (0.x.0) can change behaviour.

## Unreleased (planned as 0.2.0)

### Upgrading from 0.1.0

These changes can affect code written for 0.1.0:

- **`solve(maxGenerations:)` continues instead of starting over.** It used to create a new population on every call, discarding the one from `init` and any progress made with `step()`. It now continues from the current state, and `maxGenerations` limits the total generation count rather than the generations run by that call. Call `reset()` first to start a new run.
- **The termination check runs once per population.** It used to run up to three times per generation. It now runs exactly once for the population created by `init` or `reset()` and once after each generation, so `init` calls it for the starting population. Checks that keep their own state (for example, counting generations without improvement) now see each generation once.
- **Invalid input stops the program with a message.** A `populationSize` below 1, a `crossoverRate` or `mutationRate` outside 0…1 (including NaN), a replacement operator that returns no individuals, and selection from an empty population used to crash with unrelated errors or be accepted silently. The parameters are checked in `init` and whenever one is set, so an out-of-range value stops the program at the line that sets it.
- **`GeneticOperators.Element` must conform to `GeneticElement`.** Types that didn't couldn't be used with the solver anyway.
- **Code that uses `GeneticElement` as a type must write `any GeneticElement`.** `GeneticElement` now includes `FitnessEvaluatable`, and with it the `Fitness` associated type, so `[GeneticElement]` becomes `[any GeneticElement]` and `value is GeneticElement` becomes `value is any GeneticElement`. Without `any`, Swift 5.9 reports an error and Swift 6 a warning. Types that conform to `GeneticElement`, and generic code such as `<T: GeneticElement>`, don't change.
- **No minimum OS versions.** The package required macOS 13, iOS 17, tvOS 17 and visionOS 1; it now supports every deployment target the Swift toolchain supports, including watchOS, and packages that use it no longer have to declare `platforms`.

### Added

- `GeneticSolver(populationSize:crossoverRate:mutationRate:operators:terminationCheck:)` creates a solver from a `GeneticOperators` type.
- `reset()` starts a new run with a new population.
- `isTerminated` keeps the latest result of the termination check.
- `bestElement` returns the fittest individual of the current population.
- `GeneticSolver.elitistReplacement(eliteCount:)` keeps the fittest individuals from one generation to the next, so the best solution found is never lost.
- `GeneticSolver.tournamentSelection(tournamentSize:using:)` offers tournament selection with any size and random number generator.
- `SeededRandomNumberGenerator` and the solver's `randomNumberGenerator` make runs reproducible. The generator is `Sendable`, so Swift 6 code can keep it in a static property or pass it to another task.

### Changed

- `GeneticElement` includes `FitnessEvaluatable`, so conforming to `GeneticElement` is enough. Types that list both still compile; code that uses `GeneticElement` as a type needs `any` (see above).
- The default tournament selection evaluates each candidate's fitness once instead of in every comparison.
- `solve(maxGenerations:)` is `@discardableResult`.

### Fixed

- `step()` no longer loops forever when the crossover operator returns no children; the parents are copied instead.
- README: the quick start ran no generations, the install snippet named a version that didn't exist, the protocol-based example selected the same parent twice, and the roulette wheel, elitism and Traveling Salesman examples crashed or didn't compile. Each complete example is now covered by a test.

## 0.1.0

`GeneticSolver` with closure operators, `step()` and `solve(maxGenerations:)`, and the `GeneticOperators` protocol with default implementations.
