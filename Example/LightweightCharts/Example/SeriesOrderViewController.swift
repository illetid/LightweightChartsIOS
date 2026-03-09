import UIKit
import LightweightCharts

class SeriesOrderViewController: UIViewController {

    private var chart: LightweightCharts!
    private var lineSeries: LineSeries!
    private var areaSeries: AreaSeries!
    private var baselineSeries: BaselineSeries!
    private let statusLabel = UILabel()
    private var orderPhase = 0

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
        let toggleButton = UIButton(type: .system)
        toggleButton.setTitle("Cycle Series Order", for: .normal)
        toggleButton.addTarget(self, action: #selector(toggleOrder), for: .touchUpInside)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toggleButton)

        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = .secondaryLabel
        statusLabel.text = "Orders: -"
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        let chart = LightweightCharts()
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
                statusLabel.bottomAnchor.constraint(equalTo: toggleButton.topAnchor, constant: -8),

                toggleButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                toggleButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
                toggleButton.heightAnchor.constraint(equalToConstant: 44)
            ])
        } else {
            NSLayoutConstraint.activate([
                chart.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                chart.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                chart.topAnchor.constraint(equalTo: view.topAnchor),
                chart.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),

                statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
                statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
                statusLabel.bottomAnchor.constraint(equalTo: toggleButton.topAnchor, constant: -8),

                toggleButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                toggleButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
                toggleButton.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
        self.chart = chart
    }

    private func setupData() {
        let lineOptions = LineSeriesOptions(color: "rgba(255, 0, 0, 1)", lineWidth: .three)
        let lineSeries = chart.addLineSeries(options: lineOptions)

        let areaOptions = AreaSeriesOptions(
            topColor: "rgba(38, 198, 218, 0.56)",
            bottomColor: "rgba(38, 198, 218, 0.04)",
            lineColor: "rgba(38, 198, 218, 1)",
            lineWidth: .two
        )
        let areaSeries = chart.addAreaSeries(options: areaOptions)

        let baselineOptions = BaselineSeriesOptions(
            baseValue: .baseValuePrice(BaseValuePrice(price: 55, type: .price)),
            topFillColor1: "rgba(255, 193, 7, 0.25)",
            topFillColor2: "rgba(255, 193, 7, 0.05)",
            topLineColor: "rgba(255, 193, 7, 1)",
            bottomFillColor1: "rgba(255, 87, 34, 0.20)",
            bottomFillColor2: "rgba(255, 87, 34, 0.04)",
            bottomLineColor: "rgba(255, 87, 34, 1)",
            lineWidth: .two
        )
        let baselineSeries = chart.addBaselineSeries(options: baselineOptions)

        var lineData: [LineData] = []
        var areaData: [AreaData] = []
        var baselineData: [BaselineData] = []
        var timestamp: TimeInterval = 1539907200 // 2018-10-19
        for i in 0..<30 {
            let time: Time = .utc(timestamp: timestamp)
            // Keep all 3 series in similar value range so they overlap often,
            // but use different wave components so they are not fully identical.
            let x = Double(i)
            let lineValue = 55.0 + sin(x * 0.45) * 2.4 + cos(x * 0.15) * 0.8
            let areaValue = 55.2 + cos(x * 0.43 + 0.7) * 2.1 + sin(x * 0.18) * 0.7
            let baselineValue = 54.8 + sin(x * 0.41 + 1.2) * 2.2 + cos(x * 0.14 + 0.4) * 0.9

            lineData.append(LineData(time: time, value: lineValue))
            areaData.append(AreaData(time: time, value: areaValue))
            baselineData.append(BaselineData(time: time, value: baselineValue))
            timestamp += 86400 // next day
        }
        lineSeries.setData(data: lineData)
        areaSeries.setData(data: areaData)
        baselineSeries.setData(data: baselineData)

        self.lineSeries = lineSeries
        self.areaSeries = areaSeries
        self.baselineSeries = baselineSeries

        // Initial order: line (bottom), area (middle), baseline (top)
        lineSeries.setSeriesOrder(order: 0)
        areaSeries.setSeriesOrder(order: 1)
        baselineSeries.setSeriesOrder(order: 2)
        refreshOrderStatus()
    }

    @objc private func toggleOrder() {
        // Rotate top series across 3 permutations so the z-order effect is obvious.
        switch orderPhase {
        case 0:
            // area top
            lineSeries.setSeriesOrder(order: 0)
            baselineSeries.setSeriesOrder(order: 1)
            areaSeries.setSeriesOrder(order: 2)
        case 1:
            // line top
            baselineSeries.setSeriesOrder(order: 0)
            areaSeries.setSeriesOrder(order: 1)
            lineSeries.setSeriesOrder(order: 2)
        default:
            // baseline top
            lineSeries.setSeriesOrder(order: 0)
            areaSeries.setSeriesOrder(order: 1)
            baselineSeries.setSeriesOrder(order: 2)
        }
        orderPhase = (orderPhase + 1) % 3
        refreshOrderStatus()
    }

    private func refreshOrderStatus() {
        lineSeries.seriesOrder { [weak self] lineOrder in
            self?.areaSeries.seriesOrder { [weak self] areaOrder in
                self?.baselineSeries.seriesOrder { [weak self] baselineOrder in
                    DispatchQueue.main.async {
                        self?.statusLabel.text = "Orders: L=\(lineOrder ?? -1), A=\(areaOrder ?? -1), B=\(baselineOrder ?? -1)"
                    }
                }
            }
        }
    }
}
