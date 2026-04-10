//
//  GlobalSearchViewModelTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import XCTest
import SceytChat

final class GlobalSearchViewModelTests: XCTestCase {

    private var viewModel: GlobalSearchViewModel!

    override func setUp() {
        super.setUp()
        viewModel = GlobalSearchViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - shouldShowChannelSection

    func testShouldShowChannelSection_defaultsToTrue() {
        XCTAssertTrue(viewModel.shouldShowChannelSection,
                      "Channel section should be visible when no user filter is set")
    }

    func testShouldShowChannelSection_falseWhenFilterUserIsSet() {
        viewModel.filterUser = ChatUser(id: "alice")
        XCTAssertFalse(viewModel.shouldShowChannelSection,
                       "Channel section should be hidden when a user filter is active")
    }

    func testShouldShowChannelSection_trueAfterFilterUserCleared() {
        viewModel.filterUser = ChatUser(id: "alice")
        viewModel.filterUser = nil
        XCTAssertTrue(viewModel.shouldShowChannelSection,
                      "Channel section should become visible again after filter is cleared")
    }

    func testShouldShowChannelSection_independentOfChannelTypes() {
        viewModel.channelTypes = ["direct", "group"]
        XCTAssertTrue(viewModel.shouldShowChannelSection,
                      "channelTypes alone must not affect shouldShowChannelSection")

        viewModel.filterUser = ChatUser(id: "bob")
        XCTAssertFalse(viewModel.shouldShowChannelSection,
                       "filterUser overrides regardless of channelTypes")
    }

    // MARK: - subjectMatches: prefix matching

    func testSubjectMatches_prefixOfFirstWord() {
        // "Gro" is a prefix of "Group"
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "Gro"))
    }

    func testSubjectMatches_fullWordMatch() {
        // "Group" exactly matches the first word
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "Group"))
    }

    func testSubjectMatches_prefixOfSecondWord() {
        // "Fo" is a prefix of "For"
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New Group For", query: "Fo"))
    }

    func testSubjectMatches_prefixCaseInsensitive() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "GROUP"))
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "group"))
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "GROUP 1", query: "gro"))
    }

    // MARK: - subjectMatches: suffix matching

    func testSubjectMatches_suffixOfWord() {
        // "oup" is a suffix of "Group"
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New Group For", query: "oup"),
                      "suffix of a word should match")
    }

    func testSubjectMatches_suffixCaseInsensitive() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New Group For", query: "OUP"))
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New GROUP For", query: "oup"))
    }

    func testSubjectMatches_suffixOfLastWord() {
        // "or" is a suffix of "For"
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New Group For", query: "or"))
    }

    // MARK: - subjectMatches: middle-only (should NOT match)

    func testSubjectMatches_middleOfWord_noMatch() {
        // "ou" is in the middle of "Group" (g-r-o-u-p), not a prefix or suffix
        XCTAssertFalse(GlobalSearchViewModel.subjectMatches(subject: "Group New", query: "ou"),
                       "middle-of-word should not match")
    }

    func testSubjectMatches_middleOfWord_multipleWords_noMatch() {
        // "rou" is a middle slice of "Group" — not prefix, not suffix
        XCTAssertFalse(GlobalSearchViewModel.subjectMatches(subject: "Group Chat", query: "rou"))
    }

    // MARK: - subjectMatches: whitespace trimming

    func testSubjectMatches_queryWithLeadingTrailingSpaces() {
        // "    Group    " should behave the same as "Group" — but trimming happens
        // upstream in search(query:), so subjectMatches receives the already-trimmed token.
        // This test documents the contract: trimmed query matches.
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "Group"))
    }

    func testSubjectMatches_subjectWithExtraSpaces() {
        // Extra spaces between words in subject should not cause false negatives
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New  Group  For", query: "oup"))
        XCTAssertFalse(GlobalSearchViewModel.subjectMatches(subject: "New  Group  For", query: "ou"))
    }

    // MARK: - subjectMatches: edge cases

    func testSubjectMatches_emptyQuery_noMatch() {
        XCTAssertFalse(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: ""))
    }

    func testSubjectMatches_emptySubject_noMatch() {
        XCTAssertFalse(GlobalSearchViewModel.subjectMatches(subject: "", query: "Group"))
    }

    func testSubjectMatches_queryLongerThanAnyWord_noMatch() {
        // "GroupName" is longer than both "Group" and "1"
        XCTAssertFalse(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "GroupName"))
    }

    func testSubjectMatches_singleCharacterQuery_prefix() {
        // "G" is a prefix of "Group"
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "G"))
    }

    func testSubjectMatches_singleCharacterQuery_suffix() {
        // "p" is a suffix of "Group"
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "p"))
    }

    func testSubjectMatches_singleCharacterQuery_noMatch() {
        // "r" is in the middle of "Group", not prefix or suffix
        XCTAssertFalse(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "r"))
    }

    func testSubjectMatches_queryMatchesEntireWord() {
        // Exact word match is both prefix and suffix simultaneously
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New Group For", query: "Group"))
    }

    // MARK: - subjectMatches: direct channel name matching
    // Direct channels are filtered by building "firstName lastName" and running subjectMatches.

    func testDirectChannel_firstNamePrefix_matches() {
        // peer: firstName "John", lastName "Doe" → "John Doe"
        // query "Jo" → prefix of "John"
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "Jo"))
    }

    func testDirectChannel_lastNamePrefix_matches() {
        // query "Do" → prefix of "Doe"
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "Do"))
    }

    func testDirectChannel_firstNameSuffix_matches() {
        // query "hn" → suffix of "John"
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "hn"))
    }

    func testDirectChannel_lastNameSuffix_matches() {
        // query "oe" → suffix of "Doe"
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "oe"))
    }

    func testDirectChannel_middleOfFirstName_noMatch() {
        // query "oh" → middle of "John" (j-o-h-n), not prefix or suffix
        XCTAssertFalse(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "oh"))
    }

    func testDirectChannel_middleOfLastName_noMatch() {
        // "o" is in the middle of "Doe" (d-o-e): not a prefix ("d") and not a suffix ("e", "oe")
        XCTAssertFalse(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "o"))
    }

    func testDirectChannel_fullFirstName_matches() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "John"))
    }

    func testDirectChannel_fullLastName_matches() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "Doe"))
    }

    func testDirectChannel_caseInsensitive_matches() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "JO"))
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "doe"))
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "JOHN DOE", query: "jo"))
    }

    func testDirectChannel_onlyFirstName_prefix() {
        // peer has no lastName → subject is just "Alice"
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Alice", query: "Ali"))
    }

    func testDirectChannel_onlyFirstName_middleNoMatch() {
        XCTAssertFalse(GlobalSearchViewModel.subjectMatches(subject: "Alice", query: "lic"))
    }

    // MARK: - subjectMatches: user-described scenarios

    func testUserScenario_groupWithSpaces_findsByTrimmedQuery() {
        // Subject "Group 1", user types "    Group    " → trimmed to "Group" upstream,
        // "Group" is prefix of "Group" → should find
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "Group"))
    }

    func testUserScenario_suffixSearch_finds() {
        // Subject "New Group For", query "oup" → suffix of "Group" → should find
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New Group For", query: "oup"))
    }

    func testUserScenario_middleSearch_doesNotFind() {
        // Subject "Group New", query "ou" → middle of "Group" → should NOT find
        XCTAssertFalse(GlobalSearchViewModel.subjectMatches(subject: "Group New", query: "ou"))
    }
}
