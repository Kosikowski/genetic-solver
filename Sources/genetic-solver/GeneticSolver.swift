//  GeneticSolver.swift
//  genetic-solver
//
//  Created by Mateusz Kosikowski on 05/02/2024.
//

/// Genetic Solver: highly generic, extensible genetic algorithm framework
public struct GeneticSolver<Element: GeneticElement> {
    // MARK: Properties

    // Parameters, checked by `init`, `reset()` and `step()`, which stop the
    // program with a message when one is out of range

    /// The number of individuals in each generation. Must be at least 1.
    public var populationSize: Int

    /// The probability, from 0 to 1, that `crossoverOperator` is applied to a
    /// selected pair of parents.
    public var crossoverRate: Double

    /// The probability, from 0 to 1, that `mutationOperator` is applied to
    /// each individual of the next generation.
    public var mutationRate: Double

    // Operators, which can be replaced at any time

    /// Picks two parents from the current population.
    public var selectionOperator: SelectionOperator<Element>

    /// Combines two selected parents into children. It is applied to each
    /// selected pair with probability `crossoverRate`; otherwise, or when it
    /// returns no children, the parents are copied into the next generation
    /// unchanged. Children beyond `populationSize` are dropped.
    public var crossoverOperator: CrossoverOperator<Element>

    /// Changes an individual. It is applied to each individual of the next
    /// generation with probability `mutationRate`.
    public var mutationOperator: MutationOperator<Element>

    /// Builds the next population from the current population and the new
    /// individuals. It must return at least one individual.
    public var replacementOperator: ReplacementOperator<Element>

    /// Creates a new individual. Used to fill the population in `init` and
    /// `reset()`.
    public var newElement: () -> Element

    /// The random number generator for the solver's own random decisions:
    /// whether `crossoverOperator` is applied to a pair of parents, and whether
    /// `mutationOperator` is applied to an individual. It starts as
    /// `SystemRandomNumberGenerator`.
    ///
    /// To make runs reproducible, set it to a `SeededRandomNumberGenerator` and
    /// give your operators seeded generators too.
    ///
    /// Copying the solver copies this property. For a value type such as
    /// `SeededRandomNumberGenerator`, that copies its state, so the copy makes
    /// the same crossover and mutation decisions as the original. Copies of
    /// `SystemRandomNumberGenerator` decide independently, and a generator
    /// that is a class is shared by the copies. Generators captured by the
    /// operators, such as the one in `tournamentSelection(tournamentSize:using:)`,
    /// are shared too, so copies of a solver pick different parents.
    public var randomNumberGenerator: any RandomNumberGenerator = SystemRandomNumberGenerator()

    /// Decides whether the run is finished, given the generation count and
    /// the population.
    ///
    /// The solver calls it exactly once for each population: the one created
    /// by `init` or `reset()`, and the one produced by each generation. The
    /// result is kept in `isTerminated`, so a check that keeps its own state
    /// (for example, counting generations without improvement) sees every
    /// generation once. Assigning a new check calls it once for the current
    /// population.
    public var terminationCheck: TerminationCheck<Element> {
        didSet {
            isTerminated = terminationCheck(currentGeneration, currentPopulation)
        }
    }

    /// The current population of individuals.
    public private(set) var currentPopulation: [Element]

    /// The current generation count.
    public private(set) var currentGeneration: Int

    /// Whether `terminationCheck` passed for the current population. Once it
    /// is `true`, `step()` and `solve(maxGenerations:)` run no more
    /// generations until `reset()` is called or `terminationCheck` is
    /// replaced with one that returns `false`.
    public private(set) var isTerminated: Bool

    // MARK: Computed Properties

    /// The fittest individual in the current population; on a tie, the first
    /// one. Each access evaluates `fitness()` once per individual.
    ///
    /// The default replacement operator replaces the whole population, so the
    /// best individual found so far can be lost. With
    /// `elitistReplacement(eliteCount:)` (and an `eliteCount` of at least 1),
    /// this is always the best individual found so far.
    public var bestElement: Element {
        // The population is never empty: `populationSize` is at least 1 and
        // `step()` stops if a replacement operator returns no individuals.
        let fitnesses = currentPopulation.map { $0.fitness() }
        let bestIndex = fitnesses.indices.max { fitnesses[$0] < fitnesses[$1] }!
        return currentPopulation[bestIndex]
    }

    // MARK: Lifecycle

