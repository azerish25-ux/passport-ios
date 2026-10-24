//
//  PhotoImporter.swift
//  PassportProof
//
//  PhotosUI wrapper. The load happens off the main thread and the decoded
//  `UIImage` is handed back on the main actor. The picker item is reset after
//  each load so choosing the same photo twice fires again.
//

import SwiftUI
import PhotosUI
import UIKit

struct PhotoImporter: View {

    let title: String
    var isEnabled: Bool = true
    let onImage: (UIImage) -> Void

    @State private var item: PhotosPickerItem?
    @State private var isLoading = false
    @State private var didFail = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {

            PhotosPicker(selection: $item, matching: .images) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Typography.button.text(title)
                            .foregroundStyle(isEnabled ? Theme.ink : Theme.inkTertiary)

                        Text(isLoading ? "Reading the file…" : "Photos on this device. Nothing is uploaded.")
                            .typeStyle(Typography.meta)
                            .foregroundStyle(Theme.inkTertiary)
                    }

                    Spacer(minLength: Theme.Spacing.m)

                    Typography.unit.text("photo")
                        .foregroundStyle(Theme.inkTertiary)
                }
                .frame(minHeight: Theme.Metrics.tapTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .disabled(!isEnabled || isLoading)

            if didFail {
                Text("That file could not be read as an image. Try another photo.")
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.signalFail)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: item) { _, newItem in
            load(newItem)
        }
    }

    private func load(_ newItem: PhotosPickerItem?) {
        guard let newItem else { return }

        isLoading = true
        didFail = false

        Task {
            let data = try? await newItem.loadTransferable(type: Data.self)
            let image = data.flatMap { UIImage(data: $0) }

            await MainActor.run {
                isLoading = false
                item = nil

                if let image {
                    onImage(image)
                } else {
                    didFail = true
                }
            }
        }
    }
}
