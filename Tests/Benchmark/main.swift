//  main.swift
//  Benchmark
//
//  Measures how long the solver takes to run, built in release mode and run
//  by scripts/benchmark.sh. It is a separate package that depends on this
//  one, because that is how clients use the library: its generic code runs
//  in the client's module, with the client's types.
//
//  Each scenario runs the same seeded configuration several times and prints
//  the best and median times and the best fitness found. The fitness must be
//  the same in every run; otherwise the program stops with an error. Compare
//  it before and after a change to see that the change kept the results.

import Foundation
import genetic_solver

// MARK: - Settings

/// The configuration every scenario uses, apart from its individuals and
/// their crossover and mutation.
enum Settings {
    static let populationSize = 1000
    static let generations = 300
    static let crossoverRate = 0.7
    static let mutationRate = 0.05
    static let eliteCount = 2
    static let tournamentSize = 3
}

// MARK: - OneMax

/// 64 bits, and the fitness is the number of bits set. Its operators do very
/// little, so the solver's own work dominates.
struct OneMax: GeneticElement {
    // MARK: Properties

    let bits: UInt64

    // MARK: Functions

    func fitness() -> Int {
        bits.nonzeroBitCount
    }
}

// MARK: - Genome

/// 32 genes in an array, so each individual has heap storage, as many real
/// genomes do. The fitness is highest, 0, when every gene is 0.
struct Genome: GeneticElement {
    // MARK: Properties

    var genes: [Double]

    // MARK: Functions

    func fitness() -> Double {
        -genes.reduce(0) { $0 + $1 * $1 }
    }
}

// MARK: - Vectors

/// Two vectors of 16 `Double`s stored inline: 256 bytes, so every copy of an
/// individual is expensive. The fitness is highest, 0, at the origin.
struct Vectors: GeneticElement {
    // MARK: Properties

    var first: SIMD16<Double>
    var second: SIMD16<Double>

    // MARK: Functions

    func fitness() -> Double {
        -((first * first).sum() + (second * second).sum())
    }
}

// MARK: - Scenarios

/// Returns a solver with the shared settings and seeded generators.
func makeSolver<Element: GeneticElement>(
    crossoverOperator: @escaping CrossoverOperator<Element>,
    mutationOperator: @escaping MutationOperator<Element>,
    newElement: @escaping () -> Element
)
    -> GeneticSolver<Element>
{
    var solver = GeneticSolver<Element>(
        populationSize: Settings.populationSize,
        crossoverRate: Settings.crossoverRate,
        mutationRate: Settings.mutationRate,
        eliteCount: Settings.eliteCount,
        selectionOperator: GeneticSolver.tournamentSelection(
            tournamentSize: Settings.tournamentSize,
            using: SeededRandomNumberGenerator(seed: 1)
        ),
        crossoverOperator: crossoverOperator,
        mutationOperator: mutationOperator,
        replacementOperator: { _, new in new },
        terminationCheck: { _, _ in false },
        newElement: newElement
    )
    solver.randomNumberGenerator = SeededRandomNumberGenerator(seed: 2)
    return solver
}

/// Runs OneMax and returns the best fitness found.
func runOneMax() -> String {
    // One generator for the individuals and the operators, as a closure-based
    // client would typically write it.
    var generator = SeededRandomNumberGenerator(seed: 3)
    var solver = makeSolver(
        crossoverOperator: { (first: OneMax, second: OneMax) in
            // Uniform crossover: each bit comes from either parent.
            let mask = UInt64.random(in: 0 ... .max, using: &generator)
            return [
                OneMax(bits: (first.bits & mask) | (second.bits & ~mask)),
                OneMax(bits: (second.bits & mask) | (first.bits & ~mask)),
            ]
        },
        mutationOperator: { individual in
            OneMax(bits: individual.bits ^ (1 << UInt64.random(in: 0 ..< 64, using: &generator)))
        },
        newElement: { OneMax(bits: UInt64.random(in: 0 ... .max, using: &generator)) }
    )
    solver.solve(maxGenerations: Settings.generations)
    return "\(solver.bestElement.fitness)"
}

