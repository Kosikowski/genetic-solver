//  FitnessEvaluatable.swift
//  genetic-solver
//
//  Created by Mateusz Kosikowski on 05/02/2024.
//

/// Protocol for types that can be evaluated for fitness.
public protocol FitnessEvaluatable {
    associatedtype Fitness: Comparable

    /// Returns how good this individual is; higher is better.
    ///
    /// The solver calls it once for each new individual and keeps the result
    /// in an `EvaluatedElement`, which the operators, the termination check
    /// and `bestElement` use instead of calling it again. So it may be
    /// expensive, but it should depend only on the individual: the result is
    /// kept for as long as the individual stays in the population.
    func fitness() -> Fitness
}
