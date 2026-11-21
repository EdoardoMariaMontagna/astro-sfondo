// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Edoardo Maria Montagna
//
// AstroSfondo: mostra la pagina animata in web/ come sfondo della Scrivania, dietro le icone.
import Cocoa
import ServiceManagement
import WebKit

// Cartella della pagina: quella del progetto (modificabile senza ricompilare),
// altrimenti la copia dentro l'app
let webRoot: URL = {
    if let path = Bundle.main.object(forInfoDictionaryKey: "AstroWebRoot") as? String,
       FileManager.default.fileExists(atPath: path + "/index.html") {
        return URL(fileURLWithPath: path, isDirectory: true)
    }
    return Bundle.main.resourceURL!.appendingPathComponent("web", isDirectory: true)
}()

// Dati dell'app: istantanee per lo sfondo di sistema ed esito delle verifiche automatiche
let supportFolder: URL = {
    let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("AstroSfondo", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}()
let verifyLogURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/AstroSfondo/verifica.log")
let launchAgent = "gui/\(getuid())/local.astrosfondo"
let verifyAgent = "gui/\(getuid())/local.astrosfondo.verifica"
// Impostazioni personali per chi installa dal .dmg: l'interno dell'app firmata non è modificabile
let personalConfig = supportFolder.appendingPathComponent("config.local.js")

// Esegue launchctl e ne restituisce il codice di uscita (0 = servizio presente o comando riuscito)
@discardableResult
func launchctl(_ args: [String]) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    p.arguments = args
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    guard (try? p.run()) != nil else { return -1 }
    p.waitUntilExit()
    return p.terminationStatus
}

func screenID(_ screen: NSScreen) -> String {
    (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "0"
}

func snapshotJPEG(_ webView: WKWebView, completion: @escaping (Data?) -> Void) {
    webView.takeSnapshot(with: nil) { image, _ in
        guard let image, let tiff = image.tiffRepresentation,
              let jpeg = NSBitmapImageRep(data: tiff)?
                  .representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else {
            completion(nil)
            return
        }
        completion(jpeg)
    }
}

// Luminosità media (0-1) della zona del globo in un'istantanea: se la scena 3D non viene
// disegnata quella zona è nera, anche se il pannello di testo appare normalmente
func globeLuminance(of path: String) -> Double? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    let w = Double(image.width), h = Double(image.height)
    guard let globe = image.cropping(to: CGRect(x: w * 0.48, y: h * 0.32, width: w * 0.26, height: h * 0.36)) else { return nil }
    let side = 64
    var pixels = [UInt8](repeating: 0, count: side * side * 4)
    guard let context = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.draw(globe, in: CGRect(x: 0, y: 0, width: side, height: side))
    var sum = 0.0
    for i in stride(from: 0, to: pixels.count, by: 4) {
        sum += 0.2126 * Double(pixels[i]) + 0.7152 * Double(pixels[i + 1]) + 0.0722 * Double(pixels[i + 2])
    }
    return sum / Double(side * side) / 255
}

// Esito dell'ultima verifica, scritto da verifica.sh come righe chiave=valore
struct VerifyStatus {
    var level = "none"
    var time: Date?
    var summary = "Nessuna verifica ancora eseguita"
    var details: [String] = []

    static func load() -> VerifyStatus {
        var status = VerifyStatus()
        guard let text = try? String(contentsOf: supportFolder.appendingPathComponent("stato.txt"), encoding: .utf8) else {
            return status
        }
        for line in text.split(separator: "\n") {
            guard let eq = line.firstIndex(of: "=") else { continue }
            let value = String(line[line.index(after: eq)...])
            switch line[..<eq] {
            case "level": status.level = value
            case "time": status.time = TimeInterval(value).map(Date.init(timeIntervalSince1970:))
            case "summary": status.summary = value
            case "detail": status.details.append(value)
            default: break
            }
        }
        return status
    }
}

