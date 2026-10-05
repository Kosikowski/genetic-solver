//  ReadmeExamplesTests.swift
//  genetic-solverTests
//
//  Runs the code shown in README.md so the examples stay correct.
//  Keep the operators and solver setup below in sync with the README.

import XCTest
@testable import genetic_solver

// MARK: - MyIndividual

/// The individual from the README's Quick Start.
private struct MyIndividual: GeneticElement, FitnessEvaluatable {
    // MARK: Properties

    var genes: [Int]

    // MARK: Functions

    func fitness() -> Double {
        Double(genes.reduce(0, +))
    }
}

// MARK: - ExpensiveIndividual

/// The individual from the README's tip on expensive fitness.
private struct ExpensiveIndividual: GeneticElement, FitnessEvaluatable {
    // MARK: Properties

    let genes: [Int]

    private let storedFitness: Double

    // MARK: Lifecycle

    init(genes: [Int]) {
        self.genes = genes
        storedFitness = Double(genes.reduce(0, +)) // Replace with the expensive calculation
    }

    // MARK: Functions

    func fitness() -> Double {
        storedFitness
    }
}

// MARK: - ReadmeQuickStart

/// The operators and solver from the README's Quick Start, Option A.
private enum ReadmeQuickStart {
    // MARK: Static Properties

    static let geneRange = 0 ... 100
    static let geneCount = 10
    static let targetFitness = 950.0
    static let populationSize = 50
    static let maxGenerations = 200

    static let selection: SelectionOperator<MyIndividual> = { population in
        func selectOne() -> MyIndividual {
            let candidates = (0 ..< 3).map { _ -> (individual: MyIndividual, fitness: Double) in
                let candidate = population.randomElement()!
                return (candidate, candidate.fitness()) // Evaluate each candidate once
            }
            return candidates.max { $0.fitness < $1.fitness }!.individual
        }
        return (selectOne(), selectOne())
    }

    static let crossover: CrossoverOperator<MyIndividual> = { parent1, parent2 in
        let point = Int.random(in: 0 ..< parent1.genes.count)
        let child1 = MyIndividual(
            genes: Array(parent1.genes[..<point]) + Array(parent2.genes[point...])
        )
        let child2 = MyIndividual(
            genes: Array(parent2.genes[..<point]) + Array(parent1.genes[point...])
        )
        return [child1, child2]
    }

    static let mutation: MutationOperator<MyIndividual> = { individual in
        var mutant = individual
        let geneIndex = Int.random(in: 0 ..< mutant.genes.count)
        mutant.genes[geneIndex] = Int.random(in: 0 ... 100)
        return mutant
    }

    static let terminationCheck: TerminationCheck<MyIndividual> = { _, population in
        population.contains { $0.fitness() >= 950 }
    }

    // MARK: Static Functions

    static func newElement() -> MyIndividual {
        MyIndividual(genes: (0 ..< 10).map { _ in Int.random(in: 0 ... 100) })
    }

    static func makeSolver() -> GeneticSolver<MyIndividual> {
        GeneticSolver<MyIndividual>(
            populationSize: 50,
            crossoverRate: 0.8,
            mutationRate: 0.1,
            selectionOperator: selection,
            crossoverOperator: crossover,
            mutationOperator: mutation,
            replacementOperator: { _, new in new },
            terminationCheck: terminationCheck,
            newElement: { newElement() }
        )
    }
}

// MARK: - MyGeneticOperators

/// The operators type from the README's Quick Start, Option B.
private struct MyGeneticOperators: GeneticOperators {
    // MARK: Nested Types

    typealias Element = MyIndividual

    // MARK: Static Functions

    // selectionOperator, replacementOperator and fixedGenerationTermination
    // use the default implementations: tournament selection, generational
    // replacement, and stopping after a fixed number of generations.

    static func crossoverOperator(parent1: Element, parent2: Element) -> [Element] {
        let point = Int.random(in: 0 ..< parent1.genes.count)
        let child1 = MyIndividual(
            genes: Array(parent1.genes[..<point]) + Array(parent2.genes[point...])
        )
        let child2 = MyIndividual(
            genes: Array(parent2.genes[..<point]) + Array(parent1.genes[point...])
        )
        return [child1, child2]
    }

