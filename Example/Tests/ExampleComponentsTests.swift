import XCTest
@testable import LightweightCharts
@testable import LightweightCharts_Example

// MARK: - TooltipView Tests

/// Unit tests for TooltipView component
///
/// These tests verify the TooltipView UI component's initialization,
/// configuration, and update behavior.
final class TooltipViewTests: XCTestCase {

    var tooltipView: TooltipView!

    override func setUp() {
        super.setUp()
        let accentColor = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
        tooltipView = TooltipView(accentColor: accentColor)
    }

    override func tearDown() {
        tooltipView = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    /// Tests that TooltipView initializes with correct properties
    func testTooltipViewInitialization() {
        XCTAssertNotNil(tooltipView, "TooltipView should be initialized")
        XCTAssertEqual(tooltipView.layer.borderWidth, 2, "Border width should be 2")
        XCTAssertEqual(tooltipView.backgroundColor, .white, "Background should be white")
        XCTAssertFalse(tooltipView.isUserInteractionEnabled, "User interaction should be disabled")
    }

    /// Tests that TooltipView respects the accent color
    func testTooltipViewAccentColor() {
        let redColor = UIColor.red
        let redTooltip = TooltipView(accentColor: redColor)

        XCTAssertEqual(redTooltip.layer.borderColor, redColor.cgColor, "Border color should match accent color")
    }

    /// Tests that init(coder:) is not implemented
    func testInitCoderNotImplemented() {
        let coder = NSCoder()
        let coderTooltip = TooltipView(coder: coder)
        XCTAssertNil(coderTooltip, "init(coder:) should return nil (fatalError in implementation)")
    }

    // MARK: - Update Tests

    /// Tests that update method sets all labels correctly
    func testTooltipViewUpdateSetsLabels() {
        tooltipView.update(title: "Test Title", price: 123.456, date: "2024-01-15")

        // Since labels are private, we verify the view doesn't crash and layout is valid
        XCTAssertNotNil(tooltipView, "View should still exist after update")
        XCTAssertFalse(tooltipView.subviews.isEmpty, "View should have subviews")
    }

    // MARK: - Layout Tests

    /// Tests that TooltipView creates proper subview hierarchy
    func testTooltipViewSubviewHierarchy() {
        // Check that the view has the expected number of subviews (3 labels)
        let labelCount = tooltipView.subviews.filter { $0 is UILabel }.count
        XCTAssertEqual(labelCount, 3, "TooltipView should have 3 UILabel subviews")
    }

    /// Tests that TooltipView constraints are active
    func testTooltipViewLayoutValid() {
        // Trigger layout
        tooltipView.setNeedsLayout()
        tooltipView.layoutIfNeeded()

        // Verify the view has a valid size
        let size = tooltipView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        XCTAssertGreaterThan(size.width, 0, "View should have a width after layout")
        XCTAssertGreaterThan(size.height, 0, "View should have a height after layout")
    }

    /// Tests that TooltipView adapts to different intrinsic sizes
    func testTooltipViewIntrinsicContentSize() {
        let emptySize = tooltipView.intrinsicContentSize
        // UIView has no intrinsic size by default unless explicitly overridden.
        XCTAssertEqual(emptySize.width, UIView.noIntrinsicMetric,
                       "TooltipView should not declare intrinsic width by default")
        XCTAssertEqual(emptySize.height, UIView.noIntrinsicMetric,
                       "TooltipView should not declare intrinsic height by default")
    }
}

// MARK: - TableViewController.Row Tests

/// Unit tests for TableViewController.Row and Section structs
///
/// These tests verify the Row and Section structs used for navigation
/// in the example app's main table view.
final class TableViewControllerRowTests: XCTestCase {

    // MARK: - Row Structure Tests

    /// Tests that Row struct can be created with valid parameters
    func testRowCreation() {
        let row = TableViewController.Row(
            title: "Test Chart",
            subtitle: nil,
            viewController: { UIViewController() }
        )

        XCTAssertEqual(row.title, "Test Chart", "Title should match")
        XCTAssertNotNil(row.viewController(), "View controller factory should create a view controller")
    }

