import Foundation

/// Cuts long audio into pieces no longer than a limit, at the quietest moment
/// near evenly spaced boundaries, so a cut lands in a pause rather than
/// through a word.
///
/// Exists for whisper's decoder budget (FM#26): one whisper window decodes at
/// most 220 tokens, and Devanagari costs ~5 tokens a word, so dense Hindi
/// overflows after ~16 s of speech. Pure function — tested in desi-tests.
public enum AudioSplitter {
    /// Ranges into `samples`, in order, covering every sample exactly once.
    /// - Parameters:
    ///   - maxSamples: longest allowed piece. Audio at or under it is one piece.
    ///   - searchSamples: how far either side of the even boundary to look for
    ///     a pause (never so far that a piece would exceed `maxSamples`).
    ///   - frame: energy window used to find the pause (100 ms at 16 kHz).
    public static func pieces(
        of samples: [Float], maxSamples: Int,
        searchSamples: Int = 24_000, frame: Int = 1_600
    ) -> [Range<Int>] {
        let total = samples.count
        guard maxSamples > frame, total > maxSamples else { return [0..<total] }
        var ranges: [Range<Int>] = []
        var start = 0
        while total - start > maxSamples {
            let left = total - start
            let piecesLeft = (left + maxSamples - 1) / maxSamples
            // Balanced target: leftover audio split evenly, never a runt tail.
            let target = start + left / piecesLeft
            let lo = max(start + frame, target - searchSamples)
            let hi = min(start + maxSamples, target + searchSamples)
            let cut = quietestPoint(in: samples, lo: lo, hi: hi, frame: frame)
            ranges.append(start..<cut)
            start = cut
        }
        ranges.append(start..<total)
        return ranges
    }

    /// Centre of the lowest-energy `frame`-long window inside `lo..<hi`.
    static func quietestPoint(in samples: [Float], lo: Int, hi: Int, frame: Int) -> Int {
        guard hi - lo >= frame else { return (lo + hi) / 2 }
        let hop = max(1, frame / 4)
        var best = lo + frame / 2
        var bestEnergy = Float.infinity
        var i = lo
        while i + frame <= hi {
            var energy: Float = 0
            for s in samples[i..<(i + frame)] { energy += s * s }
            if energy < bestEnergy {
                bestEnergy = energy
                best = i + frame / 2
            }
            i += hop
        }
        return best
    }
}