    static func mutationOperator(element: Element) -> Element {
        var mutant = element
        let geneIndex = Int.random(in: 0 ..< mutant.genes.count)
        mutant.genes[geneIndex] = Int.random(in: 0 ... 100)
        return mutant
    }

    static func newElement() -> Element {
        MyIndividual(genes: (0 ..< 10).map { _ in Int.random(in: 0 ... 100) })
    }
}

// MARK: - ReadmeRoulette

/// The selection operator from the README's Roulette Wheel Selection section.
private enum ReadmeRoulette {
    static let rouletteSelection: SelectionOperator<MyIndividual> = { population in
        let fitnesses = population.map { $0.fitness() } // Evaluate each individual once
        precondition(fitnesses.allSatisfy { $0 >= 0 && $0.isFinite }, "Roulette wheel selection needs finite, non-negative fitness")
        let totalFitness = fitnesses.reduce(0, +)

        func selectOne() -> MyIndividual {
            // With no positive fitness there is no wheel to spin.
            guard totalFitness > 0 else { return population.randomElement()! }

            let target = Double.random(in: 0 ..< totalFitness)
            var cumulative = 0.0
            for (individual, fitness) in zip(population, fitnesses) {
                cumulative += fitness
                if cumulative > target {
                    return individual
                }
            }
            // Not reached: the loop adds the same values in the same order as
            // totalFitness, so the final sum equals totalFitness > target.
            return population[population.count - 1]
        }

        return (selectOne(), selectOne())
    }
}

// MARK: - Custom Termination Conditions

/// `stallTermination(patience:)` from the README's Custom Termination
/// Conditions section.
private func stallTermination(patience: Int) -> TerminationCheck<MyIndividual> {
    var bestSoFar = -Double.infinity
    var generationsWithoutImprovement = 0
    return { generation, population in
        // A new run, for example after `reset()`, starts again at generation 0.
        if generation == 0 {
            bestSoFar = -Double.infinity
            generationsWithoutImprovement = 0
        }
        let currentBest = population.map { $0.fitness() }.max() ?? -Double.infinity
        if currentBest > bestSoFar {
            bestSoFar = currentBest
            generationsWithoutImprovement = 0
        } else {
            generationsWithoutImprovement += 1
        }
        return generationsWithoutImprovement >= patience
    }
}

/// A solver whose operators involve no randomness: selection picks the first
/// two individuals and nothing else changes them, so the best fitness never
/// improves after the starting population.
private func makeStallingSolver(terminationCheck: @escaping TerminationCheck<MyIndividual>) -> GeneticSolver<MyIndividual> {
    var nextValue = 0
    return GeneticSolver<MyIndividual>(
        populationSize: 4,
        selectionOperator: { ($0[0], $0[1]) },
        crossoverOperator: { [$0, $1] },
        mutationOperator: { $0 },
        replacementOperator: { _, new in new },
        terminationCheck: terminationCheck,
        newElement: {
            defer { nextValue = (nextValue + 1) % 4 }
            return MyIndividual(genes: [nextValue])
        }
    )
}

// MARK: - ReadmeExamplesTests

final class ReadmeExamplesTests: XCTestCase {
    // MARK: Quick Start

    /// The README once stopped on a condition every starting population met,
    /// so the solver returned before running a single generation.
    func testQuickStartTerminationIsNotMetByStartingPopulations() {
        let populationsMeetingTermination = (0 ..< 1000).filter { _ in
            let population = (0 ..< ReadmeQuickStart.populationSize).map { _ in ReadmeQuickStart.newElement() }
            return ReadmeQuickStart.terminationCheck(0, population)
        }.count
        XCTAssertEqual(populationsMeetingTermination, 0, "Starting populations should not already meet the termination check")
    }