    /// Initialize the genetic solver with the specified parameters and operators.
    ///
    /// The first population is created right away by calling `newElement`
    /// `populationSize` times, and `terminationCheck` is called once for it.
    ///
    /// - Precondition: `populationSize` is at least 1, and `crossoverRate` and
    ///   `mutationRate` are between 0 and 1.
    public init(
        populationSize: Int,
        crossoverRate: Double = 0.7,
        mutationRate: Double = 0.01,
        selectionOperator: @escaping SelectionOperator<Element>,
        crossoverOperator: @escaping CrossoverOperator<Element>,
        mutationOperator: @escaping MutationOperator<Element>,
        replacementOperator: @escaping ReplacementOperator<Element>,
        terminationCheck: @escaping TerminationCheck<Element>,
        newElement: @escaping () -> Element
    ) {
        self.populationSize = populationSize
        self.crossoverRate = crossoverRate
        self.mutationRate = mutationRate
        self.selectionOperator = selectionOperator
        self.crossoverOperator = crossoverOperator
        self.mutationOperator = mutationOperator
        self.replacementOperator = replacementOperator
        self.terminationCheck = terminationCheck
        self.newElement = newElement

        Self.checkParameters(populationSize: populationSize, crossoverRate: crossoverRate, mutationRate: mutationRate)

        let initialPopulation = (0 ..< populationSize).map { _ in newElement() }
        currentPopulation = initialPopulation
        currentGeneration = 0
        isTerminated = terminationCheck(0, initialPopulation)
    }

    // MARK: Static Functions

    /// Returns a description of the first parameter that is out of range, or
    /// `nil` when `populationSize` is at least 1 and both rates are between 0
    /// and 1. NaN and infinite rates are out of range.
    static func invalidParameterMessage(populationSize: Int, crossoverRate: Double, mutationRate: Double) -> String? {
        if populationSize < 1 {
            return "populationSize must be at least 1, but is \(populationSize)"
        }
        if !(0 ... 1).contains(crossoverRate) {
            return "crossoverRate must be between 0 and 1, but is \(crossoverRate)"
        }
        if !(0 ... 1).contains(mutationRate) {
            return "mutationRate must be between 0 and 1, but is \(mutationRate)"
        }
        return nil
    }

    /// Stops the program with a message when a parameter is out of range.
    /// The parameters are public and settable, so `init`, `reset()` and
    /// `step()` check them whenever they use them. `fatalError` is used
    /// rather than `preconditionFailure` because it prints the message in
    /// optimized builds too.
    private static func checkParameters(populationSize: Int, crossoverRate: Double, mutationRate: Double) {
        if
            let message = invalidParameterMessage(
                populationSize: populationSize,
                crossoverRate: crossoverRate,
                mutationRate: mutationRate
            )
        {
            fatalError(message)
        }
    }

    // MARK: Functions

    /// Run generations until the termination check passes or `currentGeneration`
    /// reaches `maxGenerations`, then return the current population.
    ///
    /// The run continues from the current state: the population created by
    /// `init`, or wherever earlier calls to `step()` or `solve(maxGenerations:)`
    /// left off. `maxGenerations` limits the total generation count, not the
    /// number of generations run by this call. Call `reset()` to start over.
    ///
    /// The result is the same as `currentPopulation`, so it can be ignored, for
    /// example when only `bestElement` is needed.
    @discardableResult
    public mutating func solve(maxGenerations: Int = 1000) -> [Element] {
        while currentGeneration < maxGenerations, !isTerminated {
            step()
        }
        return currentPopulation
    }

    /// Replace the population with `populationSize` new elements from
    /// `newElement`, set `currentGeneration` back to 0, and call
    /// `terminationCheck` once for the new population.
    public mutating func reset() {
        Self.checkParameters(populationSize: populationSize, crossoverRate: crossoverRate, mutationRate: mutationRate)
        currentPopulation = (0 ..< populationSize).map { _ in newElement() }
        currentGeneration = 0
        isTerminated = terminationCheck(currentGeneration, currentPopulation)
    }

    /// Advance the algorithm by one generation and return `isTerminated`.
    ///
    /// If the solver has already terminated, this does nothing and returns
    /// `true`. Otherwise it runs one generation, calls `terminationCheck`
    /// once for the new population, and returns the result.
    @discardableResult
    public mutating func step() -> Bool {
        guard !isTerminated else { return true }
        Self.checkParameters(populationSize: populationSize, crossoverRate: crossoverRate, mutationRate: mutationRate)
        // Selection & Crossover
        var offspring: [Element] = []
        while offspring.count < populationSize {
            let (parent1, parent2) = selectionOperator(currentPopulation)
            let children = Double.random(in: 0 ..< 1, using: &randomNumberGenerator) < crossoverRate ? crossoverOperator(parent1, parent2) : []
            // Copy the parents when crossover is skipped or returns no children,
            // so every pass adds at least one element and the loop always ends.
            offspring.append(contentsOf: children.isEmpty ? [parent1, parent2] : children)
        }
        offspring = Array(offspring.prefix(populationSize))
        // Mutation
        let mutated = offspring.map { elem in
            Double.random(in: 0 ..< 1, using: &randomNumberGenerator) < mutationRate ? mutationOperator(elem) : elem
        }
        // Replacement
        currentPopulation = replacementOperator(currentPopulation, mutated)
        if currentPopulation.isEmpty {
            fatalError("replacementOperator returned no individuals")
        }
        currentGeneration += 1
        isTerminated = terminationCheck(currentGeneration, currentPopulation)
        return isTerminated
    }
}
