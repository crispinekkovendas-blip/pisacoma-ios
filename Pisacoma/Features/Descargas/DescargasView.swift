import SwiftUI

/**
 /descargas: what to keep on the phone. On the first open it is the only screen (`bare`, no
 top bar) and «Continuar» leads on; later it is reached from the menu to change the choice,
 complete a download or clear the store. Copy in the site's offline-save voice.
 */
struct DescargasView: View {
    let bare: Bool
    let onContinue: () -> Void
    @EnvironmentObject private var app: AppModel
    @StateObject private var model: DescargasModel

    init(bare: Bool, onContinue: @escaping () -> Void) {
        self.bare = bare
        self.onContinue = onContinue
        let a = AppModel.shared
        _model = StateObject(wrappedValue: DescargasModel(store: a.content, downloader: a.downloader, userState: a.userState))
    }

    var body: some View {
        let s = model.state
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: bare ? 36 : 44)
                EyebrowLine("— Guardar en el teléfono")
                Spacer().frame(height: 18)
                PageTitle(titleWithEm("¿Qué quieres guardar", "en este teléfono", tail: "?"))
                Spacer().frame(height: 22)
                Lede("Lo que guardes se lee sin señal. Puedes cambiarlo después desde el menú, en Descargas.")
                Spacer().frame(height: 26)
                VStack(spacing: 10) {
                    ForEach(Array(s.options.enumerated()), id: \.element.id) { i, o in
                        OptionRow(index: i + 1, option: o, selected: o.mode == s.current) { model.choose(o.mode) }
                    }
                }
                if s.download != .idle {
                    Spacer().frame(height: 26)
                    ProgressBlock(state: s.download, onRetry: model.complete)
                }
                if !bare && s.current != nil {
                    Spacer().frame(height: 26)
                    Hairline()
                    Spacer().frame(height: 18)
                    if !s.storedText.isEmpty {
                        Text(s.storedText).font(Fonts.inter(14)).foregroundStyle(Tokens.sageText).accessibilityIdentifier("descargas-guardado")
                        Spacer().frame(height: 14)
                    }
                    HStack(spacing: 10) {
                        if s.missingCount > 0 && !s.download.isRunning {
                            Pill(label: "Completar", filled: true, tag: "descargas-completar", action: model.complete)
                        }
                        if !s.storedText.isEmpty {
                            Pill(label: "Borrar lo descargado", filled: false, tag: "descargas-borrar", action: model.clear)
                        }
                    }
                }
                if bare {
                    Spacer().frame(height: 30)
                    ContinueButton(enabled: s.canContinue, action: onContinue)
                }
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)
            SiteFooter()
        }
        .accessibilityIdentifier("descargas")
        .onAppear { model.refresh() }
    }
}

private struct OptionRow: View {
    let index: Int
    let option: DescargasUi.Option
    let selected: Bool
    let onClick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 0) {
                Text(String(format: "%02d", index)).font(Fonts.fraunces(13)).foregroundStyle(Tokens.sageSoft).padding(.trailing, 12)
                Text(option.mode.label).font(Fonts.fraunces(18, weight: .semibold)).foregroundStyle(Tokens.inkDeep)
                Spacer(minLength: 8)
                if !option.size.isEmpty { Text(option.size).font(Fonts.inter(12, weight: .semibold)).foregroundStyle(Tokens.sageText) }
            }
            Text(option.desc).font(Fonts.inter(13.5)).lineSpacing(5).foregroundStyle(Tokens.sageText).fixedSize(horizontal: false, vertical: true)
            if selected { EyebrowLine("Actual", size: 10).padding(.top, 2) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(selected ? Tokens.sageA(0.12) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Tokens.sageA(selected ? 0.4 : 0.2), lineWidth: 1))
        .pressable(scale: 0.985, tag: "modo-\(option.mode.value)", action: onClick)
    }
}

private struct ProgressBlock: View {
    let state: DownloadState
    let onRetry: () -> Void

    var body: some View {
        let (message, progress): (String, Double) = {
            switch state {
            case let .running(doneFiles, totalFiles, doneBytes, totalBytes, failed):
                let f = failed > 0 ? " · \(failed) fallaron" : ""
                return ("Guardando \(doneFiles) de \(totalFiles) archivos · \(formatMb(doneBytes)) de \(formatMb(totalBytes))\(f)", totalBytes > 0 ? Double(doneBytes) / Double(totalBytes) : 0)
            case let .done(totalBytes): return ("Guardado en este teléfono · \(formatMb(totalBytes))", 1)
            case .error: return ("No se pudo guardar todo. Revisa la señal e inténtalo otra vez.", 0)
            case .idle: return ("", 0)
            }
        }()
        VStack(alignment: .leading, spacing: 10) {
            Text(message).font(Fonts.inter(14)).lineSpacing(5).foregroundStyle(Tokens.forest).fixedSize(horizontal: false, vertical: true)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Tokens.sageA(0.15))
                    Capsule().fill(Tokens.sage).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
            if case .error = state {
                Pill(label: "Reintentar", filled: true, tag: "descarga-reintentar", action: onRetry).padding(.top, 4)
            }
        }
        .accessibilityIdentifier("descarga-progreso")
    }
}

private struct ContinueButton: View {
    let enabled: Bool
    let action: () -> Void
    var body: some View {
        Text("Continuar")
            .font(Fonts.inter(15, weight: .semibold))
            .foregroundStyle(enabled ? Tokens.cream : Tokens.sageText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Capsule().fill(enabled ? Tokens.forest : Tokens.sageA(0.18)))
            .pressable(enabled: enabled, tag: "descargas-continuar", action: action)
    }
}

struct Pill: View {
    let label: String
    let filled: Bool
    var tag: String = ""
    let action: () -> Void
    var body: some View {
        Text(label)
            .font(Fonts.inter(13, weight: .semibold))
            .foregroundStyle(filled ? Tokens.cream : Tokens.forest)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(filled ? Tokens.forest : Color.clear))
            .overlay(Capsule().stroke(filled ? Tokens.forest : Tokens.sageA(0.35), lineWidth: 1))
            .pressable(tag: tag, action: action)
    }
}
