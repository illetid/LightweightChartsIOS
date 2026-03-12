import UIKit
import LightweightCharts

class PriceScaleRangeViewController: UIViewController {

    private var chart: LightweightCharts!
    private var series: LineSeries!
    private let statusLabel = UILabel()

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
        let setRangeButton = UIButton(type: .system)
        setRangeButton.setTitle("Set Range 56.8-57.8", for: .normal)
        setRangeButton.addTarget(self, action: #selector(setRange), for: .touchUpInside)

        let autoScaleButton = UIButton(type: .system)
        autoScaleButton.setTitle("Auto Scale", for: .normal)
        autoScaleButton.addTarget(self, action: #selector(autoScale), for: .touchUpInside)

        let getRangeButton = UIButton(type: .system)
        getRangeButton.setTitle("Show Range", for: .normal)
        getRangeButton.addTarget(self, action: #selector(getRange), for: .touchUpInside)

        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = .secondaryLabel
        statusLabel.text = "Range: auto"
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let controlsStack = UIStackView(arrangedSubviews: [setRangeButton, autoScaleButton, getRangeButton])
        controlsStack.axis = .horizontal
        controlsStack.distribution = .fillEqually
        controlsStack.spacing = 8
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsStack)
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
                statusLabel.bottomAnchor.constraint(equalTo: controlsStack.topAnchor, constant: -8),

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
                chart.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),

                statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
                statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
                statusLabel.bottomAnchor.constraint(equalTo: controlsStack.topAnchor, constant: -8),

                controlsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
                controlsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
                controlsStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
                controlsStack.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
        self.chart = chart
    }

    private func setupData() {
        let series = chart.addLineSeries(options: nil)
        var data: [LineData] = []
        var timestamp: TimeInterval = 1541030400 // 2018-11-01
        for i in 0..<30 {
            let value = 55.0 + sin(Double(i) * 0.4) * 4.0
            data.append(LineData(time: .utc(timestamp: timestamp), value: value))
            timestamp += 86400 // next day
        }
        series.setData(data: data)
        self.series = series
    }

    @objc private func setRange() {
        let priceScale = chart.priceScale(priceScaleId: "right")
        priceScale.setVisibleRange(from: 56.8, to: 57.8)
        statusLabel.text = "Range: manual 56.8-57.8"
    }

    @objc private func autoScale() {
        let priceScale = chart.priceScale(priceScaleId: "right")
        priceScale.setAutoScale(on: true)
        statusLabel.text = "Range: auto"
    }

    @objc private func getRange() {
        let priceScale = chart.priceScale(priceScaleId: "right")
        Task { @MainActor [weak self] in
            do {
                let range = try await priceScale.getVisibleRange()
                guard let range else {
                    self?.statusLabel.text = "Range: unavailable"
                    print("[PriceScaleRange] visible range is unavailable")
                    return
                }
                let text = String(format: "Range: %.4f-%.4f", range.from, range.to)
                self?.statusLabel.text = text
                print("[PriceScaleRange] from: \(range.from), to: \(range.to)")
            } catch {
                self?.statusLabel.text = "Range: unavailable"
                print("[PriceScaleRange] failed to load visible range: \(error)")
            }
        }
    }
}
