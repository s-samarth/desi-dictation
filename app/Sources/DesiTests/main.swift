// desi-tests — assertion-based test runner (no XCTest under CLT).
// Covers the app's pure logic; each check guards a behaviour that broke or
// a promise to the user.
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
runMenuBarTests()
runUpdateTests()

let group = DispatchGroup()
group.enter()
Task {
    await runEngineTests()
    group.leave()
}
group.wait()

T.finish()