/// Runs the array genome and returns the best fitness found.
func runGenome() -> String {
    var generator = SeededRandomNumberGenerator(seed: 3)
    var solver = makeSolver(
        crossoverOperator: { (first: Genome, second: Genome) in
            // One-point crossover.
            let cut = Int.random(in: 1 ..< first.genes.count, using: &generator)
            return [
                Genome(genes: Array(first.genes[..<cut] + second.genes[cut...])),
                Genome(genes: Array(second.genes[..<cut] + first.genes[cut...])),
            ]
        },
        mutationOperator: { individual in
            var individual = individual
            let index = Int.random(in: 0 ..< individual.genes.count, using: &generator)
            individual.genes[index] += Double.random(in: -0.5 ... 0.5, using: &generator)
            return individual
        },
        newElement: {
            Genome(genes: (0 ..< 32).map { _ in Double.random(in: -10 ... 10, using: &generator) })
        }
    )
    solver.solve(maxGenerations: Settings.generations)
    return "\(solver.bestElement.fitness)"
}

/// Runs the inline vectors and returns the best fitness found.
func runVectors() -> String {
    var generator = SeededRandomNumberGenerator(seed: 3)
    func randomVector() -> SIMD16<Double> {
        var vector = SIMD16<Double>()
        for index in vector.indices {
            vector[index] = Double.random(in: -10 ... 10, using: &generator)
        }
        return vector
    }
    var solver = makeSolver(
        crossoverOperator: { (first: Vectors, second: Vectors) in
            [
                Vectors(first: first.first, second: second.second),
                Vectors(first: second.first, second: first.second),
            ]
        },
        mutationOperator: { individual in
            var individual = individual
            let index = Int.random(in: 0 ..< 16, using: &generator)
            individual.first[index] += Double.random(in: -0.5 ... 0.5, using: &generator)
            return individual
        },
        newElement: { Vectors(first: randomVector(), second: randomVector()) }
    )
    solver.solve(maxGenerations: Settings.generations)
    return "\(solver.bestElement.fitness)"
}

// MARK: - Measuring

/// Prints `message` to standard error, after everything printed so far.
/// `stdout` and `stderr` are mutable globals in Glibc, which the Swift 6
/// language mode rejects, so this uses `FileHandle` and `fflush(nil)`, which
/// flushes every output stream.
func printError(_ message: String) {
    fflush(nil)
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

/// Runs `run` `repetitions` times and prints the best and median times and
/// the result. Stops the program if the runs don't all give the same result.
func measure(_ name: String, repetitions: Int, _ run: () -> String) {
    let clock = ContinuousClock()
    var milliseconds: [Double] = []
    var results: Set<String> = []
    for _ in 0 ..< repetitions {
        let start = clock.now
        results.insert(run())
        let elapsed = start.duration(to: clock.now).components
        milliseconds.append(Double(elapsed.seconds) * 1e3 + Double(elapsed.attoseconds) / 1e15)
    }
    guard results.count == 1, let result = results.first else {
        printError("error: \(name) gave different results in runs with the same seeds: \(results.sorted())")
        exit(1)
    }
    milliseconds.sort()
    let best = String(format: "%.1f", milliseconds[0])
    let median = String(format: "%.1f", milliseconds[milliseconds.count / 2])
    print("\(name.padding(toLength: 28, withPad: " ", startingAt: 0)) \(best) ms (median \(median) ms), best fitness \(result)")
}

let arguments = CommandLine.arguments.dropFirst()
guard arguments.count <= 1, let repetitions = Int(arguments.first ?? "5"), repetitions >= 1 else {
    printError("Usage: Benchmark [repetitions]\n  repetitions  How often to run each scenario (a positive integer, default 5)")
    exit(2)
}

print("""
\(Settings.populationSize) individuals, \(Settings.generations) generations, eliteCount \(Settings.eliteCount), \
tournaments of \(Settings.tournamentSize); \(repetitions == 1 ? "1 run" : "best of \(repetitions) runs")
""")
measure("OneMax (64 bits)", repetitions: repetitions, runOneMax)
measure("Genome (32 Doubles, array)", repetitions: repetitions, runGenome)
measure("Vectors (32 Doubles, inline)", repetitions: repetitions, runVectors)
