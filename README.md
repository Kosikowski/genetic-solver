[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FKosikowski%2Fgenetic-solver%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/Kosikowski/genetic-solver)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FKosikowski%2Fgenetic-solver%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/Kosikowski/genetic-solver)

# Genetic Solver

A highly generic and extensible genetic algorithm framework written in Swift. This library provides a flexible foundation for implementing genetic algorithms with customizable selection, crossover, mutation, and replacement operators.


## Genetic Algorithm Overview

Genetic algorithms are optimization techniques inspired by natural selection and genetics. The algorithm follows these fundamental steps:

### **Initialize** → **Evaluate** → **Select** → **Recombine** → **Mutate** → **Replace** → **Test-for-End** — then loop

1. **Initialize**: Create an initial population of random individuals (potential solutions)
2. **Evaluate**: Calculate the fitness of each individual in the population
3. **Select**: Choose parent individuals for reproduction based on their fitness
4. **Recombine**: Perform crossover/recombination to create offspring from selected parents
5. **Mutate**: Introduce random changes to offspring to maintain genetic diversity
6. **Replace**: Form the new population by replacing old individuals with offspring
7. **Test-for-End**: Check if termination criteria are met (e.g., maximum generations, target fitness reached)

This cycle repeats until the termination condition is satisfied, gradually improving the population's fitness over generations.

## Features

- **Generic Design**: Works with any type that conforms to `GeneticElement`
- **Customizable Operators**: Full control over selection, crossover, mutation, and replacement strategies
- **Protocol-Based Design**: Uses `GeneticOperators` protocol for clean separation of concerns
- **Default Implementations**: Built-in operators for common genetic algorithm patterns
- **Type Safety**: Leverages Swift's type system for compile-time safety
- **Extensible**: Easy to extend with custom operators and termination conditions
- **State Tracking**: Monitor current population and generation during execution
- **Incremental Execution**: Step-by-step execution with the `step()` method, continuing runs, and `reset()` to start over

## Requirements

- Swift 5.9 or later
- macOS 13, iOS 17, tvOS 17, visionOS 1 or later, Linux, or Windows

On Apple platforms, a package that depends on this library must declare at least the same minimum versions, for example `platforms: [.macOS(.v13), .iOS(.v17)]`. Without that, the build fails with "requires minimum platform version 13.0 for the macOS platform".

## Installation

### Swift Package Manager

Add the package to your `Package.swift`, then add its `genetic-solver` product to each target that uses it:

```swift
dependencies: [
    .package(url: "https://github.com/Kosikowski/genetic-solver.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "MyTarget",
        dependencies: [.product(name: "genetic-solver", package: "genetic-solver")]
    ),
]
```

Or add it to your Xcode project:
1. File → Add Package Dependencies
2. Enter `https://github.com/Kosikowski/genetic-solver.git`
3. Select the version you want to use

### Importing

The package name contains a hyphen, so the module is called `genetic_solver`:

```swift
import genetic_solver
```

## Quick Start

### 1. Define Your Individual

First, create a type that represents an individual in your genetic algorithm. `GeneticElement` includes `FitnessEvaluatable`, so all it needs is a `fitness()` method that returns a `Comparable` value, where higher is better:

```swift
import genetic_solver

struct MyIndividual: GeneticElement {
    var genes: [Int]

    func fitness() -> Double {
        // Calculate fitness based on your problem
        return Double(genes.reduce(0, +))
    }
}
```

`fitness()` can be called many times for the same individual, for example once per candidate in tournament selection. If it's expensive, compute it once when the individual is created and return the stored value. Keep the genes immutable (`let`) so the stored value can't go out of date, and have your operators create new individuals instead of changing copies:

```swift
struct ExpensiveIndividual: GeneticElement {
    let genes: [Int]
    private let storedFitness: Double

    init(genes: [Int]) {
        self.genes = genes
        storedFitness = Double(genes.reduce(0, +)) // Replace with the expensive calculation
    }

    func fitness() -> Double {
        storedFitness
    }
}
```

### 2. Implement Genetic Operators

You can implement operators individually or create a `GeneticOperators` conforming type:

#### Option A: Individual Operators