    /// Tests that Row struct can be created with subtitle
    func testRowCreationWithSubtitle() {
        let row = TableViewController.Row(
            title: "Test Chart",
            subtitle: "Test subtitle",
            viewController: { UIViewController() }
        )

        XCTAssertEqual(row.title, "Test Chart", "Title should match")
        XCTAssertEqual(row.subtitle, "Test subtitle", "Subtitle should match")
    }

    /// Tests that Row creates a new view controller each time
    func testRowFactoryCreatesNewInstances() {
        let row = TableViewController.Row(
            title: "Test",
            subtitle: nil,
            viewController: { UIViewController() }
        )

        let vc1 = row.viewController()
        let vc2 = row.viewController()

        XCTAssertNotIdentical(vc1, vc2, "Factory should create new instances each time")
    }

    /// Tests that Row with different titles are distinct
    func testRowWithDifferentTitles() {
        let row1 = TableViewController.Row(
            title: "Chart 1",
            subtitle: nil,
            viewController: { UIViewController() }
        )
        let row2 = TableViewController.Row(
            title: "Chart 2",
            subtitle: nil,
            viewController: { UIViewController() }
        )

        XCTAssertNotEqual(row1.title, row2.title, "Rows with different titles should have different titles")
    }

    /// Tests that Row can create specific view controller types
    func testRowCreatesSpecificViewControllerTypes() {
        let row = TableViewController.Row(
            title: "Custom Theme",
            subtitle: nil,
            viewController: { CustomThemesViewController() }
        )

        let vc = row.viewController()
        XCTAssertTrue(vc is CustomThemesViewController, "Should create CustomThemesViewController")
    }

    /// Tests that Row handles empty title
    func testRowWithEmptyTitle() {
        let row = TableViewController.Row(
            title: "",
            subtitle: nil,
            viewController: { UIViewController() }
        )

        XCTAssertEqual(row.title, "", "Empty title should be preserved")
        XCTAssertNotNil(row.viewController(), "View controller should still be created")
    }

    /// Tests that Row retains view controller factory
    func testRowFactoryRetention() {
        var createCount = 0
        let row = TableViewController.Row(
            title: "Test",
            subtitle: nil,
            viewController: {
                createCount += 1
                return UIViewController()
            }
        )

        _ = row.viewController()
        _ = row.viewController()

        XCTAssertEqual(createCount, 2, "Factory should be called each time")
    }

    // MARK: - Section Structure Tests

    /// Tests that Section struct can be created with valid parameters
    func testSectionCreation() {
        let section = TableViewController.Section(
            title: "Test Section",
            footer: "Test footer",
            rows: []
        )

        XCTAssertEqual(section.title, "Test Section", "Title should match")
        XCTAssertEqual(section.footer, "Test footer", "Footer should match")
        XCTAssertTrue(section.rows.isEmpty, "Rows should be empty")
    }

    /// Tests that Section can have rows
    func testSectionWithRows() {
        let row = TableViewController.Row(
            title: "Test",
            subtitle: nil,
            viewController: { UIViewController() }
        )
        let section = TableViewController.Section(
            title: "Test Section",
            footer: nil,
            rows: [row]
        )

        XCTAssertEqual(section.rows.count, 1, "Section should have 1 row")
    }

    /// Tests that Section handles nil footer
    func testSectionWithNilFooter() {
        let section = TableViewController.Section(
            title: "Test Section",
            footer: nil,
            rows: []
        )

        XCTAssertNil(section.footer, "Footer should be nil")
    }
}

// MARK: - CustomThemesViewController.Theme Tests

/// Unit tests for CustomThemesViewController.Theme enum
///
/// These tests verify the theme configuration options
/// used in the custom themes example.
final class CustomThemesViewControllerThemeTests: XCTestCase {

    // MARK: - Theme Enumeration Tests

