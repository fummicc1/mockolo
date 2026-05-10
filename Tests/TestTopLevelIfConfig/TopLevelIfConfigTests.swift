import MockoloFramework

final class TopLevelIfConfigTests: MockoloTestCase {
    func testTopLevelIfProtocol() {
        verify(srcContent: topLevelIfProtocol,
               dstContent: topLevelIfProtocolMock)
    }

    func testTopLevelIfElseIfElseProtocols() {
        verify(srcContent: topLevelIfElseIfElseProtocols,
               dstContent: topLevelIfElseIfElseProtocolsMock)
    }

    func testTopLevelNestedIf() {
        verify(srcContent: topLevelNestedIf,
               dstContent: topLevelNestedIfMock)
    }

    func testTopLevelIfWithImportAndProtocol() {
        verify(srcContent: topLevelIfWithImportAndProtocol,
               dstContent: topLevelIfWithImportAndProtocolMock)
    }

    func testTopLevelIfWithUnannotatedProtocol() {
        verify(srcContent: topLevelIfWithUnannotatedProtocol,
               dstContent: topLevelIfWithUnannotatedProtocolMock)
    }

    func testTopLevelIfMixedWithStandalone() {
        verify(srcContent: topLevelIfMixedWithStandalone,
               dstContent: topLevelIfMixedWithStandaloneMock)
    }

    func testTopLevelAndMemberIf() {
        verify(srcContent: topLevelAndMemberIf,
               dstContent: topLevelAndMemberIfMock)
    }
}
