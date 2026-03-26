import UIKit
import LightweightCharts

/// Demonstrates the v5 explicit markers plugin API.
///
/// This example uses the new `SeriesMarkersPlugin` API introduced in v5,
/// which provides explicit control over the plugin lifecycle and options.
///
/// The plugin is created using `series.createMarkersPlugin(data:options:)` and
/// can be controlled through the returned plugin instance, including:
/// - Setting new markers with `setMarkers(_:)`
/// - Reading current markers with `try await plugin.markers()` when needed
/// - Applying options with `applyOptions(options:)`
/// - Detaching the plugin with `detach()`
///
/// See `MarkersViewController` for an example of the backward-compatible
/// `series.setMarkers(data:)` API which internally uses this plugin.
class MarkersPluginViewController: UIViewController {

    private var chart: LightweightCharts!
    private var series: BarSeries!
    private var markersPlugin: SeriesMarkersPlugin<BarSeries>?

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }

        setupUI()
        chart.loadDelegate = self
    }

    private func setupUI() {
        let options = ChartOptions()
        let chart = LightweightCharts(options: options)
        view.addSubview(chart)
        chart.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 11.0, *) {
            NSLayoutConstraint.activate([
                chart.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                chart.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                chart.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                chart.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                chart.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                chart.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                chart.topAnchor.constraint(equalTo: view.topAnchor),
                chart.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        self.chart = chart
    }

    private func generateData() -> [BarData] {
        var time = DateComponents(calendar: .current, year: 2018, day: 0).date!
        var data: [BarData] = []
        for i in 0..<500 {
            time = Date(timeInterval: 60 * 60 * 24, since: time)
            let step = Double(i % 20) / 1000.0
            let base = Double(i) / 5.0
            let barData = BarData(
                time: .utc(timestamp: time.timeIntervalSince1970),
                open: base * (1 - step),
                high: base * (1 + 2 * step),
                low: base * (1 - 2 * step),
                close: base * (1 + step)
            )
            data.append(barData)
        }
        return data
    }

    private func generateMarkers(from data: [BarData]) -> [SeriesMarker] {
        return [
            SeriesMarker(time: data[data.count - 30].time, position: .belowBar, shape: .circle, color: ChartColor(UIColor.orange)),
            SeriesMarker(time: data[data.count - 30].time, position: .belowBar, shape: .circle, color: ChartColor(UIColor.yellow)),
            SeriesMarker(time: data[data.count - 30].time, position: .belowBar, shape: .circle, color: ChartColor(UIColor.green)),
            SeriesMarker(time: data[data.count - 20].time, position: .aboveBar, shape: .circle, color: ChartColor(UIColor.orange)),
            SeriesMarker(time: data[data.count - 20].time, position: .aboveBar, shape: .circle, color: ChartColor(UIColor.yellow)),
            SeriesMarker(time: data[data.count - 20].time, position: .aboveBar, shape: .circle, color: ChartColor(UIColor.green)),
            SeriesMarker(time: data[data.count - 15].time, position: .inBar, shape: .circle, color: ChartColor(UIColor.orange)),
            SeriesMarker(time: data[data.count - 10].time, position: .inBar, shape: .circle, color: ChartColor(UIColor.red))
        ]
    }
}

// MARK: - LightweightChartsDelegate
extension MarkersPluginViewController: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        let data = generateData()
        let markers = generateMarkers(from: data)

        let series = chart.addBarSeries(options: nil)
        self.series = series
        series.setData(data: data)

        // Use the v5 explicit plugin API to create a markers plugin
        let options = SeriesMarkersOptions(
            active: true,
            autoScale: true
        )
        markersPlugin = series.createMarkersPlugin(data: markers, options: options)
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        // Handle error
    }

}
