//  Ranking.swift
//  genetic-solver
//
//  How the built-in operators decide which of two fitness values is better.

/// Whether `fitness` ranks above `other`.
///
/// Values are compared with `>`, except that a value that isn't equal to
/// itself, such as `Double.nan`, ranks below every other value. With `>`
/// alone, NaN is neither above nor below anything, so a ranking that
/// contains NaN isn't consistent: sorting gives an unspecified order, and a
/// NaN drawn first wins a tournament. Tournament selection, `bestElement`
/// and elitism use this rule, so they never prefer a NaN fitness to a real
/// one. For types without such values, such as integers, it is just `>`.
func isFitter<Fitness: Comparable>(_ fitness: Fitness, than other: Fitness) -> Bool {
    // Comparable values are equal to themselves, except NaN-like values.
    let fitnessIsOrdered = fitness == fitness
    let otherIsOrdered = other == other
    if fitnessIsOrdered, otherIsOrdered {
        return fitness > other
    }
    return fitnessIsOrdered && !otherIsOrdered
}
