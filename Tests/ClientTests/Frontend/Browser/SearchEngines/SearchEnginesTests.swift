// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

@testable import Client
import Foundation
import XCTest
import Shared

class SearchEnginesTests: XCTestCase {

    private let defaultSearchEngineName = "Google"
    private let expectedEngineNames = ["Amazon.com", "Bing", "DuckDuckGo", "Google", "eBay", "Wikipedia"]

    func testIncludesExpectedEngines() {
        // Verify that the set of shipped engines includes the expected subset.
        let profile = MockProfile()
        let engines = SearchEngines(prefs: profile.prefs, files: profile.files).orderedEngines
        XCTAssertTrue((engines?.count)! >= expectedEngineNames.count)

        for engineName in expectedEngineNames {
            XCTAssertTrue(((engines?.filter { engine in engine.shortName == engineName })?.count)! > 0)
        }
    }

    func testDefaultEngineOnStartup() {
        // If this is our first run, Google should be first for the en locale.
        let profile = MockProfile()
        let engines = SearchEngines(prefs: profile.prefs, files: profile.files)
        XCTAssertEqual(engines.defaultEngine.shortName, defaultSearchEngineName)
        XCTAssertEqual(engines.orderedEngines[0].shortName, defaultSearchEngineName)
    }

    func testAddingAndDeletingCustomEngines() {
        let testEngine = OpenSearchEngine(engineID: "ATester",
                                          shortName: "ATester",
                                          image: UIImage(),
                                          searchTemplate: "http://firefox.com/find?q={searchTerm}",
                                          suggestTemplate: nil,
                                          isCustomEngine: true)
        let profile = MockProfile()
        let engines = SearchEngines(prefs: profile.prefs, files: profile.files)
        engines.addSearchEngine(testEngine)
        XCTAssertEqual(engines.orderedEngines[1].engineID, testEngine.engineID)

        engines.deleteCustomEngine(testEngine)
        let deleted = engines.orderedEngines.filter {$0 == testEngine}
        XCTAssertEqual(deleted, [])
    }

    func testDefaultEngine() {
        let profile = MockProfile()
        let engines = SearchEngines(prefs: profile.prefs, files: profile.files)
        let engineSet = engines.orderedEngines

        engines.defaultEngine = (engineSet?[0])!
        XCTAssertTrue(engines.isEngineDefault((engineSet?[0])!))
        XCTAssertFalse(engines.isEngineDefault((engineSet?[1])!))
        // The first ordered engine is the default.
        XCTAssertEqual(engines.orderedEngines[0].shortName, engineSet?[0].shortName)

        engines.defaultEngine = (engineSet?[1])!
        XCTAssertFalse(engines.isEngineDefault((engineSet?[0])!))
        XCTAssertTrue(engines.isEngineDefault((engineSet?[1])!))
        // The first ordered engine is the default.
        XCTAssertEqual(engines.orderedEngines[0].shortName, engineSet?[1].shortName)

        let engines2 = SearchEngines(prefs: profile.prefs, files: profile.files)
        // The default engine should have been persisted.
        XCTAssertTrue(engines2.isEngineDefault((engineSet?[1])!))
        // The first ordered engine is the default.
        XCTAssertEqual(engines.orderedEngines[0].shortName, engineSet?[1].shortName)
    }

    func testOrderedEngines() {
        let profile = MockProfile()
        let engines = SearchEngines(prefs: profile.prefs, files: profile.files)

        engines.orderedEngines = [expectedEngineNames[4], expectedEngineNames[2], expectedEngineNames[0]].map { name in
            for engine in engines.orderedEngines {
                if engine.shortName == name {
                    return engine
                }
            }
            XCTFail("Could not find engine: \(name)")
            return engines.orderedEngines.first!
        }
        XCTAssertEqual(engines.orderedEngines[0].shortName, expectedEngineNames[4])
        XCTAssertEqual(engines.orderedEngines[1].shortName, expectedEngineNames[2])
        XCTAssertEqual(engines.orderedEngines[2].shortName, expectedEngineNames[0])

        let engines2 = SearchEngines(prefs: profile.prefs, files: profile.files)
        // The ordering should have been persisted.
        XCTAssertEqual(engines2.orderedEngines[0].shortName, expectedEngineNames[4])
        XCTAssertEqual(engines2.orderedEngines[1].shortName, expectedEngineNames[2])
        XCTAssertEqual(engines2.orderedEngines[2].shortName, expectedEngineNames[0])

        // Remaining engines should be appended in alphabetical order.
        XCTAssertEqual(engines2.orderedEngines[3].shortName, expectedEngineNames[1])
        XCTAssertEqual(engines2.orderedEngines[4].shortName, expectedEngineNames[3])
        XCTAssertEqual(engines2.orderedEngines[5].shortName, expectedEngineNames[5])
    }