    func testQuickStartRunsGenerationsAndReachesTarget() throws {
        var solver = ReadmeQuickStart.makeSolver()

        let finalPopulation = solver.solve(maxGenerations: ReadmeQuickStart.maxGenerations)
        let bestIndividual = try XCTUnwrap(finalPopulation.max { $0.fitness() < $1.fitness() })

        XCTAssertGreaterThan(solver.currentGeneration, 0, "The solver should run at least one generation")
        XCTAssertLessThanOrEqual(solver.currentGeneration, ReadmeQuickStart.maxGenerations)
        XCTAssertEqual(finalPopulation.count, ReadmeQuickStart.populationSize)
        XCTAssertGreaterThanOrEqual(bestIndividual.fitness(), ReadmeQuickStart.targetFitness)
    }

    func testQuickStartNewElementsHaveValidGenes() {
        for _ in 0 ..< 1000 {
            let element = ReadmeQuickStart.newElement()
            XCTAssertEqual(element.genes.count, ReadmeQuickStart.geneCount)
            XCTAssertTrue(element.genes.allSatisfy { ReadmeQuickStart.geneRange.contains($0) })
        }
    }

    // MARK: Quick Start operators

    func testQuickStartSelectionReturnsMembersOfThePopulation() {
        let population = (0 ..< 20).map { MyIndividual(genes: [$0]) }
        for _ in 0 ..< 1000 {
            let (first, second) = ReadmeQuickStart.selection(population)
            XCTAssertTrue(population.contains { $0.genes == first.genes })
            XCTAssertTrue(population.contains { $0.genes == second.genes })
        }
    }

    func testQuickStartSelectionWithSingleIndividualReturnsItTwice() {
        let (first, second) = ReadmeQuickStart.selection([MyIndividual(genes: [7])])
        XCTAssertEqual(first.genes, [7])
        XCTAssertEqual(second.genes, [7])
    }

    func testQuickStartCrossoverTakesEachGeneFromOneOfTheParents() {
        let parent1 = MyIndividual(genes: Array(0 ..< 10))
        let parent2 = MyIndividual(genes: Array(100 ..< 110))
        for _ in 0 ..< 1000 {
            let children = ReadmeQuickStart.crossover(parent1, parent2)
            XCTAssertEqual(children.count, 2)
            XCTAssertTrue(children.allSatisfy { $0.genes.count == parent1.genes.count })
            // The two children are complementary: at every position one holds
            // the gene from parent1 and the other the gene from parent2.
            for index in parent1.genes.indices {
                let pair = Set([children[0].genes[index], children[1].genes[index]])
                XCTAssertEqual(pair, Set([parent1.genes[index], parent2.genes[index]]))
            }
        }
    }

    func testQuickStartCrossoverWithSingleGeneSwapsTheParents() {
        // With one gene the only crossover point is 0, so each child is a copy
        // of the other parent.
        let children = ReadmeQuickStart.crossover(MyIndividual(genes: [1]), MyIndividual(genes: [2]))
        XCTAssertEqual(children.map(\.genes), [[2], [1]])
    }

    func testQuickStartMutationChangesAtMostOneGeneWithinRange() {
        let original = MyIndividual(genes: Array(repeating: 50, count: 10))
        for _ in 0 ..< 1000 {
            let mutant = ReadmeQuickStart.mutation(original)
            XCTAssertEqual(mutant.genes.count, original.genes.count)
            let changed = zip(mutant.genes, original.genes).filter { $0 != $1 }
            XCTAssertLessThanOrEqual(changed.count, 1)
            XCTAssertTrue(mutant.genes.allSatisfy { ReadmeQuickStart.geneRange.contains($0) })
        }
    }

    // MARK: Custom Termination Conditions

    func testStallTerminationStopsAfterPatienceGenerationsWithoutImprovement() {
        var solver = makeStallingSolver(terminationCheck: stallTermination(patience: 3))

        _ = solver.solve(maxGenerations: 100)

        XCTAssertEqual(solver.currentGeneration, 3)
        XCTAssertTrue(solver.isTerminated)
    }