```swift
// Selection: Tournament selection (each parent is the best of 3 random candidates)
let selection: SelectionOperator<MyIndividual> = { population in
    func selectOne() -> MyIndividual {
        let candidates = (0..<3).map { _ -> (individual: MyIndividual, fitness: Double) in
            let candidate = population.randomElement()!
            return (candidate, candidate.fitness()) // Evaluate each candidate once
        }
        return candidates.max { $0.fitness < $1.fitness }!.individual
    }
    return (selectOne(), selectOne())
}

// Crossover: One-point crossover
let crossover: CrossoverOperator<MyIndividual> = { parent1, parent2 in
    let point = Int.random(in: 0..<parent1.genes.count)
    let child1 = MyIndividual(
        genes: Array(parent1.genes[..<point]) + Array(parent2.genes[point...])
    )
    let child2 = MyIndividual(
        genes: Array(parent2.genes[..<point]) + Array(parent1.genes[point...])
    )
    return [child1, child2]
}

// Mutation: Random gene mutation
let mutation: MutationOperator<MyIndividual> = { individual in
    var mutant = individual
    let geneIndex = Int.random(in: 0..<mutant.genes.count)
    mutant.genes[geneIndex] = Int.random(in: 0...100)
    return mutant
}
```

#### Option B: Protocol-Based Approach

Implement the operators your problem needs and `newElement()`. Anything you leave out uses the protocol's default implementation (see [Default Operators](#default-operators)):

```swift
struct MyGeneticOperators: GeneticOperators {
    typealias Element = MyIndividual

    // selectionOperator, replacementOperator and fixedGenerationTermination
    // use the default implementations: tournament selection, generational
    // replacement, and stopping after a fixed number of generations.

    static func crossoverOperator(parent1: Element, parent2: Element) -> [Element] {
        let point = Int.random(in: 0..<parent1.genes.count)
        let child1 = MyIndividual(
            genes: Array(parent1.genes[..<point]) + Array(parent2.genes[point...])
        )
        let child2 = MyIndividual(
            genes: Array(parent2.genes[..<point]) + Array(parent1.genes[point...])
        )
        return [child1, child2]
    }

    static func mutationOperator(element: Element) -> Element {
        var mutant = element
        let geneIndex = Int.random(in: 0..<mutant.genes.count)
        mutant.genes[geneIndex] = Int.random(in: 0...100)
        return mutant
    }

    static func newElement() -> Element {
        return MyIndividual(genes: (0..<10).map { _ in Int.random(in: 0...100) })
    }
}
```

### 3. Create and Run the Solver

#### Using Individual Operators

Each individual has 10 genes from 0 to 100, so the best possible fitness is 1000. This example stops as soon as any individual reaches 950, or after 200 generations, whichever comes first:

```swift
var solver = GeneticSolver<MyIndividual>(
    populationSize: 50,
    crossoverRate: 0.8,
    mutationRate: 0.1,
    selectionOperator: selection,
    crossoverOperator: crossover,
    mutationOperator: mutation,
    replacementOperator: { _, new in new }, // Generational replacement
    terminationCheck: { _, population in
        // Stop as soon as any individual reaches the target fitness.
        population.contains { $0.fitness() >= 950 }
    },
    newElement: {
        MyIndividual(genes: (0..<10).map { _ in Int.random(in: 0...100) })
    }
)

// Run until the target is reached, or for at most 200 generations.
let finalPopulation = solver.solve(maxGenerations: 200)
print("Best fitness: \(solver.bestElement.fitness())")
```

#### Using Protocol-Based Operators

Pass the operators type to the solver. It uses the type's operators and `newElement()`, including any default implementations the type doesn't override:

```swift
var solver = GeneticSolver(
    populationSize: 50,
    crossoverRate: 0.8,
    mutationRate: 0.1,
    operators: MyGeneticOperators.self,
    terminationCheck: MyGeneticOperators.fixedGenerationTermination(maxGenerations: 100)
)

// Runs until the termination check stops it at generation 100.
let finalPopulation = solver.solve()
print("Best fitness: \(solver.bestElement.fitness())")
```

Each operator can still be replaced afterwards, for example `solver.mutationOperator = { ... }`.

## Advanced Usage

### Step-by-Step Execution

`step()` runs one generation and returns `true` once the termination check passes:

```swift
var solver = GeneticSolver<MyIndividual>(/* ... */)

// Run one generation at a time
while !solver.step() {
    print("Generation \(solver.currentGeneration): Best fitness = \(solver.bestElement.fitness())")
}

// Access current state
print("Final generation: \(solver.currentGeneration)")
print("Population size: \(solver.currentPopulation.count)")
```

### Continuing and Restarting

The solver keeps its population and generation count between calls. `solve(maxGenerations:)` continues from wherever `init`, `step()` or an earlier `solve` call left off, and runs until the termination check passes or the total generation count reaches `maxGenerations`. Call `reset()` to start over with a new population:

```swift
var solver = GeneticSolver<MyIndividual>(/* ... */)

solver.step()                          // Generation 1
_ = solver.solve(maxGenerations: 50)   // Continues up to generation 50
_ = solver.solve(maxGenerations: 100)  // Continues up to generation 100

solver.reset()                         // New population, generation 0
_ = solver.solve(maxGenerations: 100)  // A fresh run
```

### Custom Termination Conditions

The solver calls the termination check exactly once for each population: the one created by `init` or `reset()`, and the one produced by each generation. Assigning a new check to `terminationCheck` calls it once for the current population. The latest result is available as `solver.isTerminated`.

Because each population is checked exactly once, a check can keep its own state. This one stops when the best fitness hasn't improved for a number of generations:

```swift
/// Stops when the best fitness hasn't improved for `patience` generations.
func stallTermination(patience: Int) -> TerminationCheck<MyIndividual> {
    var bestSoFar = -Double.infinity
    var generationsWithoutImprovement = 0
    return { generation, population in
        // A new run, for example after `reset()`, starts again at generation 0.
        if generation == 0 {
            bestSoFar = -Double.infinity
            generationsWithoutImprovement = 0
        }
        let currentBest = population.map { $0.fitness() }.max() ?? -Double.infinity
        if currentBest > bestSoFar {
            bestSoFar = currentBest
            generationsWithoutImprovement = 0
        } else {
            generationsWithoutImprovement += 1
        }
        return generationsWithoutImprovement >= patience
    }
}

solver.terminationCheck = stallTermination(patience: 10)
```

### Elitism Replacement

The default replacement replaces the whole population, so the best individual found so far can be lost in the next generation. Elitist replacement carries the fittest individuals of each generation into the next one, so the best fitness never gets worse and `solver.bestElement` is always the best individual found so far:

```swift
var solver = GeneticSolver<MyIndividual>(
    populationSize: 50,
    crossoverRate: 0.8,
    mutationRate: 0.1,
    selectionOperator: selection,
    crossoverOperator: crossover,
    mutationOperator: mutation,
    replacementOperator: GeneticSolver.elitistReplacement(eliteCount: 2), // Keep the 2 fittest
    terminationCheck: { _, population in population.contains { $0.fitness() >= 950 } },
    newElement: { MyIndividual(genes: (0..<10).map { _ in Int.random(in: 0...100) }) }
)
```

The elite replace the last new individuals, so the population size doesn't change. Each individual of the current population has its fitness evaluated once per generation.

### Reproducible Runs

By default every random choice uses the system random number generator, so each run is different. To repeat a run exactly, for example to debug it, use a `SeededRandomNumberGenerator` wherever randomness is used: in your operators, in the selection operator, and for the solver's own decisions about when to apply crossover and mutation:

```swift
var random = SeededRandomNumberGenerator(seed: 42) // For your own operators

var solver = GeneticSolver<MyIndividual>(
    populationSize: 50,
    crossoverRate: 0.8,
    mutationRate: 0.1,
    selectionOperator: GeneticSolver.tournamentSelection(using: SeededRandomNumberGenerator(seed: 1)),
    crossoverOperator: { parent1, parent2 in
        let point = Int.random(in: 0..<parent1.genes.count, using: &random)
        return [
            MyIndividual(genes: Array(parent1.genes[..<point]) + Array(parent2.genes[point...])),
            MyIndividual(genes: Array(parent2.genes[..<point]) + Array(parent1.genes[point...])),
        ]
    },
    mutationOperator: { individual in
        var mutant = individual
        mutant.genes[Int.random(in: 0..<mutant.genes.count, using: &random)] = Int.random(in: 0...100, using: &random)
        return mutant
    },
    replacementOperator: { _, new in new },
    terminationCheck: { _, population in population.contains { $0.fitness() >= 950 } },
    newElement: { MyIndividual(genes: (0..<10).map { _ in Int.random(in: 0...100, using: &random) }) }
)
solver.randomNumberGenerator = SeededRandomNumberGenerator(seed: 2) // For the solver's own decisions

let finalPopulation = solver.solve(maxGenerations: 200) // The same result on every run
```

`SeededRandomNumberGenerator` produces the same numbers for the same seed on every platform. Numbers the standard library derives from them, like `Int.random(in:using:)`, were identical on Swift 5.9, 6.1 and 6.4, but a future Swift version could change them. `tournamentSelection(tournamentSize:using:)` also lets you choose the tournament size; larger tournaments favor fitter individuals more strongly.