// Serve i file della pagina con lo schema astro://: moduli JS e texture hanno così la stessa
// origine, cosa che WebGL richiede (con file:// le texture verrebbero rifiutate)
final class LocalFiles: NSObject, WKURLSchemeHandler {
    private let types = ["html": "text/html", "js": "text/javascript", "css": "text/css",
                         "png": "image/png", "jpg": "image/jpeg", "json": "application/json"]

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        let relative = url.path.isEmpty || url.path == "/" ? "index.html" : String(url.path.dropFirst())
        var file = webRoot.appendingPathComponent(relative).standardizedFileURL
        if relative == "config.local.js", !FileManager.default.fileExists(atPath: file.path) {
            file = personalConfig
        }
        guard file.path.hasPrefix(webRoot.standardizedFileURL.path + "/") || file == personalConfig,
              let data = try? Data(contentsOf: file) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mime = types[file.pathExtension.lowercased()] ?? "application/octet-stream"
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": mime, "Cache-Control": "no-cache"])!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

// Finestra senza bordi al livello della Scrivania: sopra l'immagine di sfondo, sotto le icone,
// presente in tutte le Scrivanie (Spaces) e trasparente ai clic
final class DesktopWindow: NSWindow {
    let webView: WKWebView

    init(screen: NSScreen, configuration: WKWebViewConfiguration, query: String) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        isReleasedWhenClosed = false
        setFrame(screen.frame, display: false)
        webView.setValue(false, forKey: "drawsBackground") // niente lampo bianco al caricamento
        webView.isInspectable = true // ispezionabile da Safari > Sviluppo, utile per modifiche
        contentView = webView
        webView.load(URLRequest(url: URL(string: "astro://app/index.html\(query)")!))
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// Tiene lo sfondo di sistema uguale alla scena. macOS lo mostra al posto della nostra finestra
// mentre si spostano i widget, in Mission Control e nei cambi di Scrivania: così non si nota.
final class WallpaperSync {
    private let defaults = UserDefaults.standard

    private func originalKey(_ screen: NSScreen) -> String { "originalWallpaper-\(screenID(screen))" }

    // Ricorda lo sfondo scelto dall'utente, per ripristinarlo all'uscita
    private func rememberOriginal(for screen: NSScreen) {
        guard let current = NSWorkspace.shared.desktopImageURL(for: screen),
              !current.path.hasPrefix(supportFolder.path) else { return }
        defaults.set(current.path, forKey: originalKey(screen))
    }

    func update(_ window: DesktopWindow) {
        guard let screen = window.screen else { return }
        rememberOriginal(for: screen)
        snapshotJPEG(window.webView) { jpeg in
            guard let jpeg else { return }
            // macOS non ricarica un'immagine con lo stesso percorso: si alternano due file, scrivendo
            // sempre quello che lo schermo non sta usando. Nessuno dei due va mai cancellato: ogni
            // Scrivania (Space) e la schermata di blocco ricordano il proprio percorso, e un file
            // mancante si vede come un lampo di colore nel cambio di Scrivania.
            let id = screenID(screen)
            let a = supportFolder.appendingPathComponent("sfondo-\(id)-a.jpg")
            let b = supportFolder.appendingPathComponent("sfondo-\(id)-b.jpg")
            let current = NSWorkspace.shared.desktopImageURL(for: screen)?.standardizedFileURL
            let url = current == a.standardizedFileURL ? b : a
            do {
                try jpeg.write(to: url, options: .atomic)
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [
                    .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                    .allowClipping: true,
                ])
                // l'altro file resta come seconda istantanea più recente, per le Scrivanie che lo usano
                let other = url == a ? b : a
                if !FileManager.default.fileExists(atPath: other.path) { try? jpeg.write(to: other, options: .atomic) }
            } catch {
                NSLog("AstroSfondo: impossibile aggiornare lo sfondo di sistema: \(error)")
            }
        }
    }

    func restoreOriginals() {
        for screen in NSScreen.screens {
            guard let path = defaults.string(forKey: originalKey(screen)) else { continue }
            try? NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: path), for: screen, options: [:])
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let wallpaper = WallpaperSync()
    private var wallpaperTimer: Timer?
    private var statusTimer: Timer?
    private var verifySignal: DispatchSourceSignal?
    private var windows: [DesktopWindow] = []
    private var statusItem: NSStatusItem?
    private var verifyItem: NSMenuItem?
    private var pauseItem: NSMenuItem?
    private var loginItem: NSMenuItem?
    private var userPaused = false
    private var screensAsleep = false
    private let configuration: WKWebViewConfiguration = {
        let c = WKWebViewConfiguration()
        c.setURLSchemeHandler(LocalFiles(), forURLScheme: "astro")
        c.suppressesIncrementalRendering = true
        return c
    }()

