import Foundation

public struct Pitch: Codable, Sendable, Hashable {
    public let step: Step
    public let alter: Int
    public let octave: Int

    public init(step: Step, alter: Int = 0, octave: Int) {
        self.step = step
        self.alter = alter
        self.octave = octave
    }

    public var midiNumber: Int {
        let baseMidi: [Step: Int] = [.c: 0, .d: 2, .e: 4, .f: 5, .g: 7, .a: 9, .b: 11]
        guard let base = baseMidi[step] else { return 60 }
        return (octave + 1) * 12 + base + alter
    }

    public var frequency: Double { 440.0 * pow(2.0, Double(midiNumber - 69) / 12.0) }

    public var displayName: String {
        let stepName = step.rawValue.uppercased()
        let accidental: String
        switch alter {
        case 1: accidental = "♯"
        case -1: accidental = "♭"
        case 2: accidental = "𝄪"
        case -2: accidental = "𝄫"
        default: accidental = ""
        }
        return "\(stepName)\(accidental)\(octave)"
    }
}

public enum Step: String, Codable, Sendable, CaseIterable { case c, d, e, f, g, a, b }
