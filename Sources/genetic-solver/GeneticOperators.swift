//  GeneticOperators.swift
//  genetic-solver
//
//  Created by Mateusz Kosikowski on 05/02/2024.
//
//  This file defines the GeneticOperators protocol and its default implementations.
//  The protocol outlines essential genetic algorithm operations such as selection,
//  crossover, mutation, replacement, and termination criteria. It provides a flexible
//  interface for evolving populations of elements conforming to FitnessEvaluatable.

// MARK: - GeneticOperators

/// Protocol defining the core genetic algorithm operations required to evolve a population.
/// The associated type `Element` has the same requirements as `GeneticSolver`'s element,
/// so a conforming type can be passed to
/// `GeneticSolver(populationSize:crossoverRate:mutationRate:operators:terminationCheck:)`.
public protocol GeneticOperators {
    associatedtype Element: GeneticElement

    /// Selects two individuals from the population for reproduction.
    /// - Parameter population: The current population array.
    /// - Returns: A tuple containing two selected elements.
    static func selectionOperator(population: [Element]) -> (Element, Element)

    /// Performs crossover on two parent elements to produce offspring.
    /// - Parameters:
    ///   - parent1: The first parent element.
    ///   - parent2: The second parent element.
    /// - Returns: An array of offspring elements resulting from crossover.
    static func crossoverOperator(parent1: Element, parent2: Element) -> [Element]

    /// Mutates a given element to introduce variation.
    /// - Parameter element: The element to mutate.
    /// - Returns: The mutated element.
    static func mutationOperator(element: Element) -> Element

    /// Replaces elements in the population with new elements.
    /// - Parameters:
    ///   - old: The current population elements to be replaced.
    ///   - new: The new elements to insert.
    /// - Returns: The resulting population after replacement.
    static func replacementOperator(old: [Element], new: [Element]) -> [Element]

    /// Provides a termination condition based on a fixed number of generations.
    /// - Parameter maxGenerations: The maximum number of generations allowed.
    /// - Returns: A closure that determines if the evolutionary process should terminate.
    static func fixedGenerationTermination(maxGenerations: Int) -> TerminationCheck<Element>

    /// Creates a new random element.
    /// - Returns: A new element instance.
    static func newElement() -> Element
}

public extension GeneticOperators {
    /// Default selection operator implementing tournament selection with a tournament size of 3.
    /// Each parent is the best of three randomly chosen candidates; on a tie, the candidate
    /// drawn first wins. Each candidate's fitness is evaluated once.
    ///
    /// It uses the system random number generator. For another tournament size or a seeded
    /// generator, use `GeneticSolver.tournamentSelection(tournamentSize:using:)`.
    static func selectionOperator(population: [Element]) -> (Element, Element) {
        var generator = SystemRandomNumberGenerator()
        let first = tournamentWinner(of: population, size: 3, using: &generator)
        let second = tournamentWinner(of: population, size: 3, using: &generator)
        return (first, second)
    }

    /// Default crossover operator that returns the parents unchanged (no crossover).
    static func crossoverOperator(parent1: Element, parent2: Element) -> [Element] {
        [parent1, parent2]
    }

    /// Default mutation operator that returns the element unchanged (no mutation).
    static func mutationOperator(element: Element) -> Element {
        element
    }

    /// Default replacement operator that completely replaces the old population with the new one.
    static func replacementOperator(old _: [Element], new: [Element]) -> [Element] {
        new
    }

    /// Default termination condition that stops the algorithm after a fixed maximum number of generations.
    static func fixedGenerationTermination(maxGenerations: Int) -> TerminationCheck<Element> {
        { generation, _ in generation >= maxGenerations }
    }
}
