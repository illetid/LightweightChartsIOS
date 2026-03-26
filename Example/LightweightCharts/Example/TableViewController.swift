import UIKit

class TableViewController: UITableViewController {

    struct Section {
        let title: String
        let footer: String?
        let rows: [Row]
    }

    struct Row {
        let title: String
        let subtitle: String?
        let viewController: () -> UIViewController
    }

    var sections: [Section] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        setupInitialState()
        fillSections()
    }

    private func setupInitialState() {
        title = "Lightweight Charts"
        navigationController?.navigationBar.isTranslucent = false
        self.clearsSelectionOnViewWillAppear = true
    }

    private func fillSections() {
        sections = [
            // MARK: - v5 Plugin API Examples
            Section(
                title: "v5 Plugin API",
                footer: "New v5 plugin API examples. Use these for new code.",
                rows: [
                    Row(title: "Async API", subtitle: "Async reads, stream events, scale snapshots, screenshots", viewController: { AsyncAPIViewController() }),
                    Row(title: "Text Watermark", subtitle: "Text watermark plugin", viewController: { CustomWatermarkViewController() }),
                    Row(title: "Image Watermark", subtitle: "Image watermark plugin", viewController: { ImageWatermarkViewController() }),
                    Row(title: "Markers Plugin", subtitle: "Explicit markers plugin API", viewController: { MarkersPluginViewController() }),
                    Row(title: "Up-Down Markers Plugin", subtitle: "Directional markers plugin", viewController: { UpDownMarkersViewController() }),
                    Row(title: "Multiple Panes", subtitle: "Candlestick + volume, pane add/remove/swap, live pane inspection", viewController: { MultiplePanesViewController() }),
                    Row(title: "Price-Positioned Markers", subtitle: "Markers at exact price levels", viewController: { PricePositionedMarkersViewController() }),
                    Row(title: "Series Order", subtitle: "Toggle rendering order of overlapping series", viewController: { SeriesOrderViewController() }),
                    Row(title: "Price Scale Range", subtitle: "Set/get visible price range, auto-scale", viewController: { PriceScaleRangeViewController() }),
                    Row(title: "Data Conflation", subtitle: "Toggle conflation on large dataset (15K points)", viewController: { DataConflationViewController() }),
                    Row(title: "Pane Sizing", subtitle: "Stretch factor & height control for panes", viewController: { PaneSizingViewController() }),
                ]
            ),

            // MARK: - v4 Compatibility API Examples
            Section(
                title: "v4 Compatibility API",
                footer: "Backward-compatible v4 API. Existing code continues to work without changes.",
                rows: [
                    Row(title: "Markers (Legacy)", subtitle: "Backward-compatible setMarkers API", viewController: { MarkersViewController() }),
                ]
            ),

            // MARK: - Core Chart Examples
            Section(
                title: "Core Charts",
                footer: nil,
                rows: [
                    Row(title: "Bar chart", subtitle: nil, viewController: { BarChartViewController() }),
                    Row(title: "Candlestick chart", subtitle: nil, viewController: { CandlestickChartViewController() }),
                ]
            ),

            // MARK: - Customization Examples
            Section(
                title: "Customization",
                footer: nil,
                rows: [
                    Row(title: "Custom font family", subtitle: nil, viewController: { CustomFontFamilyViewController() }),
                    Row(title: "Custom price formatter", subtitle: nil, viewController: { CustomPriceFormatterViewController() }),
                    Row(title: "Custom locale", subtitle: nil, viewController: { CustomLocaleViewController() }),
                    Row(title: "Custom themes", subtitle: "Disables attribution logo (review NOTICE/license obligations)", viewController: { CustomThemesViewController() }),
                ]
            ),

            // MARK: - Price Scale Examples
            Section(
                title: "Price Scale",
                footer: nil,
                rows: [
                    Row(title: "Percentage price scale", subtitle: nil, viewController: { PercentagePriceScaleViewController() }),
                    Row(title: "Inverted price scale", subtitle: nil, viewController: { InvertedPriceScaleViewController() }),
                    Row(title: "Logarithmic price scale", subtitle: nil, viewController: { LogarithmicPriceScaleViewController() }),
                    Row(title: "No price scale", subtitle: nil, viewController: { NoPriceScaleViewController() }),
                    Row(title: "Price scale at left", subtitle: nil, viewController: { PriceScaleAtLeftViewController() }),
                ]
            ),

            // MARK: - Legend Examples
            Section(
                title: "Legend",
                footer: nil,
                rows: [
                    Row(title: "Legend", subtitle: nil, viewController: { LegendViewController() }),
                    Row(title: "3-line legend", subtitle: nil, viewController: { ThreeLineLegendViewController() }),
                ]
            ),

            // MARK: - Tooltip Examples
            Section(
                title: "Tooltips",
                footer: nil,
                rows: [
                    Row(title: "Floating tooltip", subtitle: nil, viewController: { FloatingTooltipViewController() }),
                    Row(title: "Tracking tooltip", subtitle: nil, viewController: { TrackingTooltipViewController() }),
                    Row(title: "Magnifier tooltip", subtitle: nil, viewController: { MagnifierTooltipViewController() }),
                ]
            ),

            // MARK: - Interaction Examples
            Section(
                title: "Interaction",
                footer: nil,
                rows: [
                    Row(title: "Fit content", subtitle: nil, viewController: { FitContentViewController() }),
                    Row(title: "Go to realtime button", subtitle: nil, viewController: { GoToRealtimeButtonViewController() }),
                    Row(title: "Range switcher", subtitle: nil, viewController: { RangeSwitcherViewController() }),
                    Row(title: "Realtime emulation", subtitle: nil, viewController: { RealtimeEmulationViewController() }),
                    Row(title: "Intraday data", subtitle: nil, viewController: { IntradayDataViewController() }),
                ]
            ),

            // MARK: - Scale Options
            Section(
                title: "Scale Options",
                footer: nil,
                rows: [
                    Row(title: "No time scale", subtitle: nil, viewController: { NoTimeScaleViewController() }),
                ]
            ),

            // MARK: - Price Lines
            Section(
                title: "Price Lines",
                footer: nil,
                rows: [
                    Row(title: "Price line", subtitle: nil, viewController: { PriceLineViewController() }),
                    Row(title: "Add and remove price line", subtitle: nil, viewController: { AddAndRemovePriceLineViewController() }),
                ]
            ),

            // MARK: - Studies
            Section(
                title: "Studies",
                footer: nil,
                rows: [
                    Row(title: "Volume study", subtitle: nil, viewController: { VolumeStudyViewController() }),
                ]
            ),
        ]
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]

        // Use subtitle cell style for rows with subtitles, default style otherwise
        let cell: UITableViewCell
        if let subtitle = row.subtitle {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "subtitleCell")
            cell.textLabel?.text = row.title
            cell.detailTextLabel?.text = subtitle
            cell.detailTextLabel?.textColor = .secondaryLabel
        } else {
            cell = UITableViewCell(style: .default, reuseIdentifier: "defaultCell")
            cell.textLabel?.text = row.title
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = sections[indexPath.section].rows[indexPath.row]
        let vc = row.viewController()
        vc.title = row.title
        self.navigationController?.pushViewController(vc, animated: true)
    }

}
