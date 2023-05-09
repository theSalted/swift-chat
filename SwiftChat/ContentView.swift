//
//  ContentView.swift
//  SwiftChat
//
//  Created by Pedro Cuenca on April 2023
//  Based on code by Cyril Zakka from https://github.com/cyrilzakka/pen
//

import SwiftUI
import Generation
import Models

struct ContentView: View {
    @State private var config = GenerationConfig(maxNewTokens: 20)
//    @State private var prompt = """
//    Correct spelling and grammar from the following text.
//    I do not wan to go
//
//    """
    @State private var prompt = "Write a poem about Valencia\n"
    @State private var modelURL: URL? = nil
    @State private var languageModel: LanguageModel? = nil
    
    enum ModelState: Equatable {
        case noModel
        case loading
        case ready
        case generating(Float)
    }
    @State private var status: ModelState = .noModel
    
    
    func modelDidChange() {
        guard status != .loading else { return }
        
        status = .loading
        Task.init {
            do {
                languageModel = try await ModelLoader.load(url: modelURL)
                config.bosTokenId = languageModel?.bosTokenId
                config.eosTokenId = languageModel?.eosTokenId
                status = .ready
            } catch {
                print("No model could be loaded: \(error)")
                status = .noModel
            }

        }
    }

    func run() {
        guard let languageModel = languageModel else { return }
        
        @Sendable func showOutput(currentGeneration: String, progress: Float, finished: Bool = false) {
            Task { @MainActor in
                // I'm getting `\\n` instead of `\n` in at least some models. To be debugged.
                prompt = currentGeneration.replacingOccurrences(of: "\\n", with: "\n")
                status = finished ? .ready : .generating(progress)
            }
        }
        
        Task.init {
            status = .generating(0)
            var tokensReceived = 0
            let begin = Date()
            let output = await languageModel.generate(config: config, prompt: prompt) { inProgressGeneration in
                tokensReceived += 1
                showOutput(currentGeneration: inProgressGeneration, progress: Float(tokensReceived)/Float(config.maxNewTokens))
            }
            print("Took \(Date().timeIntervalSince(begin))")
            showOutput(currentGeneration: output, progress: 1, finished: true)
        }
    }
    
    @ViewBuilder
    var runButton: some View {
        switch status {
        case .noModel:
            EmptyView()
        case .loading:
            ProgressView().controlSize(.small).padding(.trailing, 6)
        case .ready:
            Button(action: run) { Label("Run", systemImage: "play.fill") }
                .keyboardShortcut("R")
        case .generating(let progress):
            ProgressView(value: progress).controlSize(.small).progressViewStyle(.circular).padding(.trailing, 6)
        }
    }

    
    var body: some View {
        NavigationSplitView {
            ControlView(prompt: prompt, config: $config, model: $languageModel, modelURL: $modelURL)
                .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            TextEditor(text: $prompt)
                .font(.body)
                .fontDesign(.rounded)
                .scrollContentBackground(.hidden)
                .lineSpacing(5)
                .padding()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        runButton
                    }
                }
        }.onAppear {
            modelDidChange()
        }
        .onChange(of: modelURL) { model in
            modelDidChange()
        }
//        .onChange(of: completer.status) { status in
//            switch status {
//            case .missingModel, .idle, .working, .starting:
//                print("Error")
//            case .progress, .done:
//                promptArea = completer.status.response!.result
//            case .failed(let error):
//                print("\(error)")
//            }
//        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
