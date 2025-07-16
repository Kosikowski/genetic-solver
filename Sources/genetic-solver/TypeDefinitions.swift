//  TypeDefinitions.swift
//  RubicCubeTests
//
//  Created by Mateusz Kosikowski on 05/02/2024.
//

// MARK: - GeneticElement

/// Protocol that represents an individual in the genetic algorithm.
public protocol GeneticElement {} // a marker porotocol for the Solver

/// Default selection operator using Comparable fitness (tournament, roulette, etc. can be user-provided)
public typealias SelectionOperator<Element> = ([Element]) -> (Element, Element)

/// Crossover operator: produces children from two parents
public typealias CrossoverOperator<Element> = (Element, Element) -> [Element]

/// Mutation operator: mutates an individual
public typealias MutationOperator<Element> = (Element) -> Element

/// Replacement operator: produces the next generation from old + new population
public typealias ReplacementOperator<Element> = ([Element], [Element]) -> [Element]

/// Termination check: determines if the algorithm should stop
public typealias TerminationCheck<Element> = (Int, [Element]) -> Bool
