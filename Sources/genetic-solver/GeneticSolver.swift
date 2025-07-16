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
    public var terminationCheck: TerminationCheck<Element>
    public var newElement: () -> Element

    /// The current population of individuals.
    public private(set) var currentPopulation: [Element]

    /// The current generation count.
    public private(set) var currentGeneration: Int

    // MARK: Lifecycle

    /// Initialize the genetic solver with the specified parameters and operators.
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

        currentPopulation = (0 ..< populationSize).map { _ in newElement() }
        currentGeneration = 0
    }

    // MARK: Functions

    /// Run the genetic algorithm until termination or maxGenerations reached, returning the final population.
    public mutating func solve(maxGenerations: Int = 1000) -> [Element] {
        currentPopulation = (0 ..< populationSize).map { _ in newElement() }
        currentGeneration = 0
        while currentGeneration < maxGenerations, !terminationCheck(currentGeneration, currentPopulation) {
            if step() {
                break
            }
        }
        return currentPopulation
    }

    /// Advance the algorithm by one generation. Returns true if terminated, false otherwise.
    @discardableResult
    public mutating func step() -> Bool {
        guard !terminationCheck(currentGeneration, currentPopulation) else { return true }
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
        return terminationCheck(currentGeneration, currentPopulation)
    }
}
