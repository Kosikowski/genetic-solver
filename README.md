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

- **Generic Design**: Works with any type that conforms to `GeneticElement` and `FitnessEvaluatable`
- **Customizable Operators**: Full control over selection, crossover, mutation, and replacement strategies
- **Protocol-Based Design**: Uses `GeneticOperators` protocol for clean separation of concerns
- **Default Implementations**: Built-in operators for common genetic algorithm patterns
- **Type Safety**: Leverages Swift's type system for compile-time safety
- **Extensible**: Easy to extend with custom operators and termination conditions
- **State Tracking**: Monitor current population and generation during execution
- **Incremental Execution**: Step-by-step execution with the `step()` method

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Kosikowski/genetic-solver.git", from: "1.0.0")
]
```

Or add it to your Xcode project:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version you want to use

## Quick Start

### 1. Define Your Individual

First, create a type that represents an individual in your genetic algorithm:

```swift
struct MyIndividual: GeneticElement, FitnessEvaluatable {
    var genes: [Int]

    func fitness() -> Double {
        // Calculate fitness based on your problem
        return Double(genes.reduce(0, +))
    }
}
```

### 2. Implement Genetic Operators

You can implement operators individually or create a `GeneticOperators` conforming type:

#### Option A: Individual Operators

```swift
// Selection: Tournament selection
let selection: SelectionOperator<MyIndividual> = { population in
    func selectOne() -> MyIndividual {
        let candidates = (0..<3).map { _ in population.randomElement()! }
        return candidates.max { $0.fitness() < $1.fitness() }!
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

```swift
struct MyGeneticOperators: GeneticOperators {
    typealias Element = MyIndividual

    static func selectionOperator(population: [Element]) -> (Element, Element) {
        // Use default tournament selection
        let candidates = (0..<3).map { _ in population.randomElement()! }
        let best = candidates.max { $0.fitness() < $1.fitness() }!
        return (best, best)
    }

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

    static func replacementOperator(old: [Element], new: [Element]) -> [Element] {
        return new // Generational replacement
    }

    static func fixedGenerationTermination(maxGenerations: Int) -> TerminationCheck<Element> {
        return { generation, _ in generation >= maxGenerations }
    }

    static func newElement() -> Element {
        return MyIndividual(genes: (0..<10).map { _ in Int.random(in: 0...100) })
    }
}
```

### 3. Create and Run the Solver

#### Using Individual Operators

```swift
var solver = GeneticSolver<MyIndividual>(
    populationSize: 50,
    crossoverRate: 0.8,
    mutationRate: 0.1,
    selectionOperator: selection,
    crossoverOperator: crossover,
    mutationOperator: mutation,
    replacementOperator: { _, new in new }, // Generational replacement
    terminationCheck: { generation, population in
        generation >= 100 || population.allSatisfy { $0.fitness() > 0.95 }
    },
    newElement: {
        MyIndividual(genes: (0..<10).map { _ in Int.random(in: 0...100) })
    }
)

let finalPopulation = solver.solve(maxGenerations: 200)
let bestIndividual = finalPopulation.max { $0.fitness() < $1.fitness() }!
print("Best fitness: \(bestIndividual.fitness())")
```

#### Using Protocol-Based Operators

```swift
var solver = GeneticSolver<MyIndividual>(
    populationSize: 50,
    crossoverRate: 0.8,
    mutationRate: 0.1,
    selectionOperator: { MyGeneticOperators.selectionOperator(population: $0) },
    crossoverOperator: { MyGeneticOperators.crossoverOperator(parent1: $0, parent2: $1) },
    mutationOperator: { MyGeneticOperators.mutationOperator(element: $0) },
    replacementOperator: { MyGeneticOperators.replacementOperator(old: $0, new: $1) },
    terminationCheck: MyGeneticOperators.fixedGenerationTermination(maxGenerations: 100),
    newElement: { MyGeneticOperators.newElement() }
)

let finalPopulation = solver.solve(maxGenerations: 200)
let bestIndividual = finalPopulation.max { $0.fitness() < $1.fitness() }!
print("Best fitness: \(bestIndividual.fitness())")
```

## Advanced Usage

### Step-by-Step Execution

The solver now supports incremental execution using the `step()` method:

```swift
var solver = GeneticSolver<MyIndividual>(/* ... */)

// Run one generation at a time
while !solver.step() {
    print("Generation \(solver.currentGeneration): Best fitness = \(solver.currentPopulation.map { $0.fitness() }.max()!)")
}

// Access current state
print("Final generation: \(solver.currentGeneration)")
print("Population size: \(solver.currentPopulation.count)")
```

### Custom Termination Conditions

```swift
// Stop when fitness improvement stalls
let adaptiveTermination: TerminationCheck<MyIndividual> = { generation, population in
    if generation < 10 { return false }

    let currentBest = population.map { $0.fitness() }.max()!
    let previousBest = // ... get from history

    return abs(currentBest - previousBest) < 0.001
}
```

### Elitism Replacement

```swift
let elitismReplacement: ReplacementOperator<MyIndividual> = { old, new in
    let eliteCount = 2
    let sortedOld = old.sorted { $0.fitness() > $1.fitness() }
    let elite = Array(sortedOld.prefix(eliteCount))
    let sortedNew = new.sorted { $0.fitness() > $1.fitness() }
    let rest = Array(sortedNew.prefix(old.count - eliteCount))
    return elite + rest
}
```

### Roulette Wheel Selection

```swift
let rouletteSelection: SelectionOperator<MyIndividual> = { population in
    let totalFitness = population.reduce(0) { $0 + $1.fitness() }

    func selectOne() -> MyIndividual {
        let target = Double.random(in: 0..<totalFitness)
        var cumulative = 0.0

        for individual in population {
            cumulative += individual.fitness()
            if cumulative >= target {
                return individual
            }
        }
        return population.last!
    }

    return (selectOne(), selectOne())
}
```

## API Reference

### Core Types

- `GeneticElement`: Protocol for types that can participate in genetic algorithms
- `FitnessEvaluatable`: Protocol for types that can be evaluated for fitness
- `GeneticSolver<Element>`: Main solver class with state tracking
- `GeneticOperators`: Protocol defining core genetic algorithm operations

### Operator Types

- `SelectionOperator<Element>`: `([Element]) -> (Element, Element)`
- `CrossoverOperator<Element>`: `(Element, Element) -> [Element]`
- `MutationOperator<Element>`: `(Element) -> Element`
- `ReplacementOperator<Element>`: `([Element], [Element]) -> [Element]`
- `TerminationCheck<Element>`: `(Int, [Element]) -> Bool`

### Default Operators

The `GeneticOperators` protocol provides default implementations for all genetic algorithm operations:

- `selectionOperator`: Tournament selection with tournament size of 3
- `crossoverOperator`: Returns parents unchanged (no crossover)
- `mutationOperator`: Returns element unchanged (no mutation)
- `replacementOperator`: Generational replacement (replace all)
- `fixedGenerationTermination`: Stop after fixed number of generations
- `newElement`: Must be implemented by conforming types

## Examples

### Traveling Salesman Problem

```swift
struct City {
    let x: Double, y: Double
}

struct TSPIndividual: GeneticElement, FitnessEvaluatable {
    var route: [Int]
    let cities: [City]

    func fitness() -> Double {
        var totalDistance = 0.0
        for i in 0..<route.count {
            let current = cities[route[i]]
            let next = cities[route[(i + 1) % route.count]]
            let distance = sqrt(pow(next.x - current.x, 2) + pow(next.y - current.y, 2))
            totalDistance += distance
        }
        return 1.0 / totalDistance // Higher fitness = shorter distance
    }
}
```

### Knapsack Problem

```swift
struct Item {
    let weight: Int
    let value: Int
}

struct KnapsackIndividual: GeneticElement, FitnessEvaluatable {
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

### Code Formatting

This project uses SwiftFormat to maintain consistent code style.

#### Local Development

1. Install SwiftFormat:
   ```bash
   brew install swiftformat
   ```

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
# Install pre-commit
pip install pre-commit

# Install the git hook scripts
pre-commit install
```

#### CI/CD

- **Format Check**: Every PR is automatically checked for proper formatting
- **Auto-Format**: Weekly automated formatting PRs are created if needed
- **Pre-commit**: Local hooks ensure code is formatted before commits

## License

This project is licensed under the MIT License - see the LICENSE file for details.
