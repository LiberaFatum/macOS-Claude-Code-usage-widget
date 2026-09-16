import AppKit

/// Okénko pro vložení vlastního dlouhodobého tokenu z "claude setup-token".
///
/// Vlastní token se ukládá do položky, kterou si aplikace vytvoří sama, takže
/// se u jejího čtení systém nikdy neptá na heslo ke svazku klíčů.
enum TokenSheet {
    @MainActor
    static func present() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Vlastní token widgetu"
        alert.informativeText = """
        V Terminálu spusť "claude setup-token", token zkopíruj a vlož sem.

        Uloží se do vlastní položky svazku klíčů, u které se systém nikdy neptá \
        na heslo. Claude Code do ní nesahá, takže ji nepřepíše.
        """
        alert.alertStyle = .informational

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "vlož token"
        alert.accessoryView = field

        alert.addButton(withTitle: "Uložit")
        alert.addButton(withTitle: "Vložit ze schránky")
        alert.addButton(withTitle: "Zrušit")

        alert.window.initialFirstResponder = field

        while true {
            let response = alert.runModal()
            switch response {
            case .alertSecondButtonReturn:
                field.stringValue = NSPasteboard.general.string(forType: .string) ?? ""
                continue
            case .alertFirstButtonReturn:
                save(field.stringValue)
                return
            default:
                return
            }
        }
    }

    @MainActor
    private static func save(_ raw: String) {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            report(title: "Nic jsem nedostal", text: "Pole bylo prázdné, nic se neuložilo.")
            return
        }

        let status = Credentials.saveOwnToken(token)
        guard status == errSecSuccess else {
            report(title: "Uložení selhalo", text: "Svazek klíčů vrátil OSStatus \(status).")
            return
        }

        report(
            title: "Token uložen",
            text: "Widget teď na položku Claude Code nesahá, takže se systém přestane ptát na heslo."
        )
    }

    @MainActor
    static func clear() {
        let status = Credentials.deleteOwnToken()
        let ok = status == errSecSuccess || status == errSecItemNotFound
        report(
            title: ok ? "Vlastní token smazán" : "Mazání selhalo",
            text: ok
                ? "Widget se vrací k tokenu Claude Code, dialog svazku klíčů se může začít vracet."
                : "Svazek klíčů vrátil OSStatus \(status)."
        )
    }

    @MainActor
    private static func report(title: String, text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