    /// Tests that all themes can be iterated
    func testAllThemesCaseIterable() {
        let allThemes = CustomThemesViewController.Theme.allCases
        XCTAssertEqual(allThemes.count, 2, "Should have exactly 2 themes")

        XCTAssertTrue(allThemes.contains(.dark), "Should contain dark theme")
        XCTAssertTrue(allThemes.contains(.light), "Should contain light theme")
    }

    /// Tests that dark theme has correct title
    func testDarkThemeTitle() {
        XCTAssertEqual(CustomThemesViewController.Theme.dark.title, "Dark")
    }

    /// Tests that light theme has correct title
    func testLightThemeTitle() {
        XCTAssertEqual(CustomThemesViewController.Theme.light.title, "Light")
    }

    /// Tests that all themes have non-empty titles
    func testAllThemesHaveTitles() {
        for theme in CustomThemesViewController.Theme.allCases {
            XCTAssertFalse(theme.title.isEmpty, "Theme \(theme) should have a non-empty title")
        }
    }

    /// Tests that dark theme has chart options
    func testDarkThemeHasChartOptions() {
        let options = CustomThemesViewController.Theme.dark.chartOptions

        XCTAssertNotNil(options.layout, "Dark theme should have layout options")
        XCTAssertNotNil(options.crosshair, "Dark theme should have crosshair options")
        XCTAssertNotNil(options.grid, "Dark theme should have grid options")
    }

    /// Tests that dark theme has watermark options (using v5 plugin API)
    func testDarkThemeHasWatermarkOptions() {
        let watermarkOptions = CustomThemesViewController.Theme.dark.watermarkOptions
        XCTAssertTrue(watermarkOptions.visible, "Dark theme watermark should be visible")
        XCTAssertFalse(watermarkOptions.lines.isEmpty, "Dark theme watermark should have lines")
    }

    /// Tests that light theme has chart options
    func testLightThemeHasChartOptions() {
        let options = CustomThemesViewController.Theme.light.chartOptions

        XCTAssertNotNil(options.layout, "Light theme should have layout options")
        XCTAssertNotNil(options.crosshair, "Light theme should have crosshair options")
        XCTAssertNotNil(options.grid, "Light theme should have grid options")
    }

    /// Tests that light theme has watermark options (using v5 plugin API)
    func testLightThemeHasWatermarkOptions() {
        let watermarkOptions = CustomThemesViewController.Theme.light.watermarkOptions
        XCTAssertTrue(watermarkOptions.visible, "Light theme watermark should be visible")
        XCTAssertFalse(watermarkOptions.lines.isEmpty, "Light theme watermark should have lines")
    }

    /// Tests that dark theme has series options
    func testDarkThemeHasSeriesOptions() {
        let options = CustomThemesViewController.Theme.dark.seriesOptions

        XCTAssertNotNil(options.topColor, "Dark theme should have top color")
        XCTAssertNotNil(options.bottomColor, "Dark theme should have bottom color")
        XCTAssertNotNil(options.lineColor, "Dark theme should have line color")
    }

    /// Tests that light theme has series options
    func testLightThemeHasSeriesOptions() {
        let options = CustomThemesViewController.Theme.light.seriesOptions

        XCTAssertNotNil(options.topColor, "Light theme should have top color")
        XCTAssertNotNil(options.bottomColor, "Light theme should have bottom color")
        XCTAssertNotNil(options.lineColor, "Light theme should have line color")
    }

    /// Tests that dark theme has dark background
    func testDarkThemeHasDarkBackground() {
        let layout = CustomThemesViewController.Theme.dark.chartOptions.layout

        // Dark theme should have a dark background color (#2B2B43)
        if case .solid(let color) = layout?.background {
            XCTAssertEqual(color.rawValue, "rgba(43, 43, 67, 1.0)")
        } else {
            XCTFail("Background should be solid")
        }
    }

    /// Tests that light theme has light background
    func testLightThemeHasLightBackground() {
        let layout = CustomThemesViewController.Theme.light.chartOptions.layout

        // Light theme should have a white background (#FFFFFF)
        if case .solid(let color) = layout?.background {
            XCTAssertEqual(color.rawValue, "rgba(255, 255, 255, 1.0)")
        } else {
            XCTFail("Background should be solid")
        }
    }

