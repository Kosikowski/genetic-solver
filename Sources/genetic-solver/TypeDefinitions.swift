//  TypeDefinitions.swift
//  genetic-solver
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
///
/// Because it includes `FitnessEvaluatable`'s `Fitness` associated type,
/// using it as a type needs `any`, for example `[any GeneticElement]`.
public protocol GeneticElement: FitnessEvaluatable {}

/// Selection operator: picks two parents from the population (for example by
/// tournament or roulette wheel selection). It receives the population with
/// each individual's fitness, and returns two of its members.
public typealias SelectionOperator<Element: FitnessEvaluatable> =
    ([EvaluatedElement<Element>]) -> (EvaluatedElement<Element>, EvaluatedElement<Element>)

/// Crossover operator: produces children from two parents. It may return any
/// number of children; when it returns none, the solver keeps the parents.
public typealias CrossoverOperator<Element> = (Element, Element) -> [Element]

/// Mutation operator: mutates an individual
public typealias MutationOperator<Element> = (Element) -> Element

/// Replacement operator: produces the next generation from the current
/// population and the new individuals, each with its fitness. To add an
/// individual of its own, it can create one with `EvaluatedElement(_:)`.
public typealias ReplacementOperator<Element: FitnessEvaluatable> =
    ([EvaluatedElement<Element>], [EvaluatedElement<Element>]) -> [EvaluatedElement<Element>]

/// Termination check: decides whether the algorithm should stop, given the
/// generation count and the population with each individual's fitness
public typealias TerminationCheck<Element: FitnessEvaluatable> = (Int, [EvaluatedElement<Element>]) -> Bool
