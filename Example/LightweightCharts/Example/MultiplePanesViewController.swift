import UIKit
import LightweightCharts

/// Example demonstrating multiple panes with v5 API.
///
/// Shows a candlestick chart on the main pane (pane 0) and a volume histogram
/// on a separate pane (pane 1), mimicking a typical trading chart layout.
/// The secondary pane also includes a text watermark to demonstrate that
/// watermark plugins can target panes other than the main pane, and the example
/// exposes controls for adding/removing/swapping panes and moving a series
/// between panes at runtime.
class MultiplePanesViewController: UIViewController {

    private var chart: LightweightCharts!
    private var candlestickSeries: CandlestickSeries!
    private var volumeSeries: HistogramSeries!
    private var volumePaneWatermark: TextWatermarkPlugin<Chart>?
    private var controlsStackView: UIStackView!
    private let statusLabel = UILabel()
    private let volumeWatermarkOptions = TextWatermarkOptions(
        horizontalAlignment: .right,
        verticalAlignment: .top,
        lines: [
            WatermarkLine(
                text: "Volume Pane",
                color: "rgba(209, 212, 220, 0.45)",
                fontSize: 18,
                fontFamily: "-apple-system",
                fontStyle: "normal"
            )
        ]
    )

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
        let addButton = UIButton(type: .system)
        addButton.setTitle("Add Pane", for: .normal)
        addButton.addTarget(self, action: #selector(addPaneTapped), for: .touchUpInside)

        let removeButton = UIButton(type: .system)
        removeButton.setTitle("Remove Last Pane", for: .normal)
        removeButton.addTarget(self, action: #selector(removePaneTapped), for: .touchUpInside)

        let swapButton = UIButton(type: .system)
        swapButton.setTitle("Swap 0 ↔ 1", for: .normal)
        swapButton.addTarget(self, action: #selector(swapPanesTapped), for: .touchUpInside)

        let inspectButton = UIButton(type: .system)
        inspectButton.setTitle("Inspect Panes", for: .normal)
        inspectButton.addTarget(self, action: #selector(inspectPanesTapped), for: .touchUpInside)

        let moveVolumeButton = UIButton(type: .system)
        moveVolumeButton.setTitle("Move Volume 0 ↔ 1", for: .normal)
        moveVolumeButton.addTarget(self, action: #selector(moveVolumeTapped), for: .touchUpInside)

        let topRow = UIStackView(arrangedSubviews: [addButton, removeButton])
        topRow.axis = .horizontal
        topRow.distribution = .fillEqually
        topRow.spacing = 8

        let middleRow = UIStackView(arrangedSubviews: [swapButton, inspectButton])
        middleRow.axis = .horizontal
        middleRow.distribution = .fillEqually
        middleRow.spacing = 8

        let bottomRow = UIStackView(arrangedSubviews: [moveVolumeButton])
        bottomRow.axis = .horizontal
        bottomRow.distribution = .fillEqually
        bottomRow.spacing = 8

        let controlsStackView = UIStackView(arrangedSubviews: [topRow, middleRow, bottomRow])
        controlsStackView.axis = .vertical
        controlsStackView.spacing = 8
        controlsStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsStackView)
        self.controlsStackView = controlsStackView

        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.text = "Panes: loading..."
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        let options = ChartOptions(
            layout: LayoutOptions(background: .solid(color: "#131722"), textColor: "#d1d4dc"),
            leftPriceScale: VisiblePriceScaleOptions(
                borderVisible: false,
                visible: true
            ),
            rightPriceScale: VisiblePriceScaleOptions(
                scaleMargins: PriceScaleMargins(top: 0.1, bottom: 0.1),
                borderVisible: false
            ),
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
                chart.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),

                statusLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
                statusLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
                statusLabel.bottomAnchor.constraint(equalTo: controlsStackView.topAnchor, constant: -8),

                controlsStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
                controlsStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
                controlsStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
                controlsStackView.heightAnchor.constraint(equalToConstant: 144)
            ])
        } else {
            NSLayoutConstraint.activate([
                chart.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                chart.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                chart.topAnchor.constraint(equalTo: view.topAnchor),
                chart.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),

                statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
                statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
                statusLabel.bottomAnchor.constraint(equalTo: controlsStackView.topAnchor, constant: -8),

                controlsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
                controlsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
                controlsStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
                controlsStackView.heightAnchor.constraint(equalToConstant: 144)
            ])
        }
        self.chart = chart
    }

    private func setupData() {
        // MARK: - Pane 0: Candlestick series (main pane)
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
            CandlestickData(time: .string("2018-11-30"), open: 59.78, high: 60.54, low: 59.53, close: 60.30),
        ]
        candlestickSeries.setData(data: candlestickData)
        self.candlestickSeries = candlestickSeries

        // MARK: - Pane 1: Histogram volume series (separate pane)
        // Adding a series to paneIndex: 1 automatically creates the second pane
        let volumeOptions = HistogramSeriesOptions(
            priceScaleId: "left",
            priceLineVisible: false,
            priceFormat: .builtIn(BuiltInPriceFormat(type: .volume, precision: nil, minMove: nil)),
            color: "#26a69a"
        )
        let volumeSeries = chart.addHistogramSeries(options: volumeOptions, paneIndex: 1)
        chart.priceScale(priceScaleId: "left", paneIndex: 1).applyOptions(
            options: PriceScaleOptions(borderVisible: false, visible: true)
        )

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
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-11-15"), value: 17_147_123),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-11-16"), value: 19_470_986),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-11-19"), value: 18_405_731),
            HistogramData(color: "rgba(239, 83, 80, 0.8)", time: .string("2018-11-20"), value: 22_028_957),
            HistogramData(color: "rgba(239, 83, 80, 0.8)", time: .string("2018-11-21"), value: 18_482_233),
            HistogramData(color: "rgba(239, 83, 80, 0.8)", time: .string("2018-11-23"), value: 7_009_050),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-11-26"), value: 12_308_876),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-11-27"), value: 14_118_867),
            HistogramData(color: "rgba(239, 83, 80, 0.8)", time: .string("2018-11-28"), value: 18_662_989),
            HistogramData(color: "rgba(239, 83, 80, 0.8)", time: .string("2018-11-29"), value: 14_763_658),
            HistogramData(color: "rgba(38, 198, 218, 0.8)", time: .string("2018-11-30"), value: 31_142_818),
        ]
        volumeSeries.setData(data: volumeData)
        self.volumeSeries = volumeSeries

        volumePaneWatermark = try? chart.createTextWatermarkPlugin(paneIndex: 1, options: volumeWatermarkOptions)
        refreshPaneStatus()
    }

    @objc private func addPaneTapped() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            _ = try? await self.chart.addPane()
            self.refreshPaneStatus()
        }
    }

    @objc private func removePaneTapped() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard let panes = try? await self.chart.panes() else { return }
            guard let lastPane = panes.last else { return }
            guard let liveIndex = try? await lastPane.paneIndex(), liveIndex > 0 else { return }
            try? await self.chart.removePane(index: liveIndex)
            self.refreshPaneStatus()
        }
    }

    @objc private func swapPanesTapped() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard let panes = try? await self.chart.panes(), panes.count > 1 else { return }
            try? await self.chart.swapPanes(first: 0, second: 1)
            self.refreshPaneStatus()
        }
    }

    @objc private func inspectPanesTapped() {
        refreshPaneStatus()
    }

    @objc private func moveVolumeTapped() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            do {
                let currentPane = try await self.volumeSeries.getPane()
                let currentIndex = try await currentPane.paneIndex()
                let targetIndex = currentIndex == 0 ? 1 : 0

                if targetIndex > 0 {
                    let panes = try await self.chart.panes()
                    if panes.count <= targetIndex {
                        _ = try await self.chart.addPane()
                    }
                }

                try await self.volumeSeries.moveToPane(paneIndex: targetIndex)
                self.recreateVolumeWatermark(onPane: targetIndex)
                self.refreshPaneStatus()
            } catch {
                self.statusLabel.text = "Panes: move failed"
            }
        }
    }

    private func refreshPaneStatus() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let panes = try await self.chart.panes()
                var details: [String] = []
                for pane in panes {
                    let current = try await pane.paneIndex()
                    details.append("pane \(current)")
                }
                self.statusLabel.text = "Panes: \(details.joined(separator: " | "))"
            } catch {
                self.statusLabel.text = "Panes: unavailable"
            }
        }
    }

    private func recreateVolumeWatermark(onPane paneIndex: Int) {
        volumePaneWatermark?.detach()
        volumePaneWatermark = try? chart.createTextWatermarkPlugin(paneIndex: paneIndex, options: volumeWatermarkOptions)
    }
}
