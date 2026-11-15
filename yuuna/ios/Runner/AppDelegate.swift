import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FolderImportPlugin") {
      FolderImportPlugin.register(with: registrar)
    }
  }
}

/// Hides the status bar on devices that show it as a sidebar.
///
/// The iPhone Duo puts the status bar in a column down the right edge of both
/// displays, taking a strip of every page. Other iPhones keep their status bar
/// across the top. A visible status bar that leaves no top inset but a side
/// inset is a sidebar; once seen it is known for the device, so it stays
/// hidden after that. Flutter can still hide the status bar anywhere, such as
/// in immersive readers.
final class RunnerViewController: FlutterViewController {
  private var statusBarIsSidebar = false

  override var prefersStatusBarHidden: Bool {
    return super.prefersStatusBarHidden || statusBarIsSidebar
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let insets = view.safeAreaInsets
    guard !statusBarIsSidebar,
      view.window?.windowScene?.statusBarManager?.isStatusBarHidden == false,
      insets.top == 0,
      insets.left > 0 || insets.right > 0
    else { return }
    statusBarIsSidebar = true
    setNeedsStatusBarAppearanceUpdate()
  }
}

/// Lets the user pick a folder anywhere in Files (iCloud Drive, Downloads,
/// external drives) and copies it into the app's Documents folder.
///
/// Mokuro volumes are an HTML file next to a folder of page images, and a
/// WKWebView can only load them from inside the app sandbox. Access to a
/// picked folder is security scoped and ends with the session, so the folder
/// is copied while access lasts. A folder already inside Documents is used in
/// place, and a folder imported before is reused.
final class FolderImportPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private var pendingResult: FlutterResult?
  private var destinationRoot: URL?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "app.arianneorpilla.yuuna/folder_import",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(FolderImportPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "importFolder",
      let arguments = call.arguments as? [String: Any],
      let destination = arguments["destination"] as? String
    else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pendingResult == nil else {
      result(FlutterError(code: "busy", message: "A folder is already being picked", details: nil))
      return
    }
    guard let presenter = Self.topViewController() else {
      result(FlutterError(code: "no_window", message: "No window to present from", details: nil))
      return
    }

    pendingResult = result
    destinationRoot = URL(fileURLWithPath: destination, isDirectory: true)

    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingResult, let root = destinationRoot, let url = urls.first else {
      return
    }
    pendingResult = nil
    DispatchQueue.global(qos: .userInitiated).async {
      let response = Self.importFolder(url, into: root)
      DispatchQueue.main.async { result(response) }
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingResult?(nil)
    pendingResult = nil
  }

  private static func importFolder(_ url: URL, into root: URL) -> Any? {
    let accessing = url.startAccessingSecurityScopedResource()
    defer {
      if accessing {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let fileManager = FileManager.default
    let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .resolvingSymlinksInPath().path
    let picked = url.resolvingSymlinksInPath()
    if picked.path == documents || picked.path.hasPrefix(documents + "/") {
      return picked.path
    }

    let target = root.appendingPathComponent(url.lastPathComponent, isDirectory: true)
    if fileManager.fileExists(atPath: target.path) {
      return target.path
    }

    var coordinationError: NSError?
    var copyError: Error?
    // Coordinated reading downloads iCloud items that are not on the device.
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) {
      readableURL in
      do {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.copyItem(at: readableURL, to: target)
      } catch {
        copyError = error
      }
    }

    if let error = copyError ?? coordinationError {
      try? fileManager.removeItem(at: target)
      return FlutterError(code: "copy_failed", message: error.localizedDescription, details: nil)
    }
    return target.path
  }

  private static func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}
