//  main.swift
//  Swift6Client
//
//  A client of this package in the Swift 6 language mode, built and run by
//  scripts/test-swift6-client.sh. The package and its tests use the Swift 5
//  language mode, which doesn't enforce Sendable, so problems that only
//  Swift 6 clients see would otherwise go unnoticed: for example a public
//  value type that isn't Sendable can't be kept in a static property.

import genetic_solver

// MARK: - Individual

struct Individual: GeneticElement, Sendable {
    // MARK: Properties

    let genes: [Int]

    // MARK: Functions

    func fitness() -> Int {
        genes.reduce(0, +)
    }
}

// MARK: - Operators

enum Operators: GeneticOperators {
    static func newElement() -> Individual {
        Individual(genes: (0 ..< 8).map { _ in Int.random(in: 0 ... 9) })
    }

    static func mutationOperator(element: Individual) -> Individual {
        var genes = element.genes
        genes[Int.random(in: 0 ..< genes.count)] = Int.random(in: 0 ... 9)
        return Individual(genes: genes)
    }
}

// MARK: - Shared

/// Public value types must be Sendable to be kept in global or static
/// properties, or sent to other tasks, in the Swift 6 language mode.
enum Shared {
    static let generator = SeededRandomNumberGenerator(seed: 1)
    static let evaluated = EvaluatedElement(Individual(genes: [9, 9]))
}

let globalGenerator = SeededRandomNumberGenerator(seed: 2)

func requireSendable(_: (some Sendable).Type) {}

requireSendable(SeededRandomNumberGenerator.self)
requireSendable(EvaluatedElement<Individual>.self)

// MARK: - Optimizer

/// Runs a solver inside an actor, as a Swift 6 app might.
actor Optimizer {
    // MARK: Properties

    private var solver: GeneticSolver<Individual>

    // MARK: Lifecycle

    init(seed: UInt64) {
        var solver = GeneticSolver(
            populationSize: 20,
            crossoverRate: 0.8,
            mutationRate: 0.3,
            eliteCount: 1,
            operators: Operators.self,
            terminationCheck: { _, population in population.contains { $0.fitness >= 70 } }
        )
        solver.selectionOperator = GeneticSolver.tournamentSelection(using: SeededRandomNumberGenerator(seed: seed))
        solver.randomNumberGenerator = SeededRandomNumberGenerator(seed: seed &+ 1)
        self.solver = solver
    }

    // MARK: Functions

    func run(maxGenerations: Int) -> (generation: Int, bestFitness: Int) {
        solver.solve(maxGenerations: maxGenerations)
        solver.checkTermination()
        return (solver.currentGeneration, solver.bestElement.fitness)
    }
}

// MARK: - Run

let startingBest = Operators.newElement().fitness()
let result = await Optimizer(seed: 3).run(maxGenerations: 200)
precondition(result.generation > 0, "The solver should run at least one generation")
precondition(result.bestFitness >= 0, "Fitness is a sum of genes from 0 to 9")

var sent = Shared.generator
let fromTask = await Task.detached { [globalGenerator] in
    var copy = globalGenerator
    return copy.next()
}.value
var local = globalGenerator
precondition(fromTask == local.next(), "A generator sent to a task continues the same sequence")
precondition(Shared.evaluated.fitness == 18, "An evaluated individual keeps its fitness")
_ = sent.next()

print("Swift 6 client: generation \(result.generation), best fitness \(result.bestFitness) (a random individual: \(startingBest))")
