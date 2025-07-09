//  FitnessEvaluatable.swift
//  RubicCubeTests
//
//  Created by Mateusz Kosikowski on 05/02/2024.
//

/// Protocol for types that can be evaluated for fitness.
public protocol FitnessEvaluatable {
    associatedtype Fitness: Comparable
    func fitness() -> Fitness
}