    func testStallTerminationCountResetsWhenFitnessImproves() {
        let check = stallTermination(patience: 3)
        let bestFitnessPerGeneration = [5, 5, 6, 6, 6, 6]

        let results = bestFitnessPerGeneration.enumerated().map { generation, best in
            check(generation, [MyIndividual(genes: [best])])
        }

        // 5 (first), 5 (1 without improvement), 6 (improved), then 1, 2, 3.
        XCTAssertEqual(results, [false, false, false, false, false, true])
    }

    func testStallTerminationWithZeroPatienceStopsImmediately() {
        let solver = makeStallingSolver(terminationCheck: stallTermination(patience: 0))

        XCTAssertTrue(solver.isTerminated)
        XCTAssertEqual(solver.currentGeneration, 0)
    }

    func testStallTerminationStartsOverAfterReset() {
        var solver = makeStallingSolver(terminationCheck: stallTermination(patience: 3))
        _ = solver.solve(maxGenerations: 100)
        XCTAssertTrue(solver.isTerminated)

        // The new population is no better than the old one, so without the
        // generation-0 reset in the check the count would carry over and the
        // solver would stay terminated.
        solver.reset()
        XCTAssertFalse(solver.isTerminated)

        _ = solver.solve(maxGenerations: 100)
        XCTAssertEqual(solver.currentGeneration, 3)
    }

    func testStallTerminationAssignedMidRunStartsCountingFromThatGeneration() {
        var solver = makeStallingSolver(terminationCheck: { _, _ in false })
        _ = solver.solve(maxGenerations: 5)

        solver.terminationCheck = stallTermination(patience: 3)
        _ = solver.solve(maxGenerations: 100)

        XCTAssertEqual(solver.currentGeneration, 8)
    }

    // MARK: Expensive fitness tip

    func testExpensiveIndividualReturnsTheFitnessComputedAtCreation() {
        XCTAssertEqual(ExpensiveIndividual(genes: [1, 2, 3]).fitness(), 6)
        XCTAssertEqual(ExpensiveIndividual(genes: []).fitness(), 0)
    }

    func testExpensiveIndividualWorksWithTheSolver() {
        // A crossover rate of 1 applies crossover to every pair, so every
        // child combines two individuals and the result doesn't depend on
        // random numbers.
        var solver = GeneticSolver<ExpensiveIndividual>(
            populationSize: 4,
            crossoverRate: 1,
            selectionOperator: { ($0[0], $0[1]) },
            crossoverOperator: { [ExpensiveIndividual(genes: $0.genes + $1.genes)] },
            mutationOperator: { $0 },
            replacementOperator: { _, new in new },
            terminationCheck: { _, _ in false },
            newElement: { ExpensiveIndividual(genes: [1]) }
        )

        _ = solver.solve(maxGenerations: 1)

        XCTAssertEqual(solver.currentPopulation.map { $0.fitness() }, [2, 2, 2, 2])
    }

    // MARK: Quick Start, Option B

    /// Option B used to return the best candidate as both parents, so
    /// crossover could only produce copies. It now uses the default
    /// tournament selection, which picks each parent separately.
    func testOptionBUsesTheDefaultSelectionWithIndependentParents() {
        // Two different individuals with the same fitness.
        let population = [MyIndividual(genes: [0, 5]), MyIndividual(genes: [5, 0])]

        let differentPairs = (0 ..< 1000).filter { _ in
            let (first, second) = MyGeneticOperators.selectionOperator(population: population)
            return first.genes != second.genes
        }.count

        XCTAssertGreaterThan(differentPairs, 0)
    }

    func testOptionBReachesHighFitnessWithin100Generations() throws {
        var solver = GeneticSolver(
            populationSize: 50,
            crossoverRate: 0.8,
            mutationRate: 0.1,
            operators: MyGeneticOperators.self,
            terminationCheck: MyGeneticOperators.fixedGenerationTermination(maxGenerations: 100)
        )

        let bestIndividual = try XCTUnwrap(solver.solve().max { $0.fitness() < $1.fitness() })

        // Across 2,000 runs the best fitness after 100 generations was never
        // below 952 (out of 1000).
        XCTAssertGreaterThanOrEqual(bestIndividual.fitness(), 940)
    }

