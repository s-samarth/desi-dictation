// desi-tests — assertion-based test runner (no XCTest under CLT).
// Covers every 0.6 feature's pure logic, individually and in combination.
// `swift run desi-tests` → exit 0 means all green.
import Foundation

runDictionaryTests()
runStoreTests()

let group = DispatchGroup()
group.enter()
Task {
    await runEngineTests()
    await runCombinationTests()
    group.leave()
}
group.wait()

T.finish()
