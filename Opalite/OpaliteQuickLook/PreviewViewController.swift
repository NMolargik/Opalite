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
            hexLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    // MARK: - Palette Preview

    private func setupPalettePreview(colors: [UIColor], name: String) {
        // Gradient view for palette
        let gradientView = GradientView()
        gradientView.colors = colors.isEmpty ? [.systemGray4, .systemGray4] : colors
        gradientView.layer.cornerRadius = 24
        gradientView.layer.borderWidth = 4
        gradientView.layer.borderColor = UIColor.systemGray4.cgColor
        gradientView.clipsToBounds = true
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gradientView)

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
            gradientView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gradientView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            gradientView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            gradientView.heightAnchor.constraint(equalToConstant: 180),

            nameLabel.topAnchor.constraint(equalTo: gradientView.bottomAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            countLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            countLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            countLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    // MARK: - Helpers

    private func hexString(from color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Gradient View

private class GradientView: UIView {
    var colors: [UIColor] = [] {
        didSet { updateGradient() }
    }

    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(gradientLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    private func updateGradient() {
        gradientLayer.colors = colors.map { $0.cgColor }

        // Evenly distribute color stops
        if colors.count > 1 {
            gradientLayer.locations = colors.enumerated().map { index, _ in
                NSNumber(value: Double(index) / Double(colors.count - 1))
            }
        }
    }
}