    func testOptionBSolverRunsUntilFixedGenerationTermination() {
        var solver = GeneticSolver(
            populationSize: 50,
            crossoverRate: 0.8,
            mutationRate: 0.1,
            operators: MyGeneticOperators.self,
            terminationCheck: MyGeneticOperators.fixedGenerationTermination(maxGenerations: 100)
        )

        let finalPopulation = solver.solve()

        XCTAssertEqual(solver.currentGeneration, 100)
        XCTAssertTrue(solver.isTerminated)
        XCTAssertEqual(finalPopulation.count, 50)
        XCTAssertTrue(finalPopulation.allSatisfy { $0.genes.count == 10 && $0.genes.allSatisfy { (0 ... 100).contains($0) } })
    }

    // MARK: Roulette Wheel Selection

    /// The README version crashed here: with a total fitness of 0,
    /// `Double.random(in: 0 ..< 0)` traps.
    func testRouletteWithAllZeroFitnessPicksAtRandom() {
        let population = [MyIndividual(genes: [0]), MyIndividual(genes: [0, 0]), MyIndividual(genes: [0, 0, 0])]

        var pickedGeneCounts = Set<Int>()
        for _ in 0 ..< 1000 {
            let (first, second) = ReadmeRoulette.rouletteSelection(population)
            pickedGeneCounts.insert(first.genes.count)
            pickedGeneCounts.insert(second.genes.count)
        }

        XCTAssertEqual(pickedGeneCounts, [1, 2, 3], "Every individual should be picked at some point")
    }

    func testRouletteNeverPicksZeroFitnessWhenAnotherIndividualIsPositive() {
        let population = [MyIndividual(genes: [0]), MyIndividual(genes: [5]), MyIndividual(genes: [0, 0])]

        for _ in 0 ..< 1000 {
            let (first, second) = ReadmeRoulette.rouletteSelection(population)
            XCTAssertEqual(first.genes, [5])
            XCTAssertEqual(second.genes, [5])
        }
    }

    func testRoulettePicksInProportionToFitness() {
        let population = [MyIndividual(genes: [1]), MyIndividual(genes: [3])]
        let picks = 10000

        var strongPicks = 0
        for _ in 0 ..< picks / 2 {
            let (first, second) = ReadmeRoulette.rouletteSelection(population)
            strongPicks += [first, second].filter { $0.genes == [3] }.count
        }

        // Expected share 0.75 with a standard deviation of about 0.0043, so
        // this range is about 7 standard deviations wide on each side.
        let strongShare = Double(strongPicks) / Double(picks)
        XCTAssertGreaterThan(strongShare, 0.72)
        XCTAssertLessThan(strongShare, 0.78)
    }

    func testRouletteWithSingleIndividualReturnsItTwice() {
        let (first, second) = ReadmeRoulette.rouletteSelection([MyIndividual(genes: [4])])

        XCTAssertEqual(first.genes, [4])
        XCTAssertEqual(second.genes, [4])
    }

    /// The case from the review: a population where every individual has
    /// fitness 0, like a knapsack population where every selection is
    /// overweight, must not crash the solver.
    func testRouletteRunsInTheSolverWithAZeroFitnessStartingPopulation() {
        var solver = GeneticSolver<MyIndividual>(
            populationSize: 20,
            crossoverRate: 0.8,
            mutationRate: 0.5,
            selectionOperator: ReadmeRoulette.rouletteSelection,
            crossoverOperator: ReadmeQuickStart.crossover,
            mutationOperator: ReadmeQuickStart.mutation,
            replacementOperator: { _, new in new },
            terminationCheck: { _, _ in false },
            newElement: { MyIndividual(genes: Array(repeating: 0, count: 10)) }
        )

        _ = solver.solve(maxGenerations: 20)

        XCTAssertEqual(solver.currentGeneration, 20)
        XCTAssertEqual(solver.currentPopulation.count, 20)
    }
}
