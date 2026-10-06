//  StepReferenceTests.swift
//  genetic-solverTests
//
//  Compares step() with a plain reference implementation of the generation
//  it runs, operator calls and their order included, over many
//  configurations, so that changes made for speed can't change behaviour.

import XCTest
@testable import genetic_solver

// MARK: - CallLog

/// Records every operator and fitness call in the order they are made.
private final class CallLog {
    // MARK: Nested Types

    /// A call, with the ids of the individuals it received and returned.
    enum Call: Equatable {
        case fitness(Int)
        case select(Int, Int)
        case cross(Int, Int, children: [Int])
        case mutate(Int, mutant: Int)
        case replace(old: [Int], new: [Int])
    }

    // MARK: Properties

    var entries: [Call] = []
    var nextID = 0

    // MARK: Functions

    func newID() -> Int {
        defer { nextID += 1 }
        return nextID
    }
}

// MARK: - Logged

/// An individual whose fitness calls are recorded.
private struct Logged: GeneticElement {
    // MARK: Properties

    let id: Int
    let value: Int
    let log: CallLog

    // MARK: Functions

    func fitness() -> Int {
        log.entries.append(.fitness(id))
        return value
    }
}

// MARK: - Configuration

private struct Configuration: CustomStringConvertible {
    // MARK: Nested Types

    /// How many children crossover returns: a fixed number, or a random
    /// number from 0 to 3.
    enum Children {
        case fixed(Int)
        case random
    }

    /// What the replacement operator returns.
    enum Replacement {
        /// The new individuals.
        case generational
        /// The first `populationSize` of old and new together, fittest first.
        case keepFittest
        /// Only the first new individual, so the next population is smaller.
        case shrink
        /// The old and the new individuals, so the next population is larger.
        case grow
    }

    // MARK: Properties

    let populationSize: Int
    let eliteCount: Int
    let crossoverRate: Double
    let mutationRate: Double
    let children: Children
    let replacement: Replacement

    // MARK: Computed Properties

    var description: String {
        "populationSize \(populationSize), eliteCount \(eliteCount), crossoverRate \(crossoverRate), "
            + "mutationRate \(mutationRate), children \(children), replacement \(replacement)"
    }
}

// MARK: - World

/// The operators for one run, all drawing from one seeded generator, so the
/// order of their calls decides what they do, and recording every call.
private struct World {
    // MARK: Properties

    let log: CallLog
    let selection: SelectionOperator<Logged>
    let crossover: CrossoverOperator<Logged>
    let mutation: MutationOperator<Logged>
    let replacement: ReplacementOperator<Logged>
    let newElement: () -> Logged

    // MARK: Lifecycle

    init(_ configuration: Configuration, seed: UInt64) {
        let log = CallLog()
        self.log = log
        // A class, so that every operator draws from the same sequence.
        let random = SharedCountingGenerator(seed: seed)
        func make(value: Int) -> Logged {
            Logged(id: log.newID(), value: value, log: log)
        }
        selection = { population in
            var generator = random
            let first = population[Int.random(in: 0 ..< population.count, using: &generator)]
            let second = population[Int.random(in: 0 ..< population.count, using: &generator)]
            log.entries.append(.select(first.element.id, second.element.id))
            return (first, second)
        }
        crossover = { first, second in
            var generator = random
            let count = switch configuration.children {
                case let .fixed(count): count
                case .random: Int.random(in: 0 ... 3, using: &generator)
            }
            let children = (0 ..< count).map { _ in
                make(value: (first.value + second.value) / 2 + Int.random(in: -3 ... 3, using: &generator))
            }
            log.entries.append(.cross(first.id, second.id, children: children.map(\.id)))
            return children
        }
        mutation = { individual in
            var generator = random
            let mutant = make(value: individual.value + Int.random(in: -5 ... 5, using: &generator))
            log.entries.append(.mutate(individual.id, mutant: mutant.id))
            return mutant
        }
        replacement = { old, new in
            log.entries.append(.replace(old: old.map(\.element.id), new: new.map(\.element.id)))
            switch configuration.replacement {
                case .generational:
                    return new

                case .keepFittest:
                    let all = old + new
                    let order = all.indices.sorted { all[$0].fitness > all[$1].fitness || (all[$0].fitness == all[$1].fitness && $0 < $1) }
                    return order.prefix(configuration.populationSize).map { all[$0] }

                case .shrink:
                    return [new[0]]

                case .grow:
                    return old + new
            }
        }
        newElement = {
            var generator = random
            return make(value: Int.random(in: 0 ... 100, using: &generator))
        }
    }
}

