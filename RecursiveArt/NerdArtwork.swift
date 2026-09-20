import SwiftUI

/// Decorative, noninteractive SwiftUI controls. The canvas gesture surface owns input.
/// Readouts and logs are fictional animation, not device diagnostics.
struct NerdArtwork: View {
    let effect: ArtEffect
    let time: Double
    private let words = ["let light = await camera.next()", "actor RecursiveUniverse {", "  @State var reality = false", "  feedback.map { $0 * infinity }", "  try await dream.render()", "// TODO: escape the loop", "  return .moreColor", "}"]

    var body: some View {
        GeometryReader { geometry in
            stage
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.mint)
                .tint(.mint)
                .toggleStyle(ArtworkSwitchStyle())
                .progressViewStyle(ArtworkProgressStyle())
                .frame(width: 360, height: 600)
                .scaleEffect(min(geometry.size.width / 360, geometry.size.height / 600))
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }

    @ViewBuilder private var stage: some View {
        switch effect {
        case .sliderStack:
            VStack(spacing: 18) {
                title("RECURSION / MIXER")
                ForEach(0..<8) { i in
                    VStack(alignment: .leading) {
                        Text(["feedback", "entropy", "dream gain", "reality", "recursion", "warp", "syntax", "infinity"][i])
                        ArtworkSlider(value: wave(i), color: tint(i))
                    }
                }
            }.padding(22).background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))
        case .toggleRain:
            VStack(spacing: 14) {
                ForEach(0..<9) { i in
                    HStack {
                        Toggle(["reality.enabled", "loop.forever", "gravity", "debug.magic", "use.unicorns", "dark.matter", "time.reverse", "light.async", "ship.it"][i], isOn: .constant(wave(i) > 0.5))
                            .tint(tint(i))
                    }.padding(10).background(.black.opacity(0.8), in: Capsule())
                        .offset(x: sin(time * 0.5 + Double(i)) * 20)
                }
            }.padding(12)
        case .buttonStorm:
            ZStack {
                ForEach(0..<20) { i in
                    Button(["RUN", "RETRY", "⌘Z", "RECURSE", "SHIP IT", "DO NOT TAP"][i % 6]) {}
                        .buttonStyle(.borderedProminent).tint(tint(i))
                        .rotationEffect(.degrees(sin(time + Double(i)) * 22))
                        .position(point(i))
                }
            }
        case .terminal:
            VStack(alignment: .leading, spacing: 18) {
                title("◉ recursive-art — zsh")
                ForEach(0..<11) { i in
                    Text(terminalLine(i)).foregroundStyle(i % 3 == 0 ? .white : .mint)
                }
                Text("art@universe ~ % " + (Int(time * 2) % 2 == 0 ? "█" : " "))
            }.padding(20).background(.black.opacity(0.94), in: RoundedRectangle(cornerRadius: 12))
        case .codeRain:
            ZStack {
                ForEach(0..<7) { i in
                    VStack(spacing: 14) {
                        ForEach(0..<16) { j in Text(["{", "}", "let", "nil", "01", "∞", "try", "@State"][(i + j) % 8]).opacity(Double(j + 1) / 16) }
                    }
                    .foregroundStyle(tint(i))
                    .position(x: Double(i) * 54 + 15, y: 100 + fraction(time * 0.13 + Double(i) * 0.17) * 450)
                }
            }.clipped()
        case .debugHUD:
            VStack {
                title("[ LIVE / IMAGINARY TELEMETRY ]")
                HStack { metric("FPS", value: "\(Int(50 + wave(1) * 10))"); Spacer(); metric("DEPTH", value: "\(Int(time * 19))") }
                Spacer()
                Image(systemName: "scope").font(.system(size: 125, weight: .ultraLight)).rotationEffect(.degrees(time * 15))
                Text(String(format: "x %.3f  y %.3f", wave(2), wave(5)))
                Spacer()
                HStack { metric("ENTROPY", value: String(format: "%.2f", wave(0))); Spacer(); metric("STATUS", value: "RECURSIVE") }
            }.padding(24).background(.black.opacity(0.25))
        case .progressMaze:
            VStack(spacing: 15) {
                title("LOADING THE NEXT INFINITY")
                ForEach(0..<12) { i in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Level \(i + 1) / \(Int(wave(i) * 100))%")
                        ProgressView(value: wave(i)).tint(tint(i))
                    }.padding(9).background(tint(i).opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, CGFloat(i % 4) * 13)
                }
            }.padding(12).background(.black.opacity(0.85))
        case .permissionStack:
            ZStack {
                ForEach(0..<5) { i in
                    VStack(spacing: 18) {
                        Image(systemName: "hand.raised.fill").font(.largeTitle)
                        Text(["Allow access to infinity?", "Reality would like to recurse", "Enable extra dimensions?", "Let photons have fun?", "Trust this universe?"][i]).font(.headline)
                        HStack { Button("Not now") {}; Spacer(); Button("Always") {} }.buttonStyle(.bordered)
                    }.padding(20).frame(width: 270).background(tint(i).opacity(0.95), in: RoundedRectangle(cornerRadius: 22))
                        .foregroundStyle(.black)
                        .rotationEffect(.degrees(sin(time * 0.4 + Double(i)) * 12))
                        .position(x: 180 + sin(time * 0.3 + Double(i)) * 24, y: 110 + Double(i) * 92)
                }
            }
        case .syntaxGarden:
            ZStack {
                ForEach(0..<22) { i in
                    Text(["@State", "async", "await", "some View", "{ }", "nil", "func", "∞"][i % 8])
                        .font(.system(size: 16 + CGFloat(i % 4) * 6, weight: .bold, design: .monospaced))
                        .foregroundStyle(tint(i)).rotationEffect(.degrees(time * 8 + Double(i) * 17))
                        .position(point(i))
                }
            }
        case .breakpointGrid:
            VStack(spacing: 13) {
                title("BREAKPOINTS / ALL HIT")
                ForEach(0..<8) { row in
                    HStack(spacing: 10) {
                        ForEach(0..<4) { col in
                            let i = row * 4 + col
                            Button { } label: { Text("\(i + 1)").frame(width: 48, height: 40) }
                                .buttonStyle(.borderedProminent).tint(wave(i) > 0.5 ? .pink : .blue)
                                .scaleEffect(0.7 + wave(i) * 0.35)
                        }
                    }
                }
            }.padding(20).background(.black.opacity(0.72))
        case .memoryHeap:
            VStack(alignment: .leading, spacing: 8) {
                title("HEAP / DO NOT FREE THE LIGHT")
                ForEach(0..<18) { i in
                    HStack(spacing: 3) {
                        Text(String(format: "0x%04X", i * 256)).font(.system(size: 10))
                        ForEach(0..<9) { j in
                            RoundedRectangle(cornerRadius: 3).fill(wave(i + j) > 0.4 ? tint(i + j) : .white.opacity(0.1)).frame(height: 19)
                        }
                    }
                }
                Text("allocated: \(Int(1024 * wave(2))) MB of imagination")
            }.padding(15).background(.black.opacity(0.9))
        case .packetRouter:
            ZStack {
                Path { path in
                    for i in 0..<6 { path.move(to: CGPoint(x: 180, y: 300)); path.addLine(to: node(i)) }
                }.stroke(.mint.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [4, 6], dashPhase: time * 12))
                ForEach(0..<6) { i in
                    Label("N\(i)", systemImage: "server.rack").padding(10).background(.black, in: Capsule()).position(node(i))
                    let p = fraction(time * 0.35 + Double(i) / 6)
                    Text("{\(i)}").padding(6).background(tint(i), in: RoundedRectangle(cornerRadius: 5)).foregroundStyle(.black)
                        .position(x: 180 + (node(i).x - 180) * p, y: 300 + (node(i).y - 300) * p)
                }
                Image(systemName: "network").font(.system(size: 50)).padding(15).background(.black, in: Circle()).position(x: 180, y: 300)
            }
        case .taskQueue:
            VStack(spacing: 18) {
                title("ACTOR: THE UNIVERSE")
                ForEach(0..<7) { i in
                    HStack {
                        Image(systemName: wave(i) > 0.8 ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                            .rotationEffect(.degrees(time * Double(i + 1) * 20))
                        VStack(alignment: .leading) {
                            Text("Task #\(i + 1): \(["bend light", "fold space", "paint pixels", "recurse"][i % 4])")
                            ProgressView(value: wave(i)).tint(tint(i))
                        }
                    }.padding(12).background(.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                        .offset(x: sin(time + Double(i)) * 10)
                }
            }.padding(15)
        case .inspector:
            VStack(alignment: .leading, spacing: 18) {
                title("INSPECTOR / reality.swift")
                ForEach(0..<5) { i in
                    VStack(alignment: .leading) {
                        Text(["Opacity of existence", "Corner radius of time", "Gravity padding", "Z-index of dreams", "Recursion depth"][i])
                        ArtworkSlider(value: wave(i), color: tint(i))
                    }
                }
                Toggle("Clip to universe", isOn: .constant(wave(5) > 0.5))
                Text(String(format: ".frame(width: %.0f, height: ∞)", wave(0) * 999))
                Button("Reset reality") {}.buttonStyle(.borderedProminent)
            }.padding(22).background(.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
        case .buildLog:
            VStack(alignment: .leading, spacing: 14) {
                title("BUILDING / FOREVER")
                ForEach(0..<16) { i in
                    let step = Int(time * 2) + i
                    Text(["✓ Compile Photon.swift", "✓ Link Infinity.framework", "⚠ Recursion limit ignored", "→ Optimizing dreams", "✓ Emit rainbow symbols"][step % 5])
                        .foregroundStyle(step % 5 == 2 ? .yellow : .mint)
                }
                ProgressView(value: fraction(time * 0.1))
                Text("Build \(Int(time)) succeeded. Again.")
            }.padding(18).background(.black.opacity(0.94))
        case .rainbowPicker:
            VStack(spacing: 24) {
                title("PALETTE / IMPOSSIBLE COLORS")
                ForEach(0..<6) { i in
                    VStack(alignment: .leading) {
                        Text("Dimension \(i)")
                        HStack(spacing: 3) {
                            ForEach(0..<3) { segment in
                                Button(["RGB", "∞", "VOID"][segment]) {}
                                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                                    .background(Int(time + Double(i)) % 3 == segment ? tint(i) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                                    .foregroundStyle(Int(time + Double(i)) % 3 == segment ? .black : .white)
                            }
                        }
                        HStack { ForEach(0..<7) { j in Circle().fill(tint(i * 7 + j)).frame(height: 28).scaleEffect(0.6 + wave(i + j) * 0.4) } }
                    }
                }
            }.padding(18).background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
        case .gaugeCluster:
            VStack(spacing: 22) {
                title("REACTOR / KEEP RECURSING")
                ForEach(0..<4) { row in
                    HStack(spacing: 30) {
                        ForEach(0..<3) { col in
                            let i = row * 3 + col
                            Gauge(value: wave(i)) { Text("R\(i)") } currentValueLabel: { Text("\(Int(wave(i) * 100))") }
                                .gaugeStyle(.accessoryCircular).tint(tint(i))
                        }
                    }
                }
            }.padding(22).background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 25))
        case .consoleWall:
            VStack(spacing: 10) {
                ForEach(0..<6) { i in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("CONSOLE \(i) // frame \(Int(time * 30))").foregroundStyle(tint(i))
                        Text("[trace] loop → loop → loop")
                        Text("[debug] \(words[(Int(time) + i) % words.count])")
                    }.font(.system(size: 11, design: .monospaced)).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.94), in: RoundedRectangle(cornerRadius: 8)).offset(x: sin(time * 0.7 + Double(i)) * 15)
                }
            }.padding(10)
        case .windowCascade:
            ZStack {
                ForEach(0..<7) { i in
                    VStack(alignment: .leading, spacing: 20) {
                        HStack { ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0).frame(width: 10, height: 10) }; Text("Untitled \(i).swift") }
                        Text(words[(i + Int(time)) % words.count]).font(.system(size: 11, design: .monospaced))
                        ProgressView(value: wave(i)).tint(tint(i))
                        HStack { Button("Run") {}; Spacer(); Text("⌘R") }
                    }.padding(16).frame(width: 270).background(Color(white: 0.09), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint(i), lineWidth: 2))
                        .position(x: 180 + sin(time * 0.4 + Double(i)) * 35, y: 95 + Double(i) * 65)
                }
            }
        case .fatalError:
            VStack(spacing: 25) {
                Text(":)").font(.system(size: 100, design: .monospaced)).rotationEffect(.degrees(sin(time) * 12))
                Text("fatalError(\"Too much art\")").font(.headline)
                Text("The universe encountered an unexpected amount of recursion.")
                ProgressView(value: fraction(time * 0.12)).tint(.white)
                Text("Recovering photons… \(Int(fraction(time * 0.12) * 100))%")
                Button("Continue anyway") {}.buttonStyle(.bordered)
                Text("Error code: 0x\(String(Int(time * 100), radix: 16).uppercased())")
            }.multilineTextAlignment(.center).padding(26).frame(maxWidth: .infinity).background(.blue.opacity(0.94), in: RoundedRectangle(cornerRadius: 20)).foregroundStyle(.white)
        default: EmptyView()
        }
    }

    private func wave(_ i: Int) -> Double { 0.5 + sin(time * 0.8 + Double(i) * 0.7) * 0.49 }
    private func fraction(_ x: Double) -> Double { x - floor(x) }
    private func tint(_ i: Int) -> Color { Color(hue: fraction(Double(i) * 0.137 + time * 0.025), saturation: 0.75, brightness: 1) }
    private func title(_ text: String) -> some View { Text(text).font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(1).foregroundStyle(.white) }
    private func point(_ i: Int) -> CGPoint { CGPoint(x: 180 + sin(Double(i) * 2.4 + time * 0.22) * 135, y: 300 + cos(Double(i) * 1.7 + time * 0.25) * 250) }
    private func node(_ i: Int) -> CGPoint { CGPoint(x: 180 + cos(Double(i) * .pi / 3) * 135, y: 300 + sin(Double(i) * .pi / 3) * 240) }
    private func metric(_ label: String, value: String) -> some View { VStack(alignment: .leading) { Text(label).font(.caption); Text(value).font(.title3.bold()) }.padding(10).background(.black.opacity(0.8)) }
    private func terminalLine(_ i: Int) -> String { ["$ swift run Universe", "> sampling photons…", "> recursion.depth = \(Int(time * 12) + i)", "$ export REALITY=false", "> compiling light…", "> loop detected. excellent."][(i + Int(time * 0.5)) % 6] }
}


// Pure SwiftUI control artwork also renders faithfully in ImageRenderer thumbnails.
private struct ArtworkSlider: View {
    let value: Double
    let color: Color
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2)).frame(height: 5)
                Capsule().fill(color).frame(width: max(0, geometry.size.width * value), height: 5)
                Circle().fill(.white).shadow(color: color.opacity(0.7), radius: 5)
                    .frame(width: 22, height: 22).offset(x: (geometry.size.width - 22) * value)
            }.frame(height: 26)
        }.frame(height: 26)
    }
}

private struct ArtworkSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Capsule().fill(configuration.isOn ? Color.mint : Color.gray.opacity(0.5))
                .frame(width: 48, height: 28)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle().fill(.white).frame(width: 24, height: 24).padding(2)
                }
        }
    }
}


private struct ArtworkProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule().fill(.tint).frame(width: geometry.size.width * (configuration.fractionCompleted ?? 0))
            }
        }.frame(height: 7)
    }
}
