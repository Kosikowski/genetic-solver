//  GeneticSolver.swift
//  genetic-solver
//
//  Created by Mateusz Kosikowski on 05/02/2024.
//

// MARK: - GeneticSolver

// The code that runs for every generation or individual (`step()`,
// `solve(maxGenerations:)`, `bestElement`, elitism, tournaments, ranking,
// the default operators) is `@inlinable`, so that the compiler specializes
// it for the client's element type in the client's module. Unspecialized
// generic code copies and compares individuals through runtime type
// information, which made the solver several times slower
// (`scripts/benchmark.sh` measures it). Inlinable code can only use public
// and `@usableFromInline` declarations, so the state it changes is kept in
// `@usableFromInline` properties behind read-only public ones.

/// Genetic Solver: highly generic, extensible genetic algorithm framework
public struct GeneticSolver<Element: GeneticElement> {
    // MARK: Properties

    // Parameters, checked by `init` and whenever they are set: a value out of
    // range stops the program right there, with a message

    /// The number of individuals in each generation. Must be at least 1, and
    /// greater than `eliteCount`.
    public var populationSize: Int {
        didSet {
            Self.stop(ifInvalid: Self.invalidPopulationSizeMessage(populationSize)
                ?? Self.invalidPopulationSizeMessage(populationSize, eliteCount: eliteCount))
        }
    }

    /// The probability, from 0 to 1, that `crossoverOperator` is applied to a
    /// selected pair of parents.
    public var crossoverRate: Double {
        didSet { Self.stop(ifInvalid: Self.invalidRateMessage("crossoverRate", crossoverRate)) }
    }

    /// The probability, from 0 to 1, that `mutationOperator` is applied to
    /// each individual of the next generation.
    public var mutationRate: Double {
        didSet { Self.stop(ifInvalid: Self.invalidRateMessage("mutationRate", mutationRate)) }
    }

    /// How many of the fittest individuals each generation carries into the
    /// next one unchanged: not selected, crossed over or mutated, and not
    /// evaluated again. The rest of the next generation,
    /// `populationSize - eliteCount` individuals, are offspring.
    ///
    /// With an `eliteCount` of at least 1, the best fitness never gets worse
    /// and `bestElement` is the best individual found so far. It must be at
    /// least 0 and less than `populationSize`, so that every generation has
    /// at least one new individual; the default is 0.
    ///
    /// The elite come first among the new individuals that
    /// `replacementOperator` receives, followed by the offspring.
    public var eliteCount: Int {
        didSet { Self.stop(ifInvalid: Self.invalidEliteCountMessage(eliteCount, populationSize: populationSize)) }
    }

    // Operators, which can be replaced at any time

    /// Picks two parents from the current population.
    public var selectionOperator: SelectionOperator<Element>

    /// Combines two selected parents into children. It is applied to each
    /// selected pair with probability `crossoverRate`; otherwise, or when it
    /// returns no children, the parents are copied into the next generation
    /// unchanged. Children beyond `populationSize` are dropped.
    public var crossoverOperator: CrossoverOperator<Element>

    /// Changes an individual. It is applied to each individual of the next
    /// generation with probability `mutationRate`.
    public var mutationOperator: MutationOperator<Element>

    /// Builds the next population from the current population and the new
    /// individuals. It must return at least one individual.
    public var replacementOperator: ReplacementOperator<Element>

    /// Creates a new individual. Used to fill the population in `init` and
    /// `reset()`.
    public var newElement: () -> Element

    /// The random number generator for the solver's own random decisions:
    /// whether `crossoverOperator` is applied to a pair of parents, and whether
    /// `mutationOperator` is applied to an individual. It starts as
    /// `SystemRandomNumberGenerator`.
    ///
    /// To make runs reproducible, set it to a `SeededRandomNumberGenerator` and
    /// give your operators seeded generators too.
    ///
    /// Copying the solver copies this property. For a value type such as
    /// `SeededRandomNumberGenerator`, that copies its state, so the copy makes
    /// the same crossover and mutation decisions as the original. Copies of
    /// `SystemRandomNumberGenerator` decide independently, and a generator
    /// that is a class is shared by the copies. Generators captured by the
    /// operators, such as the one in `tournamentSelection(tournamentSize:using:)`,
    /// are shared too, so copies of a solver pick different parents.
    public var randomNumberGenerator: any RandomNumberGenerator = SystemRandomNumberGenerator()

