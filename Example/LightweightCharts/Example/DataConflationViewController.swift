import UIKit
import LightweightCharts

class DataConflationViewController: UIViewController {

    private var chart: LightweightCharts!
    private var series: LineSeries!
    private var conflationEnabled = false

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
        toggleButton.setTitle("Toggle Conflation", for: .normal)
        toggleButton.addTarget(self, action: #selector(toggleConflation), for: .touchUpInside)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toggleButton)

        // Start with conflation disabled; set very small barSpacing so multiple
        // data points map to the same pixel — this is required for conflation to kick in.
        let options = ChartOptions(
            timeScale: TimeScaleOptions(
                barSpacing: 0.5,
                minBarSpacing: 0.01,
                enableConflation: false
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
                chart.bottomAnchor.constraint(equalTo: toggleButton.topAnchor, constant: -12),

                toggleButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                toggleButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
                toggleButton.heightAnchor.constraint(equalToConstant: 44)
            ])
        } else {
            NSLayoutConstraint.activate([
                chart.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                chart.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                chart.topAnchor.constraint(equalTo: view.topAnchor),
                chart.bottomAnchor.constraint(equalTo: toggleButton.topAnchor, constant: -12),

                toggleButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                toggleButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
                toggleButton.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
        self.chart = chart
    }

    private func setupData() {
        let series = chart.addLineSeries(options: nil)

        // Generate a large dataset (10K+ points) to demonstrate conflation benefits
        var data: [LineData] = []
        var timestamp: TimeInterval = 1514764800 // 2018-01-01
        for i in 0..<15000 {
            let value = 100.0 + sin(Double(i) * 0.01) * 20.0 + Double.random(in: -2...2)
            data.append(LineData(time: .utc(timestamp: timestamp), value: value))
            timestamp += 60 // 1-minute intervals
        }
        series.setData(data: data)
        self.series = series
    }

    @objc private func toggleConflation() {
        conflationEnabled.toggle()
        chart.applyOptions(options: ChartOptions(
            timeScale: TimeScaleOptions(
                barSpacing: 0.5,
                minBarSpacing: 0.01,
                enableConflation: conflationEnabled,
                conflationThresholdFactor: 1.0
            )
        ))
    }
}
