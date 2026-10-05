//  TypeDefinitions.swift
//  RubicCubeTests
//
//  Created by Mateusz Kosikowski on 05/02/2024.
//

// MARK: - GeneticElement

/// An individual in the genetic algorithm: a candidate solution that the
/// solver can evaluate with `fitness()`.
///
/// Conforming to `GeneticElement` is enough to use a type with
/// `GeneticSolver`, because it includes `FitnessEvaluatable`. Listing both
/// protocols, as older code does, works too.
public protocol GeneticElement: FitnessEvaluatable {}

/// Selection operator: picks two parents from the population (for example by
/// tournament or roulette wheel selection)
public typealias SelectionOperator<Element> = ([Element]) -> (Element, Element)

/// Crossover operator: produces children from two parents. It may return any
/// number of children; when it returns none, the solver keeps the parents.
public typealias CrossoverOperator<Element> = (Element, Element) -> [Element]

/// Mutation operator: mutates an individual
public typealias MutationOperator<Element> = (Element) -> Element

/// Replacement operator: produces the next generation from old + new population
public typealias ReplacementOperator<Element> = ([Element], [Element]) -> [Element]

/// Termination check: determines if the algorithm should stop
public typealias TerminationCheck<Element> = (Int, [Element]) -> Bool