### Roulette Wheel Selection

Each individual's chance of being picked is proportional to its fitness, so fitness must be finite and not negative. Individuals with fitness 0 are never picked, unless every individual has fitness 0 (as in a knapsack population where every selection is overweight); then parents are picked at random:

```swift
let rouletteSelection: SelectionOperator<MyIndividual> = { population in
    let fitnesses = population.map { $0.fitness() } // Evaluate each individual once
    precondition(fitnesses.allSatisfy { $0 >= 0 && $0.isFinite }, "Roulette wheel selection needs finite, non-negative fitness")
    let totalFitness = fitnesses.reduce(0, +)

    func selectOne() -> MyIndividual {
        // With no positive fitness there is no wheel to spin.
        guard totalFitness > 0 else { return population.randomElement()! }

        let target = Double.random(in: 0..<totalFitness)
        var cumulative = 0.0
        for (individual, fitness) in zip(population, fitnesses) {
            cumulative += fitness
            if cumulative > target {
                return individual
            }
        }
        // Not reached: the loop adds the same values in the same order as
        // totalFitness, so the final sum equals totalFitness > target.
        return population[population.count - 1]
    }

    return (selectOne(), selectOne())
}
```

## API Reference

### Core Types

- `GeneticElement`: Protocol for the individuals of a genetic algorithm; it includes `FitnessEvaluatable`
- `FitnessEvaluatable`: Protocol for types that can be evaluated for fitness
- `GeneticSolver<Element>`: Main solver class with state tracking
- `GeneticOperators`: Protocol defining core genetic algorithm operations; pass a conforming type to `GeneticSolver(populationSize:crossoverRate:mutationRate:operators:terminationCheck:)`

### Solver State and Methods

- `currentPopulation`: The current population
- `currentGeneration`: The number of generations run since `init` or the last `reset()`
- `bestElement`: The fittest individual in the current population (with elitist replacement, the best found so far)
- `isTerminated`: Whether the termination check passed for the current population
- `randomNumberGenerator`: The generator for the solver's decisions about applying crossover and mutation (the system generator unless you set one)
- `step()`: Runs one generation and returns `isTerminated`; does nothing once terminated
- `solve(maxGenerations:)`: Runs generations until terminated or `currentGeneration` reaches `maxGenerations`, and returns the population
- `reset()`: Starts over with a new population at generation 0

### Parameter Rules

`populationSize` must be at least 1, and `crossoverRate` and `mutationRate` must be between 0 and 1. These are settable properties, so the solver checks them in `init`, `reset()` and `step()`, and stops the program with a message such as `crossoverRate must be between 0 and 1, but is 1.5` when one is out of range. A replacement operator must return at least one individual.

### Random Numbers

- `SeededRandomNumberGenerator`: A random number generator that repeats its sequence for the same seed (SplitMix64; not for cryptography)

### Operator Types

- `SelectionOperator<Element>`: `([Element]) -> (Element, Element)`
- `CrossoverOperator<Element>`: `(Element, Element) -> [Element]`. It may return any number of children; if it returns none, the parents are kept
- `MutationOperator<Element>`: `(Element) -> Element`
- `ReplacementOperator<Element>`: `([Element], [Element]) -> [Element]`
- `TerminationCheck<Element>`: `(Int, [Element]) -> Bool`

### Default Operators

The `GeneticOperators` protocol provides default implementations for all genetic algorithm operations:

- `selectionOperator`: Tournament selection with tournament size of 3; `GeneticSolver.tournamentSelection(tournamentSize:using:)` takes another size and a random number generator
- `crossoverOperator`: Returns parents unchanged (no crossover)
- `mutationOperator`: Returns element unchanged (no mutation)
- `replacementOperator`: Generational replacement (replace all, so the best individual can be lost); `GeneticSolver.elitistReplacement(eliteCount:)` keeps the fittest
- `fixedGenerationTermination`: Stop after fixed number of generations
- `newElement`: Must be implemented by conforming types

## Examples

### Traveling Salesman Problem

A route visits every city once and returns to the start, so it is a permutation of the city indices. Use crossover and mutation operators that keep it a permutation, such as order crossover and swapping two cities; the one-point crossover from the Quick Start would visit some cities twice.

