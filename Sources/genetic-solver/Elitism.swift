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
    ///
    /// Inlinable, like `GeneticSolver.step()`, so that clients specialize it.
    @inlinable
    static func fittest(_ count: Int, of population: [EvaluatedElement<Element>]) -> [EvaluatedElement<Element>] {
        guard count > 0 else { return [] }
        // Indices of the fittest individuals so far, fittest first. Only
        // `count` are kept, so this needs about one comparison per individual
        // when `count` is small, instead of sorting the whole population.
        var kept: [Int] = []
        kept.reserveCapacity(min(count, population.count))
        for index in population.indices {
            let fitness = population[index].fitness
            // Not fitter than the weakest of a full list: not kept.
            if kept.count == count, !isFitter(fitness, than: population[kept[count - 1]].fitness) {
                continue
            }
            // Insert after every kept individual that is at least as fit, so
            // on a tie the earlier individual comes first.
            var low = 0
            var high = kept.count
            while low < high {
                let middle = (low + high) / 2
                if isFitter(fitness, than: population[kept[middle]].fitness) {
                    high = middle
                } else {
                    low = middle + 1
                }
            }
            kept.insert(index, at: low)
            if kept.count > count {
                kept.removeLast()
            }
        }
        return kept.map { population[$0] }
    }
}
