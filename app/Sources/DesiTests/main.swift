// desi-tests — assertion-based test runner (no XCTest under CLT).
// Covers every 0.6 feature's pure logic, individually and in combination.
// `swift run desi-tests` → exit 0 means all green.
import Foundation

runDictionaryTests()
runWordListTests()
runStoreTests()
runNumberTests()
runModelRoutingTests()
runAudioSplitterTests()
runWhisperLabelTests()
runPasteTests()
runVocabularyCorrectorTests()
runVocabularyLearningTests()
runEditTrackerTests()
runContextFitTests()
runReviewTests()
runStrictnessTests()
runCleanupTests()
runFeedbackTests()

let group = DispatchGroup()
group.enter()
Task {
    await runEngineTests()
    await runCombinationTests()
    group.leave()
}
group.wait()

T.finish()
