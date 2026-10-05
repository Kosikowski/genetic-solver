//  ParameterValidationTests.swift
//  genetic-solverTests
//
//  Tests the rules the solver checks before it uses its parameters. The
//  solver stops with `fatalError` and the message tested here, which XCTest
//  can't catch, so the rules are tested through the function that produces
//  the message.

import XCTest
@testable import genetic_solver

// MARK: - ParameterValidationTests

final class ParameterValidationTests: XCTestCase {
    func testValidParametersHaveNoMessage() {
        XCTAssertNil(message(populationSize: 50, crossoverRate: 0.7, mutationRate: 0.01))
    }

    func testBoundaryValuesAreValid() {
        XCTAssertNil(message(populationSize: 1, crossoverRate: 0, mutationRate: 0))
        XCTAssertNil(message(populationSize: 1, crossoverRate: 1, mutationRate: 1))
        XCTAssertNil(message(populationSize: Int.max, crossoverRate: -0.0, mutationRate: -0.0))
    }

    func testPopulationSizeBelowOneIsInvalid() {
        for size in [0, -1, Int.min] {
            let text = message(populationSize: size, crossoverRate: 0.5, mutationRate: 0.5)
            XCTAssertEqual(text, "populationSize must be at least 1, but is \(size)")
        }
    }

    func testCrossoverRateOutsideZeroToOneIsInvalid() {
        for rate in [-0.000_001, 1.000_001, -1, 2, Double.infinity, -Double.infinity] {
            let text = message(populationSize: 10, crossoverRate: rate, mutationRate: 0.5)
            XCTAssertEqual(text, "crossoverRate must be between 0 and 1, but is \(rate)")
        }
    }

    func testCrossoverRateNaNIsInvalid() {
        let text = message(populationSize: 10, crossoverRate: .nan, mutationRate: 0.5)
        XCTAssertEqual(text, "crossoverRate must be between 0 and 1, but is nan")
    }

    func testMutationRateOutsideZeroToOneIsInvalid() {
        for rate in [-0.000_001, 1.000_001, -1, 2, Double.infinity, -Double.infinity] {
            let text = message(populationSize: 10, crossoverRate: 0.5, mutationRate: rate)
            XCTAssertEqual(text, "mutationRate must be between 0 and 1, but is \(rate)")
        }
    }

    func testMutationRateNaNIsInvalid() {
        let text = message(populationSize: 10, crossoverRate: 0.5, mutationRate: .nan)
        XCTAssertEqual(text, "mutationRate must be between 0 and 1, but is nan")
    }

    func testFirstInvalidParameterIsReported() {
        XCTAssertEqual(
            message(populationSize: 0, crossoverRate: 2, mutationRate: 2),
            "populationSize must be at least 1, but is 0"
        )
        XCTAssertEqual(
            message(populationSize: 1, crossoverRate: 2, mutationRate: 2),
            "crossoverRate must be between 0 and 1, but is 2.0"
        )
    }

    func testSolverWithBoundaryParametersRuns() {
        var solver = GeneticSolver<TestIndividual>(
            populationSize: 1,
            crossoverRate: 1,
            mutationRate: 1,
            selectionOperator: { ($0[0], $0[0]) },
            crossoverOperator: { [$0, $1] },
            mutationOperator: { $0 },
            replacementOperator: { _, new in new },
            terminationCheck: { _, _ in false },
            newElement: ElementFactory().make
        )

        _ = solver.solve(maxGenerations: 3)

        XCTAssertEqual(solver.currentGeneration, 3)
        XCTAssertEqual(solver.currentPopulation.count, 1)
    }

    // MARK: Helpers

    private func message(populationSize: Int, crossoverRate: Double, mutationRate: Double) -> String? {
        GeneticSolver<TestIndividual>.invalidParameterMessage(
            populationSize: populationSize,
            crossoverRate: crossoverRate,
            mutationRate: mutationRate
        )
    }
}