    // Argomenti di prova: --query "?t=2027-06-21T12:00:00Z"  --snapshot /percorso/immagine.png
    private func argument(_ name: String) -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    private static let showMenuNotification = Notification.Name("local.astrosfondo.mostraMenu")

    // Aperta con doppio clic dal Finder e non da launchd: se l'avvio automatico è installato,
    // si lascia l'app a launchd (che la riavvia se si chiude per errore) e si chiede alla copia
    // in esecuzione di aprire il suo menu. Così non partono mai due sfondi sovrapposti.
    private func handOverToLaunchd() -> Bool {
        guard ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"] != "local.astrosfondo",
              argument("--snapshot") == nil, argument("--query") == nil else { return false }
        guard launchctl(["print", launchAgent]) == 0 else { return false } // avvio automatico non installato
        launchctl(["kickstart", launchAgent]) // la avvia se era stata chiusa dal menu, altrimenti non fa nulla
        DistributedNotificationCenter.default().postNotificationName(Self.showMenuNotification, object: nil,
                                                                      userInfo: nil, deliverImmediately: true)
        return true
    }

    // Aperta direttamente dal .dmg o da Download (macOS la esegue da una copia temporanea, la
    // "App Translocation"): l'avvio all'accesso e gli aggiornamenti non funzionerebbero da lì
    private func mustBeMovedToApplications() -> Bool {
        let path = Bundle.main.bundleURL.path
        guard argument("--snapshot") == nil, path.hasPrefix("/Volumes/") || path.contains("/AppTranslocation/") else { return false }
        let alert = NSAlert()
        alert.messageText = "Sposta Astro Sfondo in Applicazioni"
        alert.informativeText = "Trascina Astro Sfondo nella cartella Applicazioni e aprilo da lì: solo così può partire a ogni accesso."
        alert.addButton(withTitle: "OK")
        NSApp.activate()
        alert.runModal()
        return true
    }

    // L'avvio all'accesso è gestito da launchd quando l'app è installata dai sorgenti con install.sh
    private var managedByLaunchd: Bool { launchctl(["print", launchAgent]) == 0 }

    // Installazione dal .dmg: alla prima apertura da /Applications l'app si registra come
    // elemento di login (Impostazioni di Sistema → Generali → Elementi login). Se poi l'utente lo
    // disattiva dal menu, la scelta viene rispettata.
    private func configureLoginItemOnFirstRun() {
        let defaults = UserDefaults.standard
        guard !managedByLaunchd, Bundle.main.bundleURL.path.hasPrefix("/Applications/"),
              !defaults.bool(forKey: "loginItemConfigured") else { return }
        try? SMAppService.mainApp.register()
        defaults.set(true, forKey: "loginItemConfigured")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if mustBeMovedToApplications() || handOverToLaunchd() {
            NSApp.terminate(nil)
            return
        }
        buildWindows()
        if let path = argument("--snapshot") {
            takeSnapshot(to: path)
            return
        }
        configureLoginItemOnFirstRun()
        setupStatusItem()
        DistributedNotificationCenter.default().addObserver(forName: Self.showMenuNotification, object: nil,
                                                            queue: .main) { [weak self] _ in
            self?.statusItem?.button?.performClick(nil)
        }

        // Sfondo di sistema: la prima volta appena la pagina è pronta, poi ogni 3 minuti
        // (in 3 minuti la Terra ruota di 0,75°: la differenza non si vede)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.syncWallpaper() }
        wallpaperTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { [weak self] _ in
            self?.syncWallpaper()
        }
        statusTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.refreshVerifyStatus()
        }

        // verifica.sh chiede un'istantanea di controllo con il segnale USR1
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in self?.writeVerificationSnapshot() }
        source.resume()
        verifySignal = source

