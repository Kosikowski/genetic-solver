//  GeneticSolver+GeneticOperators.swift
//  genetic-solver
//
//  Creates a GeneticSolver from a type that conforms to GeneticOperators.

public extension GeneticSolver {
    /// Initialize the genetic solver with the operators of a `GeneticOperators` type.
    ///
    /// The solver uses `Operators.selectionOperator(population:)`,
    /// `crossoverOperator(parent1:parent2:)`, `mutationOperator(element:)`,
    /// `replacementOperator(old:new:)` and `newElement()`, including any default
    /// implementations the type doesn't override. Each one can still be replaced
    /// afterwards through the solver's properties.
    ///
    /// ```swift
    /// var solver = GeneticSolver(
    ///     populationSize: 50,
    ///     operators: MyGeneticOperators.self,
    ///     terminationCheck: MyGeneticOperators.fixedGenerationTermination(maxGenerations: 100)
    /// )
    /// ```
    @inlinable
    init<Operators: GeneticOperators>(
        populationSize: Int,
        crossoverRate: Double = 0.7,
        mutationRate: Double = 0.01,
        eliteCount: Int = 0,
        operators _: Operators.Type,
        terminationCheck: @escaping TerminationCheck<Element>
    ) where Operators.Element == Element {
        self.init(
            populationSize: populationSize,
            crossoverRate: crossoverRate,
            mutationRate: mutationRate,
            eliteCount: eliteCount,
            selectionOperator: { Operators.selectionOperator(population: $0) },
            crossoverOperator: { Operators.crossoverOperator(parent1: $0, parent2: $1) },
            mutationOperator: { Operators.mutationOperator(element: $0) },
            replacementOperator: { Operators.replacementOperator(old: $0, new: $1) },
            terminationCheck: terminationCheck,
            newElement: { Operators.newElement() }
        )
    }
}
