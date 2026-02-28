import Testing

@testable import Models

@Suite("PartType") struct PartTypeTests {
    @Test("Vocal part types are identified correctly") func vocalTypes() {
        let vocalTypes: [PartType] = [
            .soprano, .alto, .tenor, .bass, .soprano1, .soprano2, .alto1, .alto2, .tenor1, .tenor2,
            .bass1, .bass2, .descant,
        ]
        for partType in vocalTypes {
            #expect(partType.isVocal == true, "\(partType) should be vocal")
        }
    }

    @Test("Non-vocal part types are identified correctly") func nonVocalTypes() {
        #expect(PartType.piano.isVocal == false)
        #expect(PartType.accompaniment.isVocal == false)
    }

    @Test("Display names are human-readable") func displayNames() {
        #expect(PartType.soprano.displayName == "Soprano")
        #expect(PartType.tenor1.displayName == "Tenor 1")
        #expect(PartType.bass2.displayName == "Bass 2")
        #expect(PartType.descant.displayName == "Descant")
        #expect(PartType.piano.displayName == "Piano")
    }

    @Test("Default MIDI programs are correct") func defaultMidiPrograms() {
        #expect(PartType.piano.defaultMidiProgram == 0)
        #expect(PartType.accompaniment.defaultMidiProgram == 0)
        #expect(PartType.tenor.defaultMidiProgram == 52)
        #expect(PartType.soprano.defaultMidiProgram == 52)
    }

    @Test("Tenor parts have octave transposition of 1") func tenorOctaveTransposition() {
        #expect(PartType.tenor.octaveTransposition == 1)
        #expect(PartType.tenor1.octaveTransposition == 1)
        #expect(PartType.tenor2.octaveTransposition == 1)
    }

    @Test("Non-tenor parts have octave transposition of 0") func nonTenorOctaveTransposition() {
        #expect(PartType.soprano.octaveTransposition == 0)
        #expect(PartType.alto.octaveTransposition == 0)
        #expect(PartType.bass.octaveTransposition == 0)
        #expect(PartType.piano.octaveTransposition == 0)
    }
}