    func testQuickSearchEngines() {
        let profile = MockProfile()
        let engines = SearchEngines(prefs: profile.prefs, files: profile.files)
        let engineSet = engines.orderedEngines

        // You can't disable the default engine.
        engines.defaultEngine = (engineSet?[1])!
        engines.disableEngine((engineSet?[1])!)
        XCTAssertTrue(engines.isEngineEnabled((engineSet?[1])!))

        // The default engine is not included in the quick search engines.
        XCTAssertEqual(0, engines.quickSearchEngines.filter { engine in engine.shortName == engineSet?[1].shortName }.count)

        // Enable and disable work.
        engines.enableEngine((engineSet?[0])!)
        XCTAssertTrue(engines.isEngineEnabled((engineSet?[0])!))
        XCTAssertEqual(1, engines.quickSearchEngines.filter { engine in engine.shortName == engineSet?[0].shortName }.count)

        engines.disableEngine((engineSet?[0])!)
        XCTAssertFalse(engines.isEngineEnabled((engineSet?[0])!))
        XCTAssertEqual(0, engines.quickSearchEngines.filter { engine in engine.shortName == engineSet?[0].shortName }.count)

        // Setting the default engine enables it.
        engines.defaultEngine = (engineSet?[0])!
        XCTAssertTrue(engines.isEngineEnabled((engineSet?[1])!))

        // Setting the order may change the default engine, which enables it.
        engines.orderedEngines = [(engineSet?[2])!, (engineSet?[1])!, (engineSet?[0])!]
        XCTAssertTrue(engines.isEngineDefault((engineSet?[2])!))
        XCTAssertTrue(engines.isEngineEnabled((engineSet?[2])!))

        // The enabling should be persisted.
        engines.enableEngine((engineSet?[2])!)
        engines.disableEngine((engineSet?[1])!)
        engines.enableEngine((engineSet?[0])!)

        let engines2 = SearchEngines(prefs: profile.prefs, files: profile.files)
        XCTAssertTrue(engines2.isEngineEnabled((engineSet?[2])!))
        XCTAssertFalse(engines2.isEngineEnabled((engineSet?[1])!))
        XCTAssertTrue(engines2.isEngineEnabled((engineSet?[0])!))
    }

    func testSearchSuggestionSettings() {
        let profile = MockProfile()
        let engines = SearchEngines(prefs: profile.prefs, files: profile.files)

        // By default, you should see search suggestions
        XCTAssertTrue(engines.shouldShowSearchSuggestions)

        // Setting should be persisted.
        engines.shouldShowSearchSuggestions = false

        let engines2 = SearchEngines(prefs: profile.prefs, files: profile.files)
        XCTAssertFalse(engines2.shouldShowSearchSuggestions)
    }

    func testUnorderedSearchEngines() {
        let profile = MockProfile()
        let engines = SearchEngines(prefs: profile.prefs, files: profile.files)

        XCTAssertEqual(
            engines.getUnorderedBundledEnginesFor(locale: Locale(identifier: "zh-TW")).compactMap({$0.shortName}),
            ["Google", "Bing", "DuckDuckGo", "Wikipedia (zh)"])
        XCTAssertEqual(
            engines.getUnorderedBundledEnginesFor(locale: Locale(identifier: "en-CA")).compactMap({$0.shortName}),
            ["Google", "Amazon.com", "Bing", "DuckDuckGo", "eBay", "Wikipedia"])
        XCTAssertEqual(
            engines.getUnorderedBundledEnginesFor(locale: Locale(identifier: "de-DE")).compactMap({$0.shortName}),
            ["Google", "Amazon.de", "Bing", "DuckDuckGo", "eBay", "Ecosia", "Qwant", "Wikipedia (de)"])
        XCTAssertEqual(
            engines.getUnorderedBundledEnginesFor(locale: Locale(identifier: "en-US")).compactMap({$0.shortName}),
            ["Google", "Amazon.com", "Bing", "DuckDuckGo", "eBay", "Wikipedia"])
    }

    func testGetOrderedEngines() {
        // setup an existing search engine in the profile
        let profile = MockProfile()
        profile.prefs.setObject(["Google"], forKey: "search.orderedEngineNames")
        let engines = SearchEngines(prefs: profile.prefs, files: profile.files)
        XCTAssert(engines.orderedEngines.count > 1, "There should be more than one search engine")
        XCTAssertEqual(engines.orderedEngines.first!.shortName, "Google", "Google should be the first search engine")
    }
}
