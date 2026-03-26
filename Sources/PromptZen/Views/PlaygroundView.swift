import AppKit
import SwiftUI

struct PlaygroundView: View {
    @AppStorage("PromptZen.pricePerMillionInput") private var pricePerMillionInput: Double = 2.5
    @AppStorage("PromptZen.pricePerMillionOutput") private var pricePerMillionOutput: Double = 10.0
    @State private var playgroundText: String = ""
    @State private var assumedOutputTokens: Double = 256

    private var inputTokens: Int {
        TokenEstimator.estimateTokens(for: playgroundText)
    }

    private var outputTokens: Int {
        max(0, Int(assumedOutputTokens.rounded()))
    }

    private var estimatedCost: Double {
        TokenEstimator.costUSD(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            pricePerMillionInput: pricePerMillionInput,
            pricePerMillionOutput: pricePerMillionOutput
        )
    }

    var body: some View {
        HSplitView {
            pricingSidebar
                .frame(minWidth: 260, idealWidth: 280, maxWidth: 320)

            editorPane
                .frame(minWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pricingSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Playground")
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 10) {
                    Text("Pricing (USD per 1M tokens)")
                        .font(.headline)
                    HStack {
                        Text("Input")
                        Spacer()
                        TextField("", value: $pricePerMillionInput, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Output")
                        Spacer()
                        TextField("", value: $pricePerMillionOutput, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Assumed completion")
                        .font(.headline)
                    HStack {
                        Text("Output tokens (budget)")
                        Spacer()
                        Text("\(outputTokens)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $assumedOutputTokens, in: 0...8192, step: 32)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Paste a prompt to measure")
                    .font(.headline)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Input ~\(inputTokens) tok")
                        .monospacedDigit()
                    Text(String(format: "Est. cost ~$%.5f", estimatedCost))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            TextEditor(text: $playgroundText)
                .font(.body)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            Text("Cost uses the prices at left and your output token budget.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