    /// Decides whether the run is finished, given the generation count and
    /// the population.
    ///
    /// The solver calls it exactly once for each population: the one created
    /// by `init` or `reset()`, and the one produced by each generation. The
    /// result is kept in `isTerminated`, so a check that keeps its own state
    /// (for example, counting generations without improvement) sees every
    /// generation once. Assigning a new check calls it once for the current
    /// population, and so does `checkTermination()`.
    ///
    /// So a check can still be called again for a generation it has seen:
    /// when a new check wraps the current one (to log it, or to add a
    /// condition), assigning the wrapper calls the wrapped check again for
    /// the current population. A check that keeps state should give the same
    /// answer when called again for the same generation, for example by
    /// remembering generation numbers rather than counting calls.
    ///
    /// The check runs after each generation, not before the next one, so a
    /// check that reads something outside the solver, such as a cancel flag
    /// or a deadline, sees a change after the next generation. Call
    /// `checkTermination()` to apply such a change right away.
    public var terminationCheck: TerminationCheck<Element> {
        didSet {
            checkTermination()
        }
    }

    // State, read through `currentPopulation`, `currentGeneration` and
    // `isTerminated`, and changed only by the solver

    @usableFromInline var storedPopulation: [EvaluatedElement<Element>]

    @usableFromInline var storedGeneration: Int

    @usableFromInline var storedIsTerminated: Bool

    // MARK: Computed Properties

    /// The current population: each individual with its fitness, evaluated
    /// once when the individual was created.
    @inlinable public var currentPopulation: [EvaluatedElement<Element>] {
        storedPopulation
    }

    /// The current generation count.
    @inlinable public var currentGeneration: Int {
        storedGeneration
    }

    /// The result of the latest call to `terminationCheck`, which is made for
    /// each new population, when the check is replaced, and by
    /// `checkTermination()`. Once it is `true`, `step()` and
    /// `solve(maxGenerations:)` run no more generations until a later call
    /// returns `false`: after `reset()`, after replacing the check, or after
    /// `checkTermination()` once the state the check depends on has changed.
    @inlinable public var isTerminated: Bool {
        storedIsTerminated
    }

    /// The fittest individual in the current population, with its fitness;
    /// on a tie, the first one. It compares the fitness values the solver
    /// already has, without calling `fitness()`. A fitness that isn't equal
    /// to itself, such as NaN, ranks below every other fitness.
    ///
    /// The default replacement operator replaces the whole population, so the
    /// best individual found so far can be lost. With an `eliteCount` of at
    /// least 1, this is always the best individual found so far.
    @inlinable public var bestElement: EvaluatedElement<Element> {
        // The population is never empty: `populationSize` is at least 1 and
        // `step()` stops if a replacement operator returns no individuals.
        currentPopulation.max { isFitter($1.fitness, than: $0.fitness) }!
    }

    // MARK: Lifecycle

    /// Initialize the genetic solver with the specified parameters and operators.
    ///
    /// The first population is created right away by calling `newElement`
    /// `populationSize` times and evaluating each new individual's fitness
    /// once, and `terminationCheck` is called once for it.
    ///
    /// - Precondition: `populationSize` is at least 1, `crossoverRate` and
    ///   `mutationRate` are between 0 and 1, and `eliteCount` is at least 0
    ///   and less than `populationSize`.
    public init(
        populationSize: Int,
        crossoverRate: Double = 0.7,
        mutationRate: Double = 0.01,
        eliteCount: Int = 0,
        selectionOperator: @escaping SelectionOperator<Element>,
        crossoverOperator: @escaping CrossoverOperator<Element>,
        mutationOperator: @escaping MutationOperator<Element>,
        replacementOperator: @escaping ReplacementOperator<Element>,
        terminationCheck: @escaping TerminationCheck<Element>,
        newElement: @escaping () -> Element
    ) {
        self.populationSize = populationSize
        self.crossoverRate = crossoverRate
        self.mutationRate = mutationRate
        self.eliteCount = eliteCount
        self.selectionOperator = selectionOperator
        self.crossoverOperator = crossoverOperator
        self.mutationOperator = mutationOperator
        self.replacementOperator = replacementOperator
        self.terminationCheck = terminationCheck
        self.newElement = newElement

        // Property observers don't run in `init`, so check the parameters here.
        Self.stop(ifInvalid: Self.invalidParameterMessage(
            populationSize: populationSize,
            crossoverRate: crossoverRate,
            mutationRate: mutationRate,
            eliteCount: eliteCount
        ))

        let initialPopulation = (0 ..< populationSize).map { _ in EvaluatedElement(newElement()) }
        storedPopulation = initialPopulation
        storedGeneration = 0
        storedIsTerminated = terminationCheck(0, initialPopulation)
    }

