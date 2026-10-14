import SwiftUI

/**
 The one notice for content that is neither stored nor reachable (the site's offline-save
 voice): shown by the scaffold over any screen while ContentStore.missing is set.
 */
struct MissingContentNotice: View {
    @Environment(\.chrome) private var c
    let onRetry: () -> Void
    let onDownloads: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLine("Sin conexión", color: c.bodyText.opacity(0.7))
            Spacer().frame(height: 8)
            Text("Este contenido no está guardado en el teléfono. Conéctate a internet o guárdalo desde Descargas.")
                .font(Fonts.inter(14)).lineSpacing(5).foregroundStyle(c.bodyText)
            Spacer().frame(height: 14)
            HStack(spacing: 10) {
                NoticeButton(label: "Reintentar", filled: true, tag: "sin-conexion-reintentar", action: onRetry)
                NoticeButton(label: "Descargas", filled: false, tag: "sin-conexion-descargas", action: onDownloads)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(c.background))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(c.footerBorder, lineWidth: 1))
        .uiId("sin-conexion")
    }
}

private struct NoticeButton: View {
    @Environment(\.chrome) private var c
    let label: String
    let filled: Bool
    let tag: String
    let action: () -> Void

    var body: some View {
        Text(label)
            .font(Fonts.inter(13, weight: .semibold))
            .foregroundStyle(filled ? c.background : c.bodyText)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(filled ? c.bodyText : c.background))
            .overlay(Capsule().stroke(c.bodyText.opacity(filled ? 1 : 0.35), lineWidth: 1))
            .pressable(tag: tag, action: action)
    }
}
