//  Elitism.swift
//  genetic-solver
//
//  Picks the fittest individuals that the solver carries into the next
//  generation when its eliteCount is above 0.

extension GeneticSolver {
    /// Returns the `count` fittest individuals of `population`, fittest
    /// first; on a tie, the one that comes first in `population` first. It
    /// compares the stored fitness values and evaluates nothing. When
    /// `count` is larger than the population, all of it is returned. A
    /// fitness that isn't equal to itself, such as NaN, ranks below every
    /// other fitness (see `isFitter(_:than:)`).
    static func fittest(_ count: Int, of population: [EvaluatedElement<Element>]) -> [EvaluatedElement<Element>] {
        guard count > 0 else { return [] }
        let ranked = population.indices.sorted { first, second in
            if isFitter(population[first].fitness, than: population[second].fitness) {
                return true
            }
            if isFitter(population[second].fitness, than: population[first].fitness) {
                return false
            }
            return first < second
        }
        return ranked.prefix(count).map { population[$0] }
    }
}