    // MARK: Static Functions

    /// Returns a description of the first parameter that is out of range, or
    /// `nil` when `populationSize` is at least 1, both rates are between 0
    /// and 1, and `eliteCount` is at least 0 and less than `populationSize`.
    /// NaN and infinite rates are out of range.
    static func invalidParameterMessage(
        populationSize: Int,
        crossoverRate: Double,
        mutationRate: Double,
        eliteCount: Int = 0
    )
        -> String?
    {
        invalidPopulationSizeMessage(populationSize)
            ?? invalidRateMessage("crossoverRate", crossoverRate)
            ?? invalidRateMessage("mutationRate", mutationRate)
            ?? invalidEliteCountMessage(eliteCount, populationSize: populationSize)
    }

    /// Returns why `eliteCount` is out of range, or `nil` when it is at least
    /// 0 and less than `populationSize`.
    static func invalidEliteCountMessage(_ eliteCount: Int, populationSize: Int) -> String? {
        (0 ..< populationSize).contains(eliteCount)
            ? nil
            : "eliteCount must be at least 0 and less than populationSize (\(populationSize)), but is \(eliteCount)"
    }

    /// Returns why `populationSize` is too small for `eliteCount`, or `nil`
    /// when it is greater.
    static func invalidPopulationSizeMessage(_ populationSize: Int, eliteCount: Int) -> String? {
        populationSize > eliteCount
            ? nil
            : "populationSize must be greater than eliteCount (\(eliteCount)), but is \(populationSize)"
    }

    /// Returns why `populationSize` is out of range, or `nil` when it is at
    /// least 1.
    static func invalidPopulationSizeMessage(_ populationSize: Int) -> String? {
        populationSize < 1 ? "populationSize must be at least 1, but is \(populationSize)" : nil
    }

    /// Returns why the rate called `name` is out of range, or `nil` when it is
    /// between 0 and 1. NaN and infinite rates are out of range.
    static func invalidRateMessage(_ name: String, _ rate: Double) -> String? {
        (0 ... 1).contains(rate) ? nil : "\(name) must be between 0 and 1, but is \(rate)"
    }

    /// Stops the program with `message`, if there is one. `fatalError` is
    /// used rather than `preconditionFailure` because it prints the message
    /// in optimized builds too.
    private static func stop(ifInvalid message: String?) {
        if let message {
            fatalError(message)
        }
    }

    // MARK: Functions

    /// Run generations until the termination check passes or `currentGeneration`
    /// reaches `maxGenerations`, then return the current population.
    ///
    /// The run continues from the current state: the population created by
    /// `init`, or wherever earlier calls to `step()` or `solve(maxGenerations:)`
    /// left off. `maxGenerations` limits the total generation count, not the
    /// number of generations run by this call. Call `reset()` to start over.
    ///
    /// The result is the same as `currentPopulation`, so it can be ignored, for
    /// example when only `bestElement` is needed.
    @inlinable @discardableResult
    public mutating func solve(maxGenerations: Int = 1000) -> [EvaluatedElement<Element>] {
        while currentGeneration < maxGenerations, !isTerminated {
            step()
        }
        return currentPopulation
    }