        let workspace = NSWorkspace.shared.notificationCenter
        for (name, asleep) in [(NSWorkspace.screensDidSleepNotification, true),
                               (NSWorkspace.screensDidWakeNotification, false),
                               (NSWorkspace.sessionDidResignActiveNotification, true),
                               (NSWorkspace.sessionDidBecomeActiveNotification, false)] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.screensAsleep = asleep
                self?.applyPause()
                if !asleep {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self?.syncWallpaper() }
                }
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.buildWindows()
        }
        // Ogni Scrivania (Space) ha il proprio sfondo di sistema: arrivandoci lo si aggiorna subito
        workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil,
                              queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self?.syncWallpaper() }
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.applyPause()
        }
    }

    private func buildWindows() {
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map {
            DesktopWindow(screen: $0, configuration: configuration, query: argument("--query") ?? "")
        }
        windows.forEach { $0.orderFrontRegardless() }
    }

    // Ferma le animazioni quando non servono: pausa scelta dall'utente, schermo spento,
    // sessione bloccata o Scrivania interamente coperta da altre finestre
    private func applyPause() {
        for window in windows {
            let hidden = !window.occlusionState.contains(.visible)
            let paused = userPaused || screensAsleep || hidden
            window.webView.evaluateJavaScript("window.astroPause && window.astroPause(\(paused))")
        }
    }

    // Con lo schermo spento o la Scrivania interamente coperta WebKit non disegna: un'istantanea
    // presa in quel momento (per esempio subito dopo un riavvio) sarebbe nera, quindi si aspetta
    private func syncWallpaper() {
        guard !screensAsleep else { return }
        windows.filter { $0.occlusionState.contains(.visible) }.forEach { wallpaper.update($0) }
    }

    // Istantanea di controllo per verifica.sh. A schermo spento, sessione bloccata o Scrivania
    // coperta WebKit non disegna e l'istantanea sarebbe nera: si risponde "non verificabile"
    // invece di far credere a un guasto
    private func writeVerificationSnapshot() {
        guard let window = windows.first else { return }
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        let locked = (session?["CGSSessionScreenIsLocked"] as? Bool) ?? false
        var reason: String?
        if screensAsleep || CGDisplayIsAsleep(CGMainDisplayID()) != 0 { reason = "schermo spento" }
        else if locked { reason = "sessione bloccata" }
        else if !window.occlusionState.contains(.visible) { reason = "Scrivania coperta da altre finestre" }
        if let reason {
            try? reason.write(to: supportFolder.appendingPathComponent("verifica.skip"), atomically: true, encoding: .utf8)
            return
        }
        snapshotJPEG(window.webView) { jpeg in
            try? jpeg?.write(to: supportFolder.appendingPathComponent("verifica.jpg"), options: .atomic)
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        // Le voci della verifica automatica esistono solo nell'installazione dai sorgenti
        if launchctl(["print", verifyAgent]) == 0 {
            let verify = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
            verify.isEnabled = false
            verifyItem = verify
            menu.addItem(withTitle: "Verifica adesso", action: #selector(verifyNow), keyEquivalent: "").target = self
            menu.addItem(withTitle: "Apri il registro delle verifiche", action: #selector(openVerifyLog), keyEquivalent: "").target = self
            menu.addItem(.separator())
        }
        menu.addItem(withTitle: "Ricarica lo sfondo", action: #selector(reload), keyEquivalent: "r").target = self
        let pause = menu.addItem(withTitle: "Metti in pausa le animazioni", action: #selector(togglePause), keyEquivalent: "p")
        pause.target = self
        pauseItem = pause
        menu.addItem(withTitle: "Personalizza luogo e impostazioni…", action: #selector(reveal), keyEquivalent: "").target = self
        if !managedByLaunchd {
            let login = menu.addItem(withTitle: "Apri all'accesso", action: #selector(toggleLoginItem), keyEquivalent: "")
            login.target = self
            loginItem = login
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Esci da Astro Sfondo", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
        statusItem = item
        refreshVerifyStatus()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshVerifyStatus()
        loginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        if service.status == .enabled { try? service.unregister() } else { try? service.register() }
        UserDefaults.standard.set(true, forKey: "loginItemConfigured")
    }

    // Icona e prima riga del menu riflettono l'esito dell'ultima verifica automatica
    private func refreshVerifyStatus() {
        let status = VerifyStatus.load()
        let problem = status.level == "error" || status.level == "warning"
        let symbol = problem ? "exclamationmark.triangle" : "globe.europe.africa"
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Astro Sfondo")

        let mark = ["ok": "✓", "info": "ℹ︎", "warning": "⚠︎", "error": "✕"][status.level] ?? "·"
        var title = "\(mark) \(status.summary)"
        if let time = status.time {
            let f = DateFormatter()
            f.locale = Locale(identifier: "it_IT")
            f.dateFormat = "d MMM, HH:mm"
            title += " · \(f.string(from: time))"
        }
        verifyItem?.title = title
        if status.details.isEmpty {
            verifyItem?.submenu = nil
        } else {
            let details = NSMenu()
            status.details.forEach { details.addItem(withTitle: $0, action: nil, keyEquivalent: "").isEnabled = false }
            verifyItem?.submenu = details
            verifyItem?.isEnabled = true
        }
    }

    @objc private func verifyNow() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["kickstart", verifyAgent]
        try? process.run()
    }

    @objc private func openVerifyLog() {
        NSWorkspace.shared.open(verifyLogURL)
    }

    @objc private func reload() {
        windows.forEach { $0.webView.reloadFromOrigin() }
    }

    @objc private func togglePause() {
        userPaused.toggle()
        pauseItem?.title = userPaused ? "Riprendi le animazioni" : "Metti in pausa le animazioni"
        applyPause()
    }

    // Uscita scelta dall'utente: rimette lo sfondo originale. Allo spegnimento invece non lo si
    // ripristina, così all'accesso successivo non compare per qualche secondo quello vecchio.
    @objc private func quit() {
        wallpaper.restoreOriginals()
        NSApp.terminate(nil)
    }

    // Installazione dai sorgenti: si modifica web/config.local.js nel progetto. Installazione dal
    // .dmg: si usa config.local.js nella cartella dati dell'app, creato qui con un modello.
    @objc private func reveal() {
        let projectConfig = webRoot.appendingPathComponent("config.local.js")
        guard webRoot.path.hasPrefix(Bundle.main.bundleURL.path) else {
            let exists = FileManager.default.fileExists(atPath: projectConfig.path)
            NSWorkspace.shared.activateFileViewerSelecting([exists ? projectConfig : webRoot.appendingPathComponent("config.js")])
            return
        }
        if !FileManager.default.fileExists(atPath: personalConfig.path) {
            let template = """
            // Impostazioni personali di Astro Sfondo. Togli "//" dalle righe da usare, cambia i valori,
            // salva e scegli "Ricarica lo sfondo" dal menu dell'app.
            export const CONFIG = {
              // location: { name: 'Roma', lat: 41.9028, lon: 12.4964 },
              // fps: 15,
            };

            """
            try? template.write(to: personalConfig, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.activateFileViewerSelecting([personalConfig])
    }

    private func takeSnapshot(to path: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            guard let webView = self.windows.first?.webView else { exit(1) }
            webView.takeSnapshot(with: nil) { image, error in
                guard let image, let tiff = image.tiffRepresentation,
                      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
                    FileHandle.standardError.write("snapshot non riuscito: \(String(describing: error))\n".data(using: .utf8)!)
                    exit(1)
                }
                try? png.write(to: URL(fileURLWithPath: path))
                exit(0)
            }
        }
    }
}

// Comandi di servizio per verifica.sh: rispondono e terminano senza aprire finestre
if let i = CommandLine.arguments.firstIndex(of: "--check-image"), i + 1 < CommandLine.arguments.count {
    guard let luminance = globeLuminance(of: CommandLine.arguments[i + 1]) else { exit(2) }
    print(String(format: "%.3f", luminance))
    exit(0)
}
if CommandLine.arguments.contains("--print-wallpaper") {
    print(NSScreen.main.flatMap { NSWorkspace.shared.desktopImageURL(for: $0)?.path } ?? "")
    exit(0)
}
if CommandLine.arguments.contains("--restore-wallpaper") { // usato da uninstall.sh
    WallpaperSync().restoreOriginals()
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
