//  GeneticOperators.swift
//  RubicCubeTests
//
//  Created by Mateusz Kosikowski on 05/02/2024.
//
//  This file defines the GeneticOperators protocol and its default implementations.
//  The protocol outlines essential genetic algorithm operations such as selection,
//  crossover, mutation, replacement, and termination criteria. It provides a flexible
//  interface for evolving populations of elements conforming to FitnessEvaluatable.

/// Protocol defining the core genetic algorithm operations required to evolve a population.
/// The associated type `Element` must conform to `FitnessEvaluatable` to allow fitness-based operations.
public protocol GeneticOperators {
    associatedtype Element: FitnessEvaluatable

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
    /// Selects the best individual out of three randomly chosen candidates.
    static func selectionOperator(population: [Element]) -> (Element, Element) {
        func selectOne() -> Element {
            let candidates = (0 ..< 3).map { _ in population.randomElement()! }
            return candidates.max { $0.fitness() < $1.fitness() }!
        }
        return (selectOne(), selectOne())
    }

    /// Default crossover operator that returns the parents unchanged (no crossover).
    static func crossoverOperator(parent1: Element, parent2: Element) -> [Element] {
        return [parent1, parent2]
    }

    /// Default mutation operator that returns the element unchanged (no mutation).
    static func mutationOperator(element: Element) -> Element {
        return element
    }

    /// Default replacement operator that completely replaces the old population with the new one.
    static func replacementOperator(old _: [Element], new: [Element]) -> [Element] {
        return new
    }

    /// Default termination condition that stops the algorithm after a fixed maximum number of generations.
    static func fixedGenerationTermination(maxGenerations: Int) -> TerminationCheck<Element> {
        return { generation, _ in generation >= maxGenerations }
    }
}
