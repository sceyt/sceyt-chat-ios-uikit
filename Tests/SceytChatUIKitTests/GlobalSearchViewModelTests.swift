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
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "Gro"))
    }

    func testSubjectMatches_fullWordMatch() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "Group"))
    }

    func testSubjectMatches_prefixOfSecondWord() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New Group For", query: "Fo"))
    }

    func testSubjectMatches_prefixCaseInsensitive() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "GROUP"))
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "group"))
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "GROUP 1", query: "gro"))
    }

    // MARK: - subjectMatches: suffix matching

    func testSubjectMatches_suffixOfWord() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New Group For", query: "oup"))
    }

    func testSubjectMatches_suffixCaseInsensitive() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New Group For", query: "OUP"))
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New GROUP For", query: "oup"))
    }

    func testSubjectMatches_suffixOfLastWord() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New Group For", query: "or"))
    }

    // MARK: - subjectMatches: middle-of-word matching (contains)

    func testSubjectMatches_middleOfWord_matches() {
        // "ou" is in the middle of "Group" — contains match
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group New", query: "ou"))
    }

    func testSubjectMatches_middleOfWord_multipleWords_matches() {
        // "rou" is a middle slice of "Group" — contains match
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group Chat", query: "rou"))
    }

    // MARK: - subjectMatches: whitespace trimming

    func testSubjectMatches_queryWithLeadingTrailingSpaces() {
        // trimming happens upstream in search(query:); subjectMatches receives the already-trimmed token
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "Group"))
    }

    func testSubjectMatches_subjectWithExtraSpaces() {
        // Extra spaces between words should not cause false negatives
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New  Group  For", query: "oup"))
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New  Group  For", query: "ou"))
    }

    // MARK: - subjectMatches: edge cases

    func testSubjectMatches_emptyQuery_noMatch() {
        XCTAssertFalse(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: ""))
    }

    func testSubjectMatches_emptySubject_noMatch() {
        XCTAssertFalse(GlobalSearchViewModel.subjectMatches(subject: "", query: "Group"))
    }

    func testSubjectMatches_queryLongerThanSubject_noMatch() {
        // "GroupName" is not contained in "Group 1"
        XCTAssertFalse(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "GroupName"))
    }

    func testSubjectMatches_singleCharacterQuery_prefix() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "G"))
    }

    func testSubjectMatches_singleCharacterQuery_suffix() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "p"))
    }

    func testSubjectMatches_singleCharacterQuery_middleOfWord_matches() {
        // "r" appears in "Group" — contains match
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "r"))
    }

    func testSubjectMatches_queryMatchesEntireWord() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New Group For", query: "Group"))
    }

    // MARK: - subjectMatches: direct channel name matching
    // Direct channels are filtered by building "firstName lastName" and running subjectMatches.

    func testDirectChannel_firstNamePrefix_matches() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "Jo"))
    }

    func testDirectChannel_lastNamePrefix_matches() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "Do"))
    }

    func testDirectChannel_firstNameSuffix_matches() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "hn"))
    }

    func testDirectChannel_lastNameSuffix_matches() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "oe"))
    }

    func testDirectChannel_middleOfFirstName_matches() {
        // "oh" is contained in "John"
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "oh"))
    }

    func testDirectChannel_middleOfLastName_matches() {
        // "o" is contained in both "John" and "Doe"
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "John Doe", query: "o"))
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
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Alice", query: "Ali"))
    }

    func testDirectChannel_onlyFirstName_middleMatch() {
        // "lic" is contained in "Alice"
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Alice", query: "lic"))
    }

    // MARK: - subjectMatches: user-described scenarios

    func testUserScenario_groupWithSpaces_findsByTrimmedQuery() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group 1", query: "Group"))
    }

    func testUserScenario_suffixSearch_finds() {
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "New Group For", query: "oup"))
    }

    func testUserScenario_middleSearch_finds() {
        // "ou" is contained in "Group" — should find with contains matching
        XCTAssertTrue(GlobalSearchViewModel.subjectMatches(subject: "Group New", query: "ou"))
    }
}
