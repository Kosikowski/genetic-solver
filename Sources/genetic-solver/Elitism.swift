//  Elitism.swift
//  genetic-solver
//
//  Picks the fittest individuals that the solver carries into the next
//  generation when its eliteCount is above 0.

extension GeneticSolver {
    /// Returns the `count` fittest individuals of `population`, fittest
    /// first; on a tie, the one that comes first in `population` first. It
    /// compares the stored fitness values and evaluates nothing. When
    /// `count` is larger than the population, all of it is returned.
    static func fittest(_ count: Int, of population: [EvaluatedElement<Element>]) -> [EvaluatedElement<Element>] {
        guard count > 0 else { return [] }
        let ranked = population.indices.sorted { first, second in
            if population[first].fitness != population[second].fitness {
                return population[first].fitness > population[second].fitness
            }
            return first < second
        }
        return ranked.prefix(count).map { population[$0] }
    }
}