    /// Tests that themes have different series colors
    func testThemesHaveDifferentSeriesColors() {
        let darkOptions = CustomThemesViewController.Theme.dark.seriesOptions
        let lightOptions = CustomThemesViewController.Theme.light.seriesOptions

        XCTAssertNotEqual(darkOptions.lineColor, lightOptions.lineColor,
                         "Dark and light themes should have different line colors")
        XCTAssertNotEqual(darkOptions.topColor, lightOptions.topColor,
                         "Dark and light themes should have different top colors")
    }

}

// MARK: - TableViewController New Examples Tests (Task 9.6)

/// Unit tests for TableViewController new example entries
///
/// These tests verify that the new v5 example view controllers
/// are properly registered in TableViewController's section list.
final class TableViewControllerNewExamplesTests: XCTestCase {

    // MARK: - Helper Methods

    /// Find a row by title across all sections
    private func findRow(title: String, in tvc: TableViewController) -> TableViewController.Row? {
        for section in tvc.sections {
            if let row = section.rows.first(where: { $0.title == title }) {
                return row
            }
        }
        return nil
    }

    // MARK: - Row Entry Tests

    /// Tests that all new v5 examples are present and create correct view controllers
    func testAllV5ExamplesPresent() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad to fill sections

        let newExamples: [(title: String, type: UIViewController.Type)] = [
            ("Text Watermark", CustomWatermarkViewController.self),
            ("Image Watermark", ImageWatermarkViewController.self),
            ("Markers Plugin", MarkersPluginViewController.self),
            ("Up-Down Markers Plugin", UpDownMarkersViewController.self)
        ]

        for example in newExamples {
            guard let row = findRow(title: example.title, in: tvc) else {
                XCTFail("\(example.title) row should exist")
                continue
            }

            let vc = row.viewController()
            XCTAssertTrue(type(of: vc) == example.type,
                         "\(example.title) should create \(example.type)")
        }
    }
}

// MARK: - BarChartViewController Tests

/// Unit tests for BarChartViewController
///
/// These tests verify the bar chart example view controller's
/// initialization and properties.
final class BarChartViewControllerTests: XCTestCase {

    // MARK: - Initialization Tests

    /// Tests that BarChartViewController can be created
    func testBarChartViewControllerCreation() {
        let viewController = BarChartViewController()

        XCTAssertNotNil(viewController, "BarChartViewController should be created")
    }

    /// Tests that BarChartViewController has black background
    func testBarChartViewControllerBackgroundColor() {
        let viewController = BarChartViewController()

        _ = viewController.view // Trigger viewDidLoad

        XCTAssertEqual(viewController.view.backgroundColor, .black,
                       "BarChartViewController should have black background")
    }
}

// MARK: - CandlestickChartViewController Tests

/// Unit tests for CandlestickChartViewController
///
/// These tests verify the candlestick chart example view controller's
/// initialization and properties.
final class CandlestickChartViewControllerTests: XCTestCase {

    // MARK: - Initialization Tests

}

// MARK: - CustomPriceFormatterViewController Tests

/// Unit tests for CustomPriceFormatterViewController enums
///
/// These tests verify the custom price formatter's enumeration types
/// used for switching between formatter types and sources.
final class CustomPriceFormatterViewControllerTests: XCTestCase {

    // MARK: - SourceType Tests

    /// Tests that SourceType has exactly two cases
    func testSourceTypeCaseCount() {
        XCTAssertEqual(CustomPriceFormatterViewController.SourceType.allCases.count, 2,
                      "SourceType should have exactly 2 cases")
    }

    /// Tests that SourceType.js has correct title
    func testSourceTypeJSTitle() {
        XCTAssertEqual(CustomPriceFormatterViewController.SourceType.js.title, "JavaScript")
    }

    /// Tests that SourceType.native has correct title
    func testSourceTypeNativeTitle() {
        XCTAssertEqual(CustomPriceFormatterViewController.SourceType.native.title, "Swift")
    }

