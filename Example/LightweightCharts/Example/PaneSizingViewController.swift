import UIKit
import LightweightCharts

class PaneSizingViewController: UIViewController {

    private var chart: LightweightCharts!
    private var candlestickSeries: CandlestickSeries!
    private var volumeSeries: HistogramSeries!
    private var infoLabel: UILabel!

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
        let infoLabel = UILabel()
        infoLabel.textAlignment = .center
        infoLabel.font = .systemFont(ofSize: 13)
        infoLabel.text = "Pane heights"
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)
        self.infoLabel = infoLabel

        let stretchButton = UIButton(type: .system)
        stretchButton.setTitle("Stretch 3:1", for: .normal)
        stretchButton.addTarget(self, action: #selector(setStretch), for: .touchUpInside)

        let equalButton = UIButton(type: .system)
        equalButton.setTitle("Equal", for: .normal)
        equalButton.addTarget(self, action: #selector(setEqual), for: .touchUpInside)

        let heightButton = UIButton(type: .system)
        heightButton.setTitle("Get Heights", for: .normal)
        heightButton.addTarget(self, action: #selector(getHeights), for: .touchUpInside)

        let controlsStack = UIStackView(arrangedSubviews: [stretchButton, equalButton, heightButton])
        controlsStack.axis = .horizontal
        controlsStack.distribution = .fillEqually
        controlsStack.spacing = 8
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsStack)

        let options = ChartOptions(
            layout: LayoutOptions(background: .solid(color: "#131722"), textColor: "#d1d4dc"),
            grid: GridOptions(
                verticalLines: GridLineOptions(color: "rgba(42, 46, 57, 0)"),
                horizontalLines: GridLineOptions(color: "rgba(42, 46, 57, 0.6)")
            )
        )
        let chart = LightweightCharts(options: options)
        view.addSubview(chart)
        chart.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 11.0, *) {
            NSLayoutConstraint.activate([
                chart.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                chart.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                chart.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                chart.bottomAnchor.constraint(equalTo: infoLabel.topAnchor, constant: -8),

                infoLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
                infoLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
                infoLabel.bottomAnchor.constraint(equalTo: controlsStack.topAnchor, constant: -4),

                controlsStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
                controlsStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
                controlsStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
                controlsStack.heightAnchor.constraint(equalToConstant: 44)
            ])
        } else {
            NSLayoutConstraint.activate([
                chart.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                chart.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                chart.topAnchor.constraint(equalTo: view.topAnchor),
                chart.bottomAnchor.constraint(equalTo: infoLabel.topAnchor, constant: -8),

                infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
                infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
                infoLabel.bottomAnchor.constraint(equalTo: controlsStack.topAnchor, constant: -4),

                controlsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
                controlsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
                controlsStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
                controlsStack.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
        self.chart = chart
    }

    private func setupData() {
        let candlestickOptions = CandlestickSeriesOptions(
            upColor: ChartColor("rgba(38, 198, 218, 1)"),
            downColor: ChartColor("rgba(239, 83, 80, 1)"),
            borderVisible: false,
            wickUpColor: ChartColor("rgba(38, 198, 218, 1)"),
            wickDownColor: ChartColor("rgba(239, 83, 80, 1)")
        )
        let candlestickSeries = chart.addCandlestickSeries(options: candlestickOptions)

        let candlestickData: [CandlestickData] = [
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
            CandlestickData(time: .string("2018-11-15"), open: 58.85, high: 59.09, low: 58.45, close: 59.08)
        ]
        candlestickSeries.setData(data: candlestickData)
        self.candlestickSeries = candlestickSeries

        let volumeOptions = HistogramSeriesOptions(
            priceLineVisible: false,
            priceFormat: .builtIn(BuiltInPriceFormat(type: .volume, precision: nil, minMove: nil)),
            color: "#26a69a"
        )
        let volumeSeries = chart.addHistogramSeries(options: volumeOptions, paneIndex: 1)

        let volumeData: [HistogramData] = [
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-10-19"), value: 19_103_293),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-10-22"), value: 21_737_523),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-10-23"), value: 29_328_713),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-10-24"), value: 37_435_638),
            HistogramData(color: "rgba(239, 83, 80, 0.8)", time: .string("2018-10-25"), value: 25_269_995),
            HistogramData(color: "rgba(239, 83, 80, 0.8)", time: .string("2018-10-26"), value: 24_973_311),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-10-29"), value: 22_103_692),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-10-30"), value: 25_231_199),
            HistogramData(color: "rgba(239, 83, 80, 0.8)", time: .string("2018-10-31"), value: 24_214_427),
            HistogramData(color: "rgba(239, 83, 80, 0.8)", time: .string("2018-11-01"), value: 22_533_201),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-11-02"), value: 14_734_412),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-11-05"), value: 12_733_842),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-11-06"), value: 12_371_207),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-11-07"), value: 14_891_287),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-11-08"), value: 12_482_392),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-11-09"), value: 17_365_762),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-11-12"), value: 13_236_769),
            HistogramData(color: "rgba(239, 83, 80, 0.8)", time: .string("2018-11-13"), value: 13_047_907),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-11-14"), value: 18_288_710),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-11-15"), value: 17_147_123)
        ]
        volumeSeries.setData(data: volumeData)
        self.volumeSeries = volumeSeries
    }

    @objc private func setStretch() {
        Task { @MainActor [weak self] in
            guard let panes = try? await self?.chart.panes() ?? [], panes.count >= 2 else { return }
            try? await panes[0].setStretchFactor(stretchFactor: 3.0)
            try? await panes[1].setStretchFactor(stretchFactor: 1.0)
            self?.infoLabel.text = "Stretch: pane0=3, pane1=1"
        }
    }

    @objc private func setEqual() {
        Task { @MainActor [weak self] in
            guard let panes = try? await self?.chart.panes() ?? [], panes.count >= 2 else { return }
            try? await panes[0].setStretchFactor(stretchFactor: 1.0)
            try? await panes[1].setStretchFactor(stretchFactor: 1.0)
            self?.infoLabel.text = "Stretch: equal"
        }
    }

    @objc private func getHeights() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard let panes = try? await chart.panes() else { return }

            var heights: [Int: Double] = [:]
            for pane in panes {
                if let paneIndex = try? await pane.paneIndex(), let height = try? await pane.getHeight() {
                    heights[paneIndex] = height
                }
            }

            let desc = heights.sorted(by: { $0.key < $1.key })
                .map { "pane\($0.key)=\(Int($0.value))px" }
                .joined(separator: ", ")
            self.infoLabel.text = desc
        }
    }
}
