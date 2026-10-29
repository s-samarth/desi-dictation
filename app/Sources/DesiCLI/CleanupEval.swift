import DesiDictationKit
import Foundation

/// desi-cli --cleanup "text"      what review would offer: fillers and corrections
/// desi-cli --fillers cases.tsv  filler accuracy (evals/fillers/cases.tsv: filler|keep<TAB>phrase<TAB>sentence)
/// Checker from $DESI_CHECKER or the installed one (WordRows.swift).
func runCleanup(_ args: [String]) -> Never {
    let arg = args.dropFirst().first ?? ""
    let code = args.first == "--fillers" ? fillerEval(arg) : cleanup(arg)
    cliChecker = nil   // free before exit (FM#40)
    exit(code)
}

private func cleanup(_ text: String) -> Int32 {
    guard let scorer = cliChecker else { print("no context checker"); return 1 }
    print("sounds removed: \(Fillers.removeSounds(text))")
    for c in Fillers.candidates(in: text, scorer: scorer) {
        print(String(format: "filler  %@  %@", c.score.map { String(format: "%+.2f", $0) } ?? "start", c.phrase))
    }
    for c in Corrections.find(in: text, scorer: scorer) {
        print("correction  \"\(text[c.range])\" → \"\(c.replacement)\"")
    }
    return 0
}

private func fillerEval(_ path: String) -> Int32 {
    guard let scorer = cliChecker, let tsv = try? String(contentsOfFile: path, encoding: .utf8) else {
        print("need the checker and \(path)"); return 1
    }
    var rows: [(filler: Bool, score: Double?)] = []
    for line in tsv.split(separator: "\n") where !line.hasPrefix("#") {
        let f = line.split(separator: "\t").map(String.init)
        guard f.count == 3 else { continue }
        let found = Fillers.candidates(in: f[2], scorer: scorer).first { $0.phrase.lowercased() == f[1].lowercased() }
        rows.append((f[0] == "filler", found.map { $0.score ?? .infinity }))
        print(String(format: "%@ %7@  %@", f[0] == "filler" ? "F" : "K",
                     found.map { $0.score.map { String(format: "%+.2f", $0) } ?? "start" } ?? "-", f[2]))
    }
    let fillers = rows.filter(\.filler).count, keeps = rows.count - fillers
    for (name, bar) in [("ask", Fillers.askAbove), ("remove", Fillers.removeAbove)] {
        let hit = rows.filter { $0.filler && ($0.score ?? -.infinity) > bar }.count
        let wrong = rows.filter { !$0.filler && ($0.score ?? -.infinity) > bar }.count
        print("\(name) (> \(bar)): fillers caught \(hit)/\(fillers), real words flagged \(wrong)/\(keeps)")
    }
    return 0
}