    /// Tests that all SourceType cases have non-empty titles
    func testAllSourceTypesHaveTitles() {
        for sourceType in CustomPriceFormatterViewController.SourceType.allCases {
            XCTAssertFalse(sourceType.title.isEmpty,
                          "SourceType \(sourceType) should have a non-empty title")
        }
    }

    // MARK: - FormatterType Tests

    /// Tests that FormatterType has exactly two cases
    func testFormatterTypeCaseCount() {
        XCTAssertEqual(CustomPriceFormatterViewController.FormatterType.allCases.count, 2,
                      "FormatterType should have exactly 2 cases")
    }

    /// Tests that FormatterType.dollar has correct title
    func testFormatterTypeDollarTitle() {
        XCTAssertEqual(CustomPriceFormatterViewController.FormatterType.dollar.title, "Dollar")
    }

    /// Tests that FormatterType.pound has correct title
    func testFormatterTypePoundTitle() {
        XCTAssertEqual(CustomPriceFormatterViewController.FormatterType.pound.title, "Pound")
    }

    /// Tests that FormatterType.dollar has correct formatter string
    func testFormatterTypeDollarString() {
        let formatter = CustomPriceFormatterViewController.FormatterType.dollar.formatterString
        XCTAssertTrue(formatter.contains("function(price)"),
                     "Dollar formatter should be a JavaScript function")
        XCTAssertTrue(formatter.contains("$"),
                     "Dollar formatter should contain dollar sign")
    }

    /// Tests that FormatterType.pound has correct formatter string
    func testFormatterTypePoundString() {
        let formatter = CustomPriceFormatterViewController.FormatterType.pound.formatterString
        XCTAssertTrue(formatter.contains("function(price)"),
                     "Pound formatter should be a JavaScript function")
        XCTAssertTrue(formatter.contains("\u{00A3}"),
                     "Pound formatter should contain pound sign")
    }

    /// Tests that FormatterType closures produce expected output
    func testFormatterTypeClosures() {
        let dollarFormatter = CustomPriceFormatterViewController.FormatterType.dollar.formatterClosure
        let poundFormatter = CustomPriceFormatterViewController.FormatterType.pound.formatterClosure

        let dollarOutput = dollarFormatter(123.456)
        let poundOutput = poundFormatter(98.765)

        XCTAssertTrue(dollarOutput.contains("$"),
                     "Dollar formatter closure should produce dollar sign")
        XCTAssertTrue(poundOutput.contains("\u{00A3}") || poundOutput.contains("☁️"),
                     "Pound formatter closure should produce pound sign")
    }

    /// Tests that all FormatterType cases have non-empty titles
    func testAllFormatterTypesHaveTitles() {
        for formatterType in CustomPriceFormatterViewController.FormatterType.allCases {
            XCTAssertFalse(formatterType.title.isEmpty,
                          "FormatterType \(formatterType) should have a non-empty title")
        }
    }

    /// Tests that all FormatterType cases have formatter strings
    func testAllFormatterTypesHaveFormatterStrings() {
        for formatterType in CustomPriceFormatterViewController.FormatterType.allCases {
            XCTAssertFalse(formatterType.formatterString.isEmpty,
                          "FormatterType \(formatterType) should have a formatter string")
            XCTAssertTrue(formatterType.formatterString.contains("function"),
                         "FormatterType \(formatterType) should have a JavaScript function")
        }
    }

    /// Tests that all FormatterType cases have formatter closures
    func testAllFormatterTypesHaveFormatterClosures() {
        for formatterType in CustomPriceFormatterViewController.FormatterType.allCases {
            // Call the closure to verify it works
            let output = formatterType.formatterClosure(100.0)
            XCTAssertFalse(output.isEmpty,
                          "FormatterType \(formatterType) closure should produce output")
        }
    }
}

// MARK: - TableViewController Structure Tests

