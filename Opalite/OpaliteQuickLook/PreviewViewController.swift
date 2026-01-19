//
//  PreviewViewController.swift
//  OpaliteQuickLook
//
//  Created by Nick Molargik on 12/21/25.
//

import UIKit
import QuickLook

class PreviewViewController: UIViewController, QLPreviewingController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        // Read and decode the file
        do {
            let data = try Data(contentsOf: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                handler(PreviewError.invalidFormat)
                return
            }

            let pathExtension = url.pathExtension.lowercased()

            if pathExtension == "opalitecolor" {
                // Single color preview
                guard let color = decodeColor(from: json) else {
                    handler(PreviewError.decodingFailed)
                    return
                }
                setupColorPreview(color: color, name: json["name"] as? String)

            } else if pathExtension == "opalitepalette" {
                // Palette preview
                guard let name = json["name"] as? String,
                      let colorDicts = json["colors"] as? [[String: Any]] else {
                    handler(PreviewError.decodingFailed)
                    return
                }

                let colors = colorDicts.compactMap { decodeColor(from: $0) }
                setupPalettePreview(colors: colors, name: name)
            }

            handler(nil)
        } catch {
            handler(error)
        }
    }

    // MARK: - Color Decoding

    private func decodeColor(from json: [String: Any]) -> UIColor? {
        guard let red = json["red"] as? Double,
              let green = json["green"] as? Double,
              let blue = json["blue"] as? Double else {
            return nil
        }
        let alpha = json["alpha"] as? Double ?? 1.0
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    // MARK: - Single Color Preview

    private func setupColorPreview(color: UIColor, name: String?) {
        // Color swatch view
        let swatchView = UIView()
        swatchView.backgroundColor = color
        swatchView.layer.cornerRadius = 24
        swatchView.layer.borderWidth = 4
        swatchView.layer.borderColor = UIColor.systemGray4.cgColor
        swatchView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(swatchView)

        // Name label
        let nameLabel = UILabel()
        nameLabel.text = name ?? hexString(from: color)
        nameLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nameLabel)

        // Hex label
        let hexLabel = UILabel()
        hexLabel.text = hexString(from: color)
        hexLabel.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        hexLabel.textColor = .secondaryLabel
        hexLabel.textAlignment = .center
        hexLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hexLabel)

        NSLayoutConstraint.activate([
            swatchView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            swatchView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            swatchView.widthAnchor.constraint(equalToConstant: 200),
            swatchView.heightAnchor.constraint(equalToConstant: 200),

            nameLabel.topAnchor.constraint(equalTo: swatchView.bottomAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            hexLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            hexLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            hexLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    // MARK: - Palette Preview

    private func setupPalettePreview(colors: [UIColor], name: String) {
        // Container view for the swatch grid
        let containerView = SwatchGridView(colors: colors)
        containerView.layer.cornerRadius = 24
        containerView.layer.borderWidth = 4
        containerView.layer.borderColor = UIColor.systemGray4.cgColor
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Name label
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nameLabel)

        // Color count label
        let countLabel = UILabel()
        countLabel.text = "\(colors.count) color\(colors.count == 1 ? "" : "s")"
        countLabel.font = .systemFont(ofSize: 16, weight: .regular)
        countLabel.textColor = .secondaryLabel
        countLabel.textAlignment = .center
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(countLabel)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            containerView.heightAnchor.constraint(equalToConstant: 180),

            nameLabel.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            countLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            countLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            countLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    // MARK: - Helpers

    private func hexString(from color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Swatch Grid View

private class SwatchGridView: UIView {
    private let colors: [UIColor]
    private var swatchViews: [UIView] = []

    init(colors: [UIColor]) {
        self.colors = colors
        super.init(frame: .zero)
        backgroundColor = .systemBackground
        setupSwatches()
    }

    required init?(coder: NSCoder) {
        self.colors = []
        super.init(coder: coder)
        backgroundColor = .systemBackground
    }

    private func setupSwatches() {
        for color in colors {
            let swatchView = UIView()
            swatchView.backgroundColor = color
            swatchView.layer.cornerRadius = 8
            swatchView.layer.borderWidth = 1
            swatchView.layer.borderColor = UIColor.black.withAlphaComponent(0.1).cgColor
            swatchView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(swatchView)
            swatchViews.append(swatchView)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutSwatches()
    }

    private func layoutSwatches() {
        guard !colors.isEmpty else { return }

        let padding: CGFloat = 12
        let spacing: CGFloat = 8
        let availableWidth = bounds.width - (padding * 2)
        let availableHeight = bounds.height - (padding * 2)

        let layout = calculateLayout(colorCount: colors.count, availableWidth: availableWidth, availableHeight: availableHeight, spacing: spacing)

        let totalGridWidth = CGFloat(layout.columns) * layout.swatchSize + CGFloat(layout.columns - 1) * spacing
        let totalGridHeight = CGFloat(layout.rows) * layout.swatchSize + CGFloat(layout.rows - 1) * spacing
        let startX = padding + (availableWidth - totalGridWidth) / 2
        let startY = padding + (availableHeight - totalGridHeight) / 2

        for (index, swatchView) in swatchViews.enumerated() {
            let row = index / layout.columns
            let col = index % layout.columns

            let x = startX + CGFloat(col) * (layout.swatchSize + spacing)
            let y = startY + CGFloat(row) * (layout.swatchSize + spacing)

            swatchView.frame = CGRect(x: x, y: y, width: layout.swatchSize, height: layout.swatchSize)
            swatchView.layer.cornerRadius = layout.swatchSize * 0.15
        }
    }

    private struct LayoutInfo {
        let rows: Int
        let columns: Int
        let swatchSize: CGFloat
    }

    private func calculateLayout(colorCount: Int, availableWidth: CGFloat, availableHeight: CGFloat, spacing: CGFloat) -> LayoutInfo {
        guard colorCount > 0 else {
            return LayoutInfo(rows: 0, columns: 0, swatchSize: 0)
        }

        var bestLayout = LayoutInfo(rows: 1, columns: 1, swatchSize: 0)

        for rows in 1...3 {
            let columns = Int(ceil(Double(colorCount) / Double(rows)))

            let totalHSpacing = CGFloat(columns - 1) * spacing
            let totalVSpacing = CGFloat(rows - 1) * spacing

            let maxSwatchWidth = (availableWidth - totalHSpacing) / CGFloat(columns)
            let maxSwatchHeight = (availableHeight - totalVSpacing) / CGFloat(rows)

            let swatchSize = min(maxSwatchWidth, maxSwatchHeight)

            if swatchSize > bestLayout.swatchSize {
                bestLayout = LayoutInfo(rows: rows, columns: columns, swatchSize: swatchSize)
            }
        }

        return bestLayout
    }
}
