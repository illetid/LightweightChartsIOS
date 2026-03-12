import UIKit
import LightweightCharts

/// Demonstrates the v5 UpDownMarkers plugin API.
///
/// The UpDownMarkers plugin displays directional markers on a series indicating
/// upward or downward price movements. This plugin is only supported on LineSeries
/// and AreaSeries.
///
/// This example shows:
/// - Creating an up-down markers plugin with custom options
/// - Setting initial marker data
/// - Updating individual markers
/// - Clearing all markers
class UpDownMarkersViewController: UIViewController {

    private var chart: LightweightCharts!
    private var series: LineSeries!
    private var upDownMarkersPlugin: UpDownMarkersPlugin<LineSeries>!

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

    private func generateData() -> [LineData] {
        var time = DateComponents(calendar: .current, year: 2024, month: 1, day: 1).date!
        var data: [LineData] = []
        var value = 100.0

        for _ in 0..<100 {
            time = Date(timeInterval: 60 * 60 * 24, since: time)
            let change = Double.random(in: -5...5)
            value += change

            let lineData = LineData(
                time: .utc(timestamp: time.timeIntervalSince1970),
                value: value
            )
            data.append(lineData)
        }
        return data
    }

    private func generateUpDownMarkers(from data: [LineData]) -> [SeriesUpDownMarker] {
        var markers: [SeriesUpDownMarker] = []
        let strideStep = 10

        for i in stride(from: 5, to: data.count, by: strideStep) {
            let item = data[i]
            let sign: MarkerSign
            if i > 0, let value = item.value, let previousValue = data[i - 1].value {
                if value > previousValue {
                    sign = .positive
                } else if value < previousValue {
                    sign = .negative
                } else {
                    sign = .neutral
                }
            } else {
                sign = .neutral
            }

            let marker = SeriesUpDownMarker(
                time: item.time,
                value: item.value ?? 0,
                sign: sign
            )
            markers.append(marker)
        }
        return markers
    }
}

// MARK: - LightweightChartsDelegate
extension UpDownMarkersViewController: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        let data = generateData()

        let series = chart.addLineSeries(options: nil)
        self.series = series
        
        // Create the UpDownMarkers plugin with custom options
        let options = UpDownMarkersOptions(
            positiveColor: .solid(.green),
            negativeColor: .solid(.red),
            updateVisibilityDuration: 2000
        )
        upDownMarkersPlugin = series.createUpDownMarkersPlugin(options: options)
        
        // Track the data through the plugin (which also sets it on the series)
        upDownMarkersPlugin.setData(data)

        // Example: Update the last value after a delay to trigger an automatic marker
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            if let lastData = data.last, let value = lastData.value {
                let updatedData = LineData(
                    time: lastData.time,
                    value: value + 10
                )
                // The plugin calculates the sign by comparing value + 10 with the previous value
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    try? await self.upDownMarkersPlugin.update(updatedData, isUpdate: true)
                }
            }
        }
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        // Handle error
    }

}