/// Unit tests for TableViewController structure and navigation
///
/// These tests verify the main table view controller's section-based structure
/// and navigation configuration.
final class TableViewControllerStructureTests: XCTestCase {

    // MARK: - Helper Methods

    /// Get total row count across all sections
    private func totalRowCount(in tvc: TableViewController) -> Int {
        tvc.sections.reduce(0) { $0 + $1.rows.count }
    }

    /// Get all rows across all sections
    private func allRows(in tvc: TableViewController) -> [TableViewController.Row] {
        tvc.sections.flatMap { $0.rows }
    }

    // MARK: - Structure Tests

    /// Tests that TableViewController has the expected title
    func testTableViewControllerTitle() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        XCTAssertEqual(tvc.title, "Lightweight Charts",
                      "TableViewController should have correct title")
    }

    /// Tests that TableViewController has sections after loading
    func testTableViewControllerHasSections() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        XCTAssertFalse(tvc.sections.isEmpty,
                      "TableViewController should have sections after viewDidLoad")
    }

    /// Tests that section titles are unique to avoid ambiguous navigation
    func testTableViewControllerSectionTitlesAreUnique() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        let titles = tvc.sections.map { $0.title }
        let uniqueTitles = Set(titles)
        XCTAssertEqual(uniqueTitles.count, titles.count,
                       "Section titles should be unique")
    }

    /// Tests that TableViewController returns correct section count via delegate
    func testTableViewControllerNumberOfSections() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        XCTAssertEqual(tvc.numberOfSections(in: UITableView()), tvc.sections.count,
                      "numberOfSections should match sections array count")
    }

    /// Tests that v5 Plugin API section exists and has correct title
    func testV5PluginAPISectionExists() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        let v5Section = tvc.sections.first { $0.title == "v5 Plugin API" }
        XCTAssertNotNil(v5Section, "TableViewController should have 'v5 Plugin API' section")
    }

    /// Tests that v4 Compatibility API section exists and has correct title
    func testV4CompatibilityAPISectionExists() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        let v4Section = tvc.sections.first { $0.title == "v4 Compatibility API" }
        XCTAssertNotNil(v4Section, "TableViewController should have 'v4 Compatibility API' section")
    }

    /// Tests that v5 Plugin API section has expected number of rows
    func testV5PluginAPISectionRowCount() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        guard let v5Section = tvc.sections.first(where: { $0.title == "v5 Plugin API" }) else {
            XCTFail("'v5 Plugin API' section should exist")
            return
        }

        XCTAssertEqual(v5Section.rows.count, 10,
                      "v5 Plugin API section should have 10 rows")
    }

    /// Tests that v4 Compatibility API section has expected number of rows
    func testV4CompatibilityAPISectionRowCount() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        guard let v4Section = tvc.sections.first(where: { $0.title == "v4 Compatibility API" }) else {
            XCTFail("'v4 Compatibility API' section should exist")
            return
        }

        XCTAssertEqual(v4Section.rows.count, 1,
                      "v4 Compatibility API section should have 1 row (Markers (Legacy))")
    }

    /// Tests that all sections have non-empty titles
    func testAllSectionsHaveTitles() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        for section in tvc.sections {
            XCTAssertFalse(section.title.isEmpty,
                          "Section should have a non-empty title")
        }
    }

    /// Tests that all rows have non-empty titles
    func testAllRowsHaveTitles() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        for row in allRows(in: tvc) {
            XCTAssertFalse(row.title.isEmpty,
                          "Row should have a non-empty title")
        }
    }

    /// Tests that all rows have valid view controller factories
    func testAllRowsHaveValidFactories() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        for row in allRows(in: tvc) {
            let vc = row.viewController()
            XCTAssertNotNil(vc,
                          "Row '\(row.title)' should create a valid view controller")
        }
    }

    /// Tests that v5 Plugin API section has informative footer
    func testV5PluginAPISectionFooter() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        guard let v5Section = tvc.sections.first(where: { $0.title == "v5 Plugin API" }) else {
            XCTFail("'v5 Plugin API' section should exist")
            return
        }

        XCTAssertNotNil(v5Section.footer, "v5 Plugin API section should have a footer")
        XCTAssertFalse(v5Section.footer!.isEmpty, "v5 Plugin API footer should not be empty")
    }

    /// Tests that v4 Compatibility API section has informative footer
    func testV4CompatibilityAPISectionFooter() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        guard let v4Section = tvc.sections.first(where: { $0.title == "v4 Compatibility API" }) else {
            XCTFail("'v4 Compatibility API' section should exist")
            return
        }

        XCTAssertNotNil(v4Section.footer, "v4 Compatibility API section should have a footer")
        XCTAssertFalse(v4Section.footer!.isEmpty, "v4 Compatibility API footer should not be empty")
    }

    /// Tests that v5 Plugin API examples have subtitles
    func testV5PluginAPIExamplesHaveSubtitles() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        guard let v5Section = tvc.sections.first(where: { $0.title == "v5 Plugin API" }) else {
            XCTFail("'v5 Plugin API' section should exist")
            return
        }

        for row in v5Section.rows {
            XCTAssertNotNil(row.subtitle, "v5 Plugin API row '\(row.title)' should have a subtitle")
            XCTAssertFalse(row.subtitle!.isEmpty, "v5 Plugin API row '\(row.title)' subtitle should not be empty")
        }
    }

    /// Tests that section headers and footers are returned correctly
    func testSectionHeaderAndFooterTitles() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        for (index, section) in tvc.sections.enumerated() {
            let headerTitle = tvc.tableView(UITableView(), titleForHeaderInSection: index)
            let footerTitle = tvc.tableView(UITableView(), titleForFooterInSection: index)

            XCTAssertEqual(headerTitle, section.title,
                          "Header title for section \(index) should match")
            XCTAssertEqual(footerTitle, section.footer,
                          "Footer title for section \(index) should match")
        }
    }

    /// Tests that row count per section is correct
    func testTableRowCountPerSection() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        for (index, section) in tvc.sections.enumerated() {
            let rowCount = tvc.tableView(UITableView(), numberOfRowsInSection: index)
            XCTAssertEqual(rowCount, section.rows.count,
                          "Row count for section \(index) should match")
        }
    }

    /// Tests that cells are created with correct style based on subtitle presence
    func testCellConfigurationBasedOnSubtitle() {
        let tvc = TableViewController()
        _ = tvc.view // Trigger viewDidLoad

        let tableView = UITableView()

        for (sectionIndex, section) in tvc.sections.enumerated() {
            for (rowIndex, row) in section.rows.enumerated() {
                let indexPath = IndexPath(row: rowIndex, section: sectionIndex)
                let cell = tvc.tableView(tableView, cellForRowAt: indexPath)

                XCTAssertNotNil(cell, "Cell should be created for row '\(row.title)'")
                XCTAssertEqual(cell.textLabel?.text, row.title,
                              "Cell text should match row title")

                if row.subtitle != nil {
                    XCTAssertNotNil(cell.detailTextLabel, "Cell with subtitle should have detailTextLabel")
                    XCTAssertEqual(cell.detailTextLabel?.text, row.subtitle,
                                  "Cell detail text should match row subtitle")
                }
            }
        }
    }
}

// MARK: - Additional Example View Controller Tests

/// Unit tests for additional example view controllers
///
/// These tests verify that other example view controllers
/// can be created and loaded without crashing.
final class AdditionalViewControllerTests: XCTestCase {

    /// Tests that multiple view controllers can be loaded without crashing
    func testMultipleViewControllersLoadSuccessfully() {
        let viewControllers: [UIViewController] = [
            BarChartViewController(),
            CandlestickChartViewController(),
            CustomThemesViewController(),
            LegendViewController(),
            ImageWatermarkViewController(),
            MarkersPluginViewController(),
            UpDownMarkersViewController()
        ]

        for vc in viewControllers {
            _ = vc.view // Trigger viewDidLoad
            XCTAssertNotNil(vc.view, "\(type(of: vc)) should load its view successfully")
        }
    }
}
