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
    /// Operators and termination checks may call this many times for the same
    /// individual (the default tournament selection calls it once per
    /// candidate). If it is expensive, compute it once, for example when the
    /// individual is created, and return the stored value.
    func fitness() -> Fitness
}
