import Foundation
import Testing

@testable import Models
@testable import MusicXML

// MARK: - Sample MusicXML

private let minimalSATBXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE score-partwise PUBLIC
      "-//Recordare//DTD MusicXML 4.0 Partwise//EN"
      "http://www.musicxml.org/dtds/partwise.dtd">
    <score-partwise version="4.0">
      <work><work-title>Test Piece</work-title></work>
      <identification>
        <creator type="composer">Test Composer</creator>
      </identification>
      <part-list>
        <score-part id="P1"><part-name>Soprano</part-name></score-part>
        <score-part id="P2"><part-name>Alto</part-name></score-part>
        <score-part id="P3"><part-name>Tenor</part-name></score-part>
        <score-part id="P4"><part-name>Bass</part-name></score-part>
        <score-part id="P5"><part-name>Piano</part-name></score-part>
      </part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>1</divisions>
            <key><fifths>-2</fifths><mode>major</mode></key>
            <time><beats>4</beats><beat-type>4</beat-type></time>
          </attributes>
          <direction><sound tempo="120"/></direction>
          <note>
            <pitch><step>B</step><alter>-1</alter><octave>4</octave></pitch>
            <duration>1</duration>
            <type>quarter</type>
            <lyric number="1"><syllabic>single</syllabic><text>La</text></lyric>
          </note>
          <note>
            <pitch><step>C</step><octave>5</octave></pitch>
            <duration>1</duration>
            <type>quarter</type>
          </note>
          <note>
            <pitch><step>D</step><octave>5</octave></pitch>
            <duration>2</duration>
            <type>half</type>
          </note>
        </measure>
      </part>
      <part id="P2">
        <measure number="1">
          <attributes><divisions>1</divisions></attributes>
          <note>
            <pitch><step>F</step><octave>4</octave></pitch>
            <duration>4</duration>
            <type>whole</type>
          </note>
        </measure>
      </part>
      <part id="P3">
        <measure number="1">
          <attributes><divisions>1</divisions></attributes>
          <note>
            <pitch><step>B</step><alter>-1</alter><octave>3</octave></pitch>
            <duration>4</duration>
            <type>whole</type>
            <tie type="start"/>
          </note>
        </measure>
      </part>
      <part id="P4">
        <measure number="1">
          <attributes><divisions>1</divisions></attributes>
          <note>
            <rest/>
            <duration>2</duration>
            <type>half</type>
          </note>
          <note>
            <pitch><step>B</step><alter>-1</alter><octave>2</octave></pitch>
            <duration>2</duration>
            <type>half</type>
          </note>
        </measure>
      </part>
      <part id="P5">
        <measure number="1">
          <attributes><divisions>1</divisions></attributes>
          <note>
            <pitch><step>B</step><alter>-1</alter><octave>3</octave></pitch>
            <duration>4</duration>
            <type>whole</type>
          </note>
        </measure>
      </part>
    </score-partwise>
    """

private let mixedChordXML = """
    <?xml version="1.0"?>
    <score-partwise>
      <part-list>
        <score-part id="P1"><part-name>Piano</part-name></score-part>
      </part-list>
      <part id="P1">
        <measure number="1">
          <attributes><divisions>1</divisions></attributes>
          <note>
            <pitch><step>C</step><octave>4</octave></pitch>
            <duration>1</duration>
            <type>quarter</type>
          </note>
          <note>
            <chord/>
            <pitch><step>E</step><octave>4</octave></pitch>
            <duration>1</duration>
            <type>quarter</type>
          </note>
          <note>
            <pitch><step>D</step><octave>4</octave></pitch>
            <duration>1</duration>
            <type>quarter</type>
          </note>
          <note>
            <pitch><step>E</step><octave>4</octave></pitch>
            <duration>2</duration>
            <type>half</type>
          </note>
        </measure>
      </part>
    </score-partwise>
    """

// MARK: - Tests

@Suite("MusicXMLParser") struct MusicXMLParserTests {
    let parser = MusicXMLParser()

    @Test("Parses title from work-title") func parsesTitle() throws {
        let score = try parser.parse(data: Data(minimalSATBXML.utf8))
        #expect(score.title == "Test Piece")
    }

    @Test("Parses composer from creator") func parsesComposer() throws {
        let score = try parser.parse(data: Data(minimalSATBXML.utf8))
        #expect(score.composer == "Test Composer")
    }

    @Test("Parses all five parts") func parsesFiveParts() throws {
        let score = try parser.parse(data: Data(minimalSATBXML.utf8))
        #expect(score.parts.count == 5)
    }

    @Test("Infers part types from names") func infersPartTypes() throws {
        let score = try parser.parse(data: Data(minimalSATBXML.utf8))
        #expect(score.parts[0].partType == .soprano)
        #expect(score.parts[1].partType == .alto)
        #expect(score.parts[2].partType == .tenor)
        #expect(score.parts[3].partType == .bass)
        #expect(score.parts[4].partType == .piano)
    }

    @Test("Parses key signature") func parsesKeySignature() throws {
        let score = try parser.parse(data: Data(minimalSATBXML.utf8))
        #expect(score.keySignature.fifths == -2)
        #expect(score.keySignature.mode == .major)
    }

    @Test("Parses time signature") func parsesTimeSignature() throws {
        let score = try parser.parse(data: Data(minimalSATBXML.utf8))
        #expect(score.timeSignature.beats == 4)
        #expect(score.timeSignature.beatType == 4)
    }

    @Test("Parses tempo from sound element") func parsesTempo() throws {
        let score = try parser.parse(data: Data(minimalSATBXML.utf8))
        #expect(score.tempo == 120)
    }

    @Test("Parses soprano notes correctly") func parsesSopranoNotes() throws {
        let score = try parser.parse(data: Data(minimalSATBXML.utf8))
        let soprano = score.parts[0]
        #expect(soprano.measures.count == 1)
        #expect(soprano.measures[0].notes.count == 3)

        let firstNote = soprano.measures[0].notes[0]
        #expect(firstNote.pitch?.step == .b)
        #expect(firstNote.pitch?.alter == -1)
        #expect(firstNote.pitch?.octave == 4)
        #expect(firstNote.duration == 1.0)
    }

    @Test("Parses lyrics with syllabic info") func parsesLyrics() throws {
        let score = try parser.parse(data: Data(minimalSATBXML.utf8))
        let firstNote = score.parts[0].measures[0].notes[0]
        #expect(firstNote.lyric?.text == "La")
        #expect(firstNote.lyric?.syllabic == .single)
    }

    @Test("Parses rest notes") func parsesRests() throws {
        let score = try parser.parse(data: Data(minimalSATBXML.utf8))
        let bass = score.parts[3]
        let firstNote = bass.measures[0].notes[0]
        #expect(firstNote.isRest == true)
        #expect(firstNote.pitch == nil)
    }

    @Test("Parses tied notes") func parsesTies() throws {
        let score = try parser.parse(data: Data(minimalSATBXML.utf8))
        let tenor = score.parts[2]
        let note = tenor.measures[0].notes[0]
        #expect(note.isTied == true)
    }

    @Test("Parses note durations relative to divisions") func parsesDurations() throws {
        let score = try parser.parse(data: Data(minimalSATBXML.utf8))
        let soprano = score.parts[0]
        let notes = soprano.measures[0].notes
        // divisions=1, so duration values map directly to quarter notes
        #expect(notes[0].duration == 1.0)  // quarter
        #expect(notes[1].duration == 1.0)  // quarter
        #expect(notes[2].duration == 2.0)  // half
    }

    @Test("Assigns vocal MIDI programs to voice parts") func assignsVocalMidiPrograms() throws {
        let score = try parser.parse(data: Data(minimalSATBXML.utf8))
        #expect(score.parts[0].midiProgram == 52)  // choir aahs
        #expect(score.parts[4].midiProgram == 0)  // piano
    }

    @Test("Throws on empty data") func throwsOnEmptyData() throws {
        #expect(throws: ChoirHelperError.self) { try parser.parse(data: Data()) }
    }

    @Test("Throws on invalid XML") func throwsOnInvalidXML() throws {
        #expect(throws: ChoirHelperError.self) { try parser.parse(data: Data("not xml".utf8)) }
    }

    @Test("Handles divisions > 1") func handlesDivisionsGreaterThanOne() throws {
        let xml = """
            <?xml version="1.0"?>
            <score-partwise>
              <part-list>
                <score-part id="P1"><part-name>Soprano</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>2</divisions></attributes>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>2</duration>
                    <type>quarter</type>
                  </note>
                  <note>
                    <pitch><step>D</step><octave>4</octave></pitch>
                    <duration>4</duration>
                    <type>half</type>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parser.parse(data: Data(xml.utf8))
        let notes = score.parts[0].measures[0].notes
        #expect(notes[0].duration == 1.0)  // 2/2 = 1 quarter
        #expect(notes[1].duration == 2.0)  // 4/2 = 2 quarters
    }

    // MARK: - Chord parsing

    @Test("Parses three-note chord as one Note with three pitches") func parsesChordCEG() throws {
        let xml = """
            <?xml version="1.0"?>
            <score-partwise>
              <part-list>
                <score-part id="P1"><part-name>Piano</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                    <type>quarter</type>
                  </note>
                  <note>
                    <chord/>
                    <pitch><step>E</step><octave>4</octave></pitch>
                    <duration>1</duration>
                    <type>quarter</type>
                  </note>
                  <note>
                    <chord/>
                    <pitch><step>G</step><octave>4</octave></pitch>
                    <duration>1</duration>
                    <type>quarter</type>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parser.parse(data: Data(xml.utf8))
        let notes = score.parts[0].measures[0].notes
        #expect(notes.count == 1)
        #expect(notes[0].pitches.count == 3)
        #expect(notes[0].pitches[0].step == .c)
        #expect(notes[0].pitches[1].step == .e)
        #expect(notes[0].pitches[2].step == .g)
    }

    @Test("Mixed chords and single notes produce correct note count") func mixedChordAndSingle()
        throws
    {
        let score = try parser.parse(data: Data(mixedChordXML.utf8))
        let notes = score.parts[0].measures[0].notes
        // C+E chord (1 note), D single, E single = 3 notes
        #expect(notes.count == 3)
        #expect(notes[0].pitches.count == 2)
        #expect(notes[0].isChord)
        #expect(notes[1].pitches.count == 1)
        #expect(!notes[1].isChord)
        #expect(notes[2].pitches.count == 1)
    }

    @Test("Chord inherits previous note's duration") func chordInheritsDuration() throws {
        let xml = """
            <?xml version="1.0"?>
            <score-partwise>
              <part-list>
                <score-part id="P1"><part-name>Piano</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>2</duration>
                    <type>half</type>
                  </note>
                  <note>
                    <chord/>
                    <pitch><step>E</step><octave>4</octave></pitch>
                    <duration>2</duration>
                    <type>half</type>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parser.parse(data: Data(xml.utf8))
        let notes = score.parts[0].measures[0].notes
        #expect(notes.count == 1)
        #expect(notes[0].duration == 2.0)
        #expect(notes[0].noteType == .half)
    }
}