    /// Replace the population with `populationSize` new elements from
    /// `newElement`, each evaluated once, set `currentGeneration` back to 0,
    /// and call `terminationCheck` once for the new population.
    public mutating func reset() {
        storedPopulation = (0 ..< populationSize).map { _ in EvaluatedElement(newElement()) }
        storedGeneration = 0
        checkTermination()
    }

    /// Call `terminationCheck` once for the current population, store the
    /// result in `isTerminated`, and return it.
    ///
    /// The solver calls the check after each generation, not before the next
    /// one. Use this when a check depends on something outside the solver
    /// that has changed since: for example, after setting a cancel flag, so
    /// that the next `step()` runs nothing, or after extending a deadline
    /// that stopped the run, so that `solve(maxGenerations:)` continues.
    @inlinable @discardableResult
    public mutating func checkTermination() -> Bool {
        storedIsTerminated = terminationCheck(currentGeneration, currentPopulation)
        return storedIsTerminated
    }

    /// Advance the algorithm by one generation and return `isTerminated`.
    ///
    /// If the solver has already terminated, this does nothing and returns
    /// `true`. Otherwise it runs one generation, calls `terminationCheck`
    /// once for the new population, and returns the result. It doesn't call
    /// the check before running the generation; see `checkTermination()`.
    ///
    /// With an `eliteCount` above 0, the fittest individuals are carried
    /// over unchanged and only `populationSize - eliteCount` offspring are
    /// created. Each new individual has its fitness evaluated once, after
    /// mutation. A parent that is copied unchanged (crossover skipped or
    /// returning no children, and no mutation) keeps the fitness it already
    /// has.
    @inlinable @discardableResult
    public mutating func step() -> Bool {
        guard !isTerminated else { return true }
        // A generator of a concrete type, so that the standard library's random
        // functions are specialized for it (see `AnyRandomNumberGenerator`).
        var generator = AnyRandomNumberGenerator(randomNumberGenerator)
        defer { randomNumberGenerator = generator.base }
        // Elitism
        let elite = Self.fittest(eliteCount, of: currentPopulation)
        let offspringCount = populationSize - elite.count
        // Selection & Crossover
        var offspring: [Offspring] = []
        while offspring.count < offspringCount {
            let (parent1, parent2) = selectionOperator(currentPopulation)
            let children = Double.random(in: 0 ..< 1, using: &generator) < crossoverRate
                ? crossoverOperator(parent1.element, parent2.element)
                : []
            // Copy the parents when crossover is skipped or returns no children,
            // so every pass adds at least one element and the loop always ends.
            if children.isEmpty {
                offspring += [.copy(parent1), .copy(parent2)]
            } else {
                offspring += children.map { .new($0) }
            }
        }
        offspring = Array(offspring.prefix(offspringCount))
        // Mutation
        let mutated: [Offspring] = offspring.map { candidate in
            Double.random(in: 0 ..< 1, using: &generator) < mutationRate
                ? .new(mutationOperator(candidate.element))
                : candidate
        }
        // Evaluation: once for each individual that isn't an unchanged copy
        let newIndividuals = elite + mutated.map(\.evaluated)
        // Replacement
        storedPopulation = replacementOperator(currentPopulation, newIndividuals)
        if storedPopulation.isEmpty {
            fatalError("replacementOperator returned no individuals")
        }
        storedGeneration += 1
        return checkTermination()
    }
}

// MARK: GeneticSolver.Offspring

extension GeneticSolver {
    /// An individual of the next generation before it is evaluated: either a
    /// parent copied unchanged, whose fitness is known, or a new individual
    /// from crossover or mutation.
    ///
    /// `@frozen`, so that the inlinable code that switches over it doesn't
    /// need an `@unknown default` when the library is built with library
    /// evolution.
    @frozen @usableFromInline
    enum Offspring {
        case copy(EvaluatedElement<Element>)
        case new(Element)

        // MARK: Computed Properties

        @inlinable var element: Element {
            switch self {
                case let .copy(parent): parent.element
                case let .new(element): element
            }
        }

        /// The individual with its fitness, evaluating it if it is new.
        @inlinable var evaluated: EvaluatedElement<Element> {
            switch self {
                case let .copy(parent): parent
                case let .new(element): EvaluatedElement(element)
            }
        }
    }
}
