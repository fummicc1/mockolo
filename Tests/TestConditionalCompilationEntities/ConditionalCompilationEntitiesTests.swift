final class ConditionalCompilationEntitiesTests: MockoloTestCase {
    func testProtocolInIfBlock() {
        verify(srcContent: protocolInIfBlock,
               dstContent: protocolInIfBlockMock)
    }

    func testProtocolsInIfElseIf() {
        verify(srcContent: protocolsInIfElseIf,
               dstContent: protocolsInIfElseIfMock)
    }

    func testProtocolAndImportInIfBlock() {
        verify(srcContent: protocolAndImportInIfBlock,
               dstContent: protocolAndImportInIfBlockMock)
    }

    func testNestedIfWithProtocol() {
        verify(srcContent: nestedIfWithProtocol,
               dstContent: nestedIfWithProtocolMock)
    }

    func testDoublyNestedIfWithProtocol() {
        verify(srcContent: doublyNestedIfWithProtocol,
               dstContent: doublyNestedIfWithProtocolMock)
    }

    func testMixedStandaloneAndWrapped() {
        verify(srcContent: mixedStandaloneAndWrapped,
               dstContent: mixedStandaloneAndWrappedMock)
    }
}