```swift
struct City {
    let x: Double, y: Double
}

struct TSPIndividual: GeneticElement {
    var route: [Int] // A permutation of the indices of `cities`
    let cities: [City]

    func fitness() -> Double {
        var totalDistance = 0.0
        for i in 0..<route.count {
            let current = cities[route[i]]
            let next = cities[route[(i + 1) % route.count]]
            let dx = next.x - current.x
            let dy = next.y - current.y
            totalDistance += (dx * dx + dy * dy).squareRoot()
        }
        // Higher fitness = shorter distance (infinite for a route of length 0)
        return 1.0 / totalDistance
    }
}
```

### Knapsack Problem

```swift
struct Item {
    let weight: Int
    let value: Int
}

struct KnapsackIndividual: GeneticElement {
    var selection: [Bool]
    let items: [Item]
    let maxWeight: Int

    func fitness() -> Double {
        let totalWeight = zip(selection, items).reduce(0) { sum, pair in
            sum + (pair.0 ? pair.1.weight : 0)
        }

        if totalWeight > maxWeight {
            return 0.0 // Invalid solution
        }

        let totalValue = zip(selection, items).reduce(0) { sum, pair in
            sum + (pair.0 ? pair.1.value : 0)
        }

        return Double(totalValue)
    }
}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Testing

Run the tests with `swift test`. CI also builds and tests on Linux with the oldest supported Swift version, which can reject code that newer compilers accept. To run those builds locally (requires Docker):

```bash
./scripts/test-linux.sh          # Swift versions from the Linux CI workflow
./scripts/test-linux.sh 5.9      # A specific version
```

To run the tests for an Apple platform the way CI does, with the Xcode selected by `xcode-select`:

```bash
./scripts/test-apple.sh macOS    # swift test
./scripts/test-apple.sh iOS      # xcodebuild test on the newest iOS simulator (also tvOS, visionOS)
```

### Releasing

Release tags are named `v<semantic version>`, for example `v0.2.0` or `v0.3.0-beta.1`. Pushing such a tag starts the Release workflow, which checks the tag name, runs the Apple, Linux and Windows tests, and then publishes a GitHub release with an installation snippet (`from: "0.2.0"`, without the `v`) followed by notes generated from the merged pull requests. Versions with a pre-release part, like `-beta.1`, are published as pre-releases.

### Code Formatting

This project uses SwiftFormat to maintain consistent code style. Different SwiftFormat versions can format the same code differently, so the project pins one version as the SwiftFormat `rev` in `.pre-commit-config.yaml`. The pre-commit hook and CI both use that version, and `./scripts/swiftformat-version.sh` prints it.

#### Local Development

1. Install SwiftFormat, ideally the pinned version (`./scripts/format.sh` warns when yours differs):
   ```bash
   brew install swiftformat
   ```
   Homebrew installs the latest release. To get exactly the pinned version, as CI does, run `./scripts/install-swiftformat.sh <folder>` and use `<folder>/swiftformat` (or put `<folder>` first in your `PATH`).

2. Format code locally:
   ```bash
   ./scripts/format.sh
   ```

3. Check formatting without making changes:
   ```bash
   ./scripts/format.sh --check
   ```

#### Pre-commit Hooks

Install pre-commit hooks to automatically format code before commits:

```bash
# Install pre-commit (3.2.0 or later)
pip install pre-commit

# Install the git hook scripts
pre-commit install
```

The hook versions, including the SwiftFormat version CI uses, are pinned in `.pre-commit-config.yaml`. Dependabot proposes updates weekly; `pre-commit autoupdate` updates them by hand. If an update changes how SwiftFormat formats code, the SwiftFormat check fails on that pull request until `./scripts/format.sh` is run on its branch.

#### CI/CD

- **Format Check**: Every PR is automatically checked for proper formatting
- **Auto-Format**: Weekly automated formatting PRs are created if needed
- **Pre-commit**: Local hooks ensure code is formatted before commits

#### Auto-Format Pull Requests

GitHub doesn't start other workflows for pull requests opened with the default `GITHUB_TOKEN`, so CI won't check an auto-format pull request on its own. To have CI run on them, give the Auto Format workflow its own token:

1. Create a [fine-grained personal access token](https://github.com/settings/personal-access-tokens/new) with access to this repository only, and the **Contents** and **Pull requests** permissions set to **Read and write**.
2. Add it as a repository secret named `AUTO_FORMAT_TOKEN` (Settings → Secrets and variables → Actions).

Without that secret, the workflow uses `GITHUB_TOKEN`, which needs **Allow GitHub Actions to create and approve pull requests** turned on (Settings → Actions → General). The pull request then says that its checks must be started by closing and reopening it.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