// MARK: - Reference

/// A generation as `step()` runs it, written as plainly as possible:
/// carry over the fittest `eliteCount` individuals; select pairs and apply
/// crossover with probability `crossoverRate` (copying the parents when it
/// isn't applied or returns no children) until there are enough offspring;
/// drop the extra ones; decide for each offspring, in order, whether to
/// mutate it; evaluate each new or mutated individual, in order; and pass
/// the elite followed by the offspring to the replacement operator.
private func referenceGeneration(
    of population: [EvaluatedElement<Logged>],
    configuration: Configuration,
    world: World,
    generator: inout some RandomNumberGenerator
)
    -> [EvaluatedElement<Logged>]
{
    // Elitism: the fittest first; on a tie, the earlier one first.
    let ranked = population.indices.sorted {
        isFitter(population[$0].fitness, than: population[$1].fitness)
            || (!isFitter(population[$1].fitness, than: population[$0].fitness) && $0 < $1)
    }
    let elite = ranked.prefix(configuration.eliteCount).map { population[$0] }
    let offspringCount = configuration.populationSize - elite.count

    // Selection and crossover. A parent copied unchanged keeps its fitness.
    var offspring: [(element: Logged, evaluated: EvaluatedElement<Logged>?)] = []
    while offspring.count < offspringCount {
        let (parent1, parent2) = world.selection(population)
        let children = Double.random(in: 0 ..< 1, using: &generator) < configuration.crossoverRate
            ? world.crossover(parent1.element, parent2.element)
            : []
        if children.isEmpty {
            offspring.append((parent1.element, parent1))
            offspring.append((parent2.element, parent2))
        } else {
            for child in children {
                offspring.append((child, nil))
            }
        }
    }
    offspring = Array(offspring.prefix(offspringCount))

    // Mutation: all decisions in order, after all the crossovers.
    for index in offspring.indices {
        if Double.random(in: 0 ..< 1, using: &generator) < configuration.mutationRate {
            offspring[index] = (world.mutation(offspring[index].element), nil)
        }
    }

    // Evaluation, in order, of each individual that isn't an unchanged copy.
    let newIndividuals = elite + offspring.map { $0.evaluated ?? EvaluatedElement($0.element) }
    return world.replacement(population, newIndividuals)
}

// MARK: - StepReferenceTests

final class StepReferenceTests: XCTestCase {
    func testStepMatchesTheReferenceForManyConfigurations() {
        var compared = 0
        for configuration in configurations() {
            for seed in UInt64(0) ..< 2 {
                compare(configuration, seed: seed, generations: 4)
                compared += 1
            }
        }
        // Make sure the loops above didn't come out empty.
        XCTAssertGreaterThan(compared, 2500)
    }

    /// Larger populations with the usual rates, over more generations.
    func testStepMatchesTheReferenceForLongerRuns() {
        for populationSize in [20, 51] {
            for eliteCount in [0, 2] {
                let configuration = Configuration(
                    populationSize: populationSize,
                    eliteCount: eliteCount,
                    crossoverRate: 0.7,
                    mutationRate: 0.1,
                    children: .random,
                    replacement: .generational
                )
                compare(configuration, seed: 42, generations: 40)
            }
        }
    }

    // MARK: Helpers

