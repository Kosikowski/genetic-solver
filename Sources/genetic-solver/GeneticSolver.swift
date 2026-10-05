//  GeneticSolver.swift
//  RubicCubeTests
//
//  Created by Mateusz Kosikowski on 05/02/2024.
//

/// Genetic Solver: highly generic, extensible genetic algorithm framework
public struct GeneticSolver<Element: GeneticElement & FitnessEvaluatable> {
    // MARK: Properties

    // Parameters
    public var populationSize: Int
    public var crossoverRate: Double
    public var mutationRate: Double

    // Operators (can be replaced by user)
    public var selectionOperator: SelectionOperator<Element>
    public var crossoverOperator: CrossoverOperator<Element>
    public var mutationOperator: MutationOperator<Element>
    public var replacementOperator: ReplacementOperator<Element>
    public var newElement: () -> Element

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

    // MARK: Lifecycle

    /// Initialize the genetic solver with the specified parameters and operators.
    ///
    /// The first population is created right away by calling `newElement`
    /// `populationSize` times, and `terminationCheck` is called once for it.
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

        let initialPopulation = (0 ..< populationSize).map { _ in newElement() }
        currentPopulation = initialPopulation
        currentGeneration = 0
        isTerminated = terminationCheck(0, initialPopulation)
    }

    // MARK: Functions

    /// Run generations until the termination check passes or `currentGeneration`
    /// reaches `maxGenerations`, then return the current population.
    ///
    /// The run continues from the current state: the population created by
    /// `init`, or wherever earlier calls to `step()` or `solve(maxGenerations:)`
    /// left off. `maxGenerations` limits the total generation count, not the
    /// number of generations run by this call. Call `reset()` to start over.
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
        // Selection & Crossover
        var offspring: [Element] = []
        while offspring.count < populationSize {
            let (parent1, parent2) = selectionOperator(currentPopulation)
            let children: [Element]
            if Double.random(in: 0 ..< 1) < crossoverRate {
                children = crossoverOperator(parent1, parent2)
            } else {
                children = [parent1, parent2]
            }
            offspring.append(contentsOf: children)
        }
        offspring = Array(offspring.prefix(populationSize))
        // Mutation
        let mutated = offspring.map { elem in
            Double.random(in: 0 ..< 1) < mutationRate ? mutationOperator(elem) : elem
        }
        // Replacement
        currentPopulation = replacementOperator(currentPopulation, mutated)
        currentGeneration += 1
        isTerminated = terminationCheck(currentGeneration, currentPopulation)
        return isTerminated
    }
}
