import UIKit
import LightweightCharts

final class AsyncAPIViewController: UIViewController {

    private var chart: LightweightCharts!
    private var series: LineSeries?
    private var priceLine: PriceLine?
    private var snapshotTask: Task<Void, Never>?
    private var crosshairTask: Task<Void, Never>?
    private var clickTask: Task<Void, Never>?
    private var clickCount = 0

    private let summaryLabel = UILabel()
    private let eventLabel = UILabel()

    deinit {
        snapshotTask?.cancel()
        crosshairTask?.cancel()
        clickTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        let chartOptions = ChartOptions(
            layout: LayoutOptions(
                background: .solid(color: "#ffffff"),
                textColor: "#222222"
            ),
            rightPriceScale: VisiblePriceScaleOptions(borderVisible: false),
            timeScale: TimeScaleOptions(borderVisible: false)
        )

        let chart = LightweightCharts(options: chartOptions, loadDelegate: self)
        chart.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chart)
        self.chart = chart

        summaryLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        summaryLabel.numberOfLines = 0
        summaryLabel.text = "Loading async snapshot..."
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false

        eventLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        eventLabel.numberOfLines = 0
        eventLabel.text = "Move the crosshair or tap the chart"
        eventLabel.translatesAutoresizingMaskIntoConstraints = false

        let refreshButton = UIButton(type: .system)
        refreshButton.setTitle("Refresh Async Snapshot", for: .normal)
        refreshButton.addTarget(self, action: #selector(refreshSnapshotTapped), for: .touchUpInside)

        let fitButton = UIButton(type: .system)
        fitButton.setTitle("Fit Content", for: .normal)
        fitButton.addTarget(self, action: #selector(fitContentTapped), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [refreshButton, fitButton])
        buttons.axis = .horizontal
        buttons.spacing = 12
        buttons.distribution = .fillEqually
        buttons.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(summaryLabel)
        view.addSubview(eventLabel)
        view.addSubview(buttons)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            chart.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            chart.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            chart.topAnchor.constraint(equalTo: guide.topAnchor),
            chart.bottomAnchor.constraint(equalTo: summaryLabel.topAnchor, constant: -12),

            summaryLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            summaryLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            summaryLabel.bottomAnchor.constraint(equalTo: eventLabel.topAnchor, constant: -8),

            eventLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            eventLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            eventLabel.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -8),

            buttons.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            buttons.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            buttons.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8),
            buttons.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func configureSeries() {
        let lineSeries = chart.addLineSeries(
            options: LineSeriesOptions(
                color: "#0b6e4f",
                lineWidth: .three,
                lastPriceAnimation: .continuous
            )
        )

        let data: [LineData] = [
            LineData(time: .string("2024-01-02"), value: 101.2),
            LineData(time: .string("2024-01-03"), value: 102.8),
            LineData(time: .string("2024-01-04"), value: 100.9),
            LineData(time: .string("2024-01-05"), value: 104.4),
            LineData(time: .string("2024-01-08"), value: 106.1),
            LineData(time: .string("2024-01-09"), value: 105.6),
            LineData(time: .string("2024-01-10"), value: 107.9)
        ]

        lineSeries.setData(data: data)
        priceLine = lineSeries.createPriceLine(
            options: PriceLineOptions(
                price: 103.5,
                color: ChartColor(UIColor.systemRed),
                lineWidth: .two,
                title: "Alert"
            )
        )
        chart.timeScale().fitContent()
        series = lineSeries
    }

    private func startEventStreams() {
        crosshairTask?.cancel()
        clickTask?.cancel()

        crosshairTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await event in self.chart.crosshairMoveEvents {
                self.eventLabel.text = self.crosshairText(for: event)
            }
        }

        clickTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await event in self.chart.clickEvents {
                self.clickCount += 1
                self.eventLabel.text = "click #\(self.clickCount) at \(self.timeText(for: event.time))"
            }
        }
    }

    private func refreshSnapshot() {
        snapshotTask?.cancel()
        snapshotTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                var snapshotLines: [String] = []

                if let series = self.series {
                    let lastValue = try await series.lastValueData(globalLast: true)
                    let formatter = series.priceFormatter()
                    let formattedLastValue = try await formatter.format(price: lastValue.price ?? 0)
                    let priceLines = try await series.priceLines()

                    snapshotLines.append("last value: \(formattedLastValue)")
                    snapshotLines.append("price lines: \(priceLines.count)")

                    if let priceLine = self.priceLine {
                        let priceLineOptions = try await priceLine.options()
                        snapshotLines.append("price line: \(priceLineOptions.title ?? "n/a") @ \(priceLineOptions.price ?? 0)")
                    }
                }

                self.summaryLabel.text = snapshotLines.joined(separator: "\n")
            } catch is CancellationError {
            } catch {
                self.summaryLabel.text = "async read failed: \(error.localizedDescription)"
            }
        }
    }

    private func crosshairText(for event: MouseEventParams) -> String {
        var fragments: [String] = []
        fragments.append("crosshair at \(timeText(for: event.time))")
        if let point = event.point {
            fragments.append("x: \(Int(point.x)) y: \(Int(point.y))")
        }
        if let series, case let .lineData(price) = event.price(forSeries: series), let value = price.value {
            fragments.append(String(format: "price: %.2f", value))
        }
        return fragments.joined(separator: "\n")
    }

    private func timeText(for time: EventTime?) -> String {
        switch time {
        case .utc(let timestamp):
            return String(Int(timestamp))
        case .businessDay(let day):
            return "\(day.year)-\(day.month)-\(day.day)"
        case .businessDayString(let value):
            return value
        case nil:
            return "n/a"
        }
    }

    private func timeText(for time: Time?) -> String {
        guard let time else {
            return "n/a"
        }
        return timeText(for: time)
    }

    private func timeText(for time: Time) -> String {
        switch time {
        case .utc(let timestamp):
            return String(Int(timestamp))
        case .businessDay(let day):
            return "\(day.year)-\(day.month)-\(day.day)"
        case .string(let value):
            return value
        }
    }

    @objc private func refreshSnapshotTapped() {
        refreshSnapshot()
    }

    @objc private func fitContentTapped() {
        chart.timeScale().fitContent()
        refreshSnapshot()
    }
}

extension AsyncAPIViewController: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        configureSeries()
        startEventStreams()
        refreshSnapshot()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        summaryLabel.text = "chart load failed: \(error.localizedDescription)"
    }
}