    /// Every combination of the settings that matter to `step()`.
    private func configurations() -> [Configuration] {
        var result: [Configuration] = []
        for populationSize in [1, 2, 3, 7, 10] {
            for eliteCount in Set([0, 1, populationSize - 1]).sorted() where eliteCount < populationSize {
                // Never, always, and randomly, for crossover and mutation.
                let rates: [(crossover: Double, mutation: Double)] = [(0, 0), (0, 1), (1, 0), (1, 1), (0.5, 0.5)]
                for rate in rates {
                    let children: [Configuration.Children] = [.fixed(0), .fixed(1), .fixed(2), .fixed(3), .fixed(5), .random]
                    for children in children {
                        let replacements: [Configuration.Replacement] = [.generational, .keepFittest, .shrink, .grow]
                        for replacement in replacements {
                            result.append(Configuration(
                                populationSize: populationSize,
                                eliteCount: eliteCount,
                                crossoverRate: rate.crossover,
                                mutationRate: rate.mutation,
                                children: children,
                                replacement: replacement
                            ))
                        }
                    }
                }
            }
        }
        return result
    }

    /// Runs the solver and the reference side by side, each with its own
    /// operators built from the same seed, and compares the populations,
    /// the operator and fitness calls, and the solver's generator after
    /// every generation.
    private func compare(_ configuration: Configuration, seed: UInt64, generations: Int) {
        let solverWorld = World(configuration, seed: seed)
        let referenceWorld = World(configuration, seed: seed)

        var solver = GeneticSolver<Logged>(
            populationSize: configuration.populationSize,
            crossoverRate: configuration.crossoverRate,
            mutationRate: configuration.mutationRate,
            eliteCount: configuration.eliteCount,
            selectionOperator: solverWorld.selection,
            crossoverOperator: solverWorld.crossover,
            mutationOperator: solverWorld.mutation,
            replacementOperator: solverWorld.replacement,
            terminationCheck: { _, _ in false },
            newElement: solverWorld.newElement
        )
        solver.randomNumberGenerator = SeededRandomNumberGenerator(seed: seed &+ 1000)

        var population = (0 ..< configuration.populationSize).map { _ in EvaluatedElement(referenceWorld.newElement()) }
        var generator = SeededRandomNumberGenerator(seed: seed &+ 1000)
        XCTAssertEqual(solverWorld.log.entries, referenceWorld.log.entries, "\(configuration), seed \(seed): first population")

        for generation in 1 ... generations {
            // Only this generation's calls are compared, so that the cost
            // doesn't grow with the length of the log.
            let solverStart = solverWorld.log.entries.count
            let referenceStart = referenceWorld.log.entries.count
            solver.step()
            population = referenceGeneration(of: population, configuration: configuration, world: referenceWorld, generator: &generator)

            let solverCalls = Array(solverWorld.log.entries[solverStart...])
            let referenceCalls = Array(referenceWorld.log.entries[referenceStart...])
            var solverGenerator = solver.randomNumberGenerator
            var referenceGenerator = generator
            let solverNext = solverGenerator.next()
            let referenceNext = referenceGenerator.next()
            // Compared with == first, because the XCTest assertions are slow
            // for this many comparisons; they run only to report a difference.
            if
                solverCalls != referenceCalls
                || solver.currentPopulation.map(\.element.id) != population.map(\.element.id)
                || solver.currentPopulation.map(\.fitness) != population.map(\.fitness)
                || solverNext != referenceNext
            {
                let context = "\(configuration), seed \(seed), generation \(generation)"
                XCTAssertEqual(solverCalls, referenceCalls, context)
                XCTAssertEqual(solver.currentPopulation.map(\.element.id), population.map(\.element.id), context)
                XCTAssertEqual(solver.currentPopulation.map(\.fitness), population.map(\.fitness), context)
                XCTAssertEqual(solverNext, referenceNext, "\(context): the same number of decisions")
                // One configuration's difference is enough to read.
                return
            }
        }
    }
}
