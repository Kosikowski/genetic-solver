//  OffspringTests.swift
//  genetic-solverTests
//
//  Tests how step() builds the next generation from selected parents and
//  the children the crossover operator returns.

import XCTest
@testable import genetic_solver

// MARK: - OffspringTests

final class OffspringTests: XCTestCase {
    // MARK: Crossover returning no children

    func testCrossoverReturningNoChildrenCopiesTheParents() {
        var crossoverCalls = 0
        var solver = makeDeterministicSolver(
            populationSize: 4,
            crossoverRate: 1,
            crossoverOperator: { parent1, parent2 in
                crossoverCalls += 1
                // Safety valve: if empty results ever make step() loop again,
                // this ends the loop so the test fails instead of hanging.
                return crossoverCalls > 1000 ? [parent1, parent2] : []
            }
        )

        solver.step()

        XCTAssertEqual(crossoverCalls, 2, "Each pass should add the two parents")
        XCTAssertEqual(solver.currentPopulation.map(\.id), [0, 1, 0, 1])
    }

    func testCrossoverSometimesReturningNoChildrenStillFillsThePopulation() {
        var crossoverCalls = 0
        var solver = makeDeterministicSolver(
            populationSize: 6,
            crossoverRate: 1,
            crossoverOperator: { parent1, parent2 in
                crossoverCalls += 1
                if crossoverCalls > 1000 {
                    return [parent1, parent2]
                }
                // Every other call produces one new child.
                return crossoverCalls.isMultiple(of: 2) ? [TestIndividual(gene: .one, id: 100 + crossoverCalls)] : []
            }
        )

        solver.step()

        // Calls 1, 3 and 5 add the parents (2 each); calls 2 and 4 add one
        // child each: 2 + 1 + 2 + 1 = 6 after four calls.
        XCTAssertEqual(crossoverCalls, 4)
        XCTAssertEqual(solver.currentPopulation.map(\.id), [0, 1, 102, 0, 1, 104])
    }

    // MARK: Number of children

    func testCrossoverReturningOneChildFillsThePopulationOneChildAtATime() {
        var crossoverCalls = 0
        var solver = makeDeterministicSolver(
            populationSize: 3,
            crossoverRate: 1,
            crossoverOperator: { _, _ in
                crossoverCalls += 1
                return [TestIndividual(gene: .one, id: 100 + crossoverCalls)]
            }
        )

        solver.step()

        XCTAssertEqual(crossoverCalls, 3)
        XCTAssertEqual(solver.currentPopulation.map(\.id), [101, 102, 103])
    }

    func testExtraChildrenAreDroppedToKeepThePopulationSize() {
        var solver = makeDeterministicSolver(
            populationSize: 4,
            crossoverRate: 1,
            crossoverOperator: { _, _ in (100 ..< 105).map { TestIndividual(gene: .one, id: $0) } }
        )

        solver.step()

        XCTAssertEqual(solver.currentPopulation.map(\.id), [100, 101, 102, 103])
    }

    func testOddPopulationSizeDropsTheLastPairsSecondChild() {
        var solver = makeDeterministicSolver(populationSize: 5)

        solver.step()

        XCTAssertEqual(solver.currentPopulation.map(\.id), [0, 1, 0, 1, 0])
    }

    func testPopulationSizeOfOneUsesTheFirstParentOnly() {
        // Selection needs two individuals, so this solver picks the same one twice.
        var solver = GeneticSolver<TestIndividual>(
            populationSize: 1,
            selectionOperator: { ($0[0], $0[0]) },
            crossoverOperator: { [$0, $1] },
            mutationOperator: { $0 },
            replacementOperator: { _, new in new },
            terminationCheck: { _, _ in false },
            newElement: ElementFactory().make
        )

        solver.step()

        XCTAssertEqual(solver.currentPopulation.map(\.id), [0])
    }

    // MARK: Crossover rate

    func testCrossoverRateOfZeroNeverCallsCrossover() {
        var crossoverCalls = 0
        var solver = makeDeterministicSolver(
            crossoverRate: 0,
            crossoverOperator: { parent1, parent2 in
                crossoverCalls += 1
                return [parent1, parent2]
            }
        )

        for _ in 0 ..< 10 {
            solver.step()
        }

        XCTAssertEqual(crossoverCalls, 0)
        XCTAssertEqual(solver.currentPopulation.map(\.id), [0, 1, 0, 1])
    }

    func testCrossoverRateOfOneCallsCrossoverForEveryPair() {
        var crossoverCalls = 0
        var solver = makeDeterministicSolver(
            populationSize: 6,
            crossoverRate: 1,
            crossoverOperator: { parent1, parent2 in
                crossoverCalls += 1
                return [parent1, parent2]
            }
        )

        for _ in 0 ..< 10 {
            solver.step()
        }

        XCTAssertEqual(crossoverCalls, 30, "3 pairs per generation for 10 generations")
    }
}
