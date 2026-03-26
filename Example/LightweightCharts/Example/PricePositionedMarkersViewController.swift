import UIKit
import LightweightCharts

class PricePositionedMarkersViewController: UIViewController {

    private var chart: LightweightCharts!
    private var series: CandlestickSeries!

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }

        setupUI()
        setupData()
    }

    private func setupUI() {
        let chart = LightweightCharts()
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

    private func setupData() {
        let series = chart.addCandlestickSeries(options: nil)

        let data: [CandlestickData] = [
            CandlestickData(time: .string("2018-10-19"), open: 54.62, high: 55.50, low: 54.52, close: 54.90),
            CandlestickData(time: .string("2018-10-22"), open: 55.08, high: 55.27, low: 54.61, close: 54.98),
            CandlestickData(time: .string("2018-10-23"), open: 56.09, high: 57.47, low: 56.09, close: 57.21),
            CandlestickData(time: .string("2018-10-24"), open: 57.00, high: 58.44, low: 56.41, close: 57.42),
            CandlestickData(time: .string("2018-10-25"), open: 57.46, high: 57.63, low: 56.17, close: 56.43),
            CandlestickData(time: .string("2018-10-26"), open: 56.26, high: 56.62, low: 55.19, close: 55.51),
            CandlestickData(time: .string("2018-10-29"), open: 55.81, high: 57.15, low: 55.72, close: 56.48),
            CandlestickData(time: .string("2018-10-30"), open: 56.92, high: 58.80, low: 56.92, close: 58.18),
            CandlestickData(time: .string("2018-10-31"), open: 58.32, high: 58.32, low: 56.76, close: 57.09),
            CandlestickData(time: .string("2018-11-01"), open: 56.98, high: 57.28, low: 55.55, close: 56.05),
            CandlestickData(time: .string("2018-11-02"), open: 56.34, high: 57.08, low: 55.92, close: 56.63),
            CandlestickData(time: .string("2018-11-05"), open: 56.51, high: 57.45, low: 56.51, close: 57.21),
            CandlestickData(time: .string("2018-11-06"), open: 57.02, high: 57.35, low: 56.65, close: 57.21),
            CandlestickData(time: .string("2018-11-07"), open: 57.55, high: 57.78, low: 57.03, close: 57.65),
            CandlestickData(time: .string("2018-11-08"), open: 57.70, high: 58.44, low: 57.66, close: 58.27),
            CandlestickData(time: .string("2018-11-09"), open: 58.32, high: 59.20, low: 57.94, close: 58.46),
            CandlestickData(time: .string("2018-11-12"), open: 58.84, high: 59.40, low: 58.54, close: 58.72),
            CandlestickData(time: .string("2018-11-13"), open: 59.09, high: 59.14, low: 58.32, close: 58.66),
            CandlestickData(time: .string("2018-11-14"), open: 59.13, high: 59.32, low: 58.41, close: 58.94),
            CandlestickData(time: .string("2018-11-15"), open: 58.85, high: 59.09, low: 58.45, close: 59.08),
            CandlestickData(time: .string("2018-11-16"), open: 59.06, high: 60.39, low: 58.91, close: 60.21),
            CandlestickData(time: .string("2018-11-19"), open: 60.25, high: 61.32, low: 60.18, close: 60.62),
            CandlestickData(time: .string("2018-11-20"), open: 61.03, high: 61.58, low: 59.17, close: 59.46),
            CandlestickData(time: .string("2018-11-21"), open: 59.26, high: 59.90, low: 58.88, close: 59.16),
            CandlestickData(time: .string("2018-11-23"), open: 58.86, high: 59.00, low: 58.29, close: 58.64),
            CandlestickData(time: .string("2018-11-26"), open: 58.64, high: 59.79, low: 58.47, close: 59.17),
            CandlestickData(time: .string("2018-11-27"), open: 59.21, high: 60.70, low: 59.18, close: 60.65),
            CandlestickData(time: .string("2018-11-28"), open: 60.70, high: 60.73, low: 59.64, close: 60.06),
            CandlestickData(time: .string("2018-11-29"), open: 60.13, high: 60.15, low: 58.90, close: 59.45),
            CandlestickData(time: .string("2018-11-30"), open: 59.78, high: 60.54, low: 59.53, close: 60.30)
        ]
        series.setData(data: data)
        self.series = series

        // Price-positioned markers at exact Y-axis values
        let markers: [SeriesMarker] = [
            SeriesMarker(
                time: data[10].time,
                position: .atPriceTop,
                shape: .arrowDown,
                color: ChartColor(UIColor.red),
                text: "Sell @ 57.08",
                price: 57.08
            ),
            SeriesMarker(
                time: data[15].time,
                position: .atPriceBottom,
                shape: .arrowUp,
                color: ChartColor(UIColor.green),
                text: "Buy @ 57.94",
                price: 57.94
            ),
            SeriesMarker(
                time: data[22].time,
                position: .atPriceMiddle,
                shape: .circle,
                color: ChartColor(UIColor.blue),
                text: "Target @ 60.00",
                price: 60.00
            ),
            // Traditional bar-relative markers for comparison
            SeriesMarker(
                time: data[5].time,
                position: .aboveBar,
                shape: .arrowDown,
                color: ChartColor(UIColor.orange),
                text: "Above"
            ),
            SeriesMarker(
                time: data[25].time,
                position: .belowBar,
                shape: .arrowUp,
                color: ChartColor(UIColor.purple),
                text: "Below"
            )
        ]
        series.setMarkers(data: markers)
    }
}
