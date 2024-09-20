import Cocoa
import Darwin
import Foundation
import System
import Wait

/// Adapts FileHandle to TextOutputStream, with optional coloring.
struct FileHandleTextOutputStream: TextOutputStream {
  static let sgrRed = "\u{1b}[31m"  // red foreground
  static let sgrNormal = "\u{1b}[0m"
  var handle: FileHandle
  let useColor: Bool

  init(_ handle: FileHandle) {
    self.handle = handle
    self.useColor = getenv("NO_COLOR") == nil && 1 == Darwin.isatty(handle.fileDescriptor)
  }

  public func write(_ string: String) {
    var string =
      if useColor {
        Self.sgrRed + string + Self.sgrNormal
      } else {
        string
      }
    string.withUTF8 { try? handle.write(contentsOf: $0) }
  }
}

/// Type for the main entry point.
@main
struct Main {
  /// The macOS bundle identifier for Neovide.
  static let bundleId = "com.neovide.neovide"

  /// Main entry point.
  static func main() async {
    // Errors will be written to standard error.
    var stderr = FileHandleTextOutputStream(FileHandle.standardError)

    // Find Neovide using LaunchServices.
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
      print("Cannot find Neovide.", to: &stderr)
      exit(EX_UNAVAILABLE)
    }
    // Open the Neovide bundle on the file system.
    guard let bundle = Bundle.init(url: url) else {
      print("Could not read Neovide bundle.", to: &stderr)
      exit(EX_OSFILE)
    }
    // Resolve the full path to the Neovide executable.
    guard let path = bundle.executablePath else {
      print("Could not find executable in Neovide bundle.", to: &stderr)
      exit(EX_OSFILE)
    }

    // Determine whether the `--fork` option was specified.
    let (doFork, arguments) = {
      func isForkOption(_ option: String) -> Bool {
        ["--fork", "--no-fork"].contains(option)
      }
      let arguments =
        CommandLine.arguments
        .dropFirst(1)
        .split(separator: "--", maxSplits: 1, omittingEmptySubsequences: false)
      var neovideArguments = if arguments.count > 0 { [String](arguments[0]) } else { [String]() }
      let neovimArguments = if arguments.count > 1 { [String](arguments[1]) } else { [String]() }
      let forkOption = neovideArguments.last(where: isForkOption)
      neovideArguments.removeAll(where: isForkOption)
      let reconstructed =
        if neovimArguments.count > 0 {
          neovideArguments + ["--"] + neovimArguments
        } else {
          neovideArguments
        }
      return (forkOption == "--fork", reconstructed)
    }()

    // Construct the argument list for posix_spawn.
    let argv = ([path] + arguments)
      .map { $0.withCString(strdup) }
    defer { argv.forEach { free($0) } }

    NSApplication.shared.yieldActivation(toApplicationWithBundleIdentifier: bundleId)

    // Use posix_spawn to launch Neovide.
    var pid: pid_t = 0
    let rc = posix_spawn(&pid, path, nil, nil, argv + [nil], Darwin.environ)
    guard rc == 0 else {
      let errno = Errno(rawValue: Darwin.errno)
      print("exec \(path) failed: [\(errno.rawValue): \(errno)]", to: &stderr)
      exit(EX_UNAVAILABLE)
    }

    // Neovide may launch successfully, yet encounter a problem shortly
    // afterwards and exit. We monitor for a moment in case this
    // happens, so that we can report the error, both with a message to
    // the console and with exit status.
    var activated = false
    for _ in 1...5 {
      // Cooperate to give focus to the newly launched Neovide.
      if !activated, let app = NSRunningApplication(processIdentifier: pid) {
        NSApplication.shared.yieldActivation(to: app)
        activated = app.activate()
      }

      // Allow some time to pass.
      try! await Task.sleep(nanoseconds: 100_000_000)

      // Check whether Neovide is still running.
      // If we successfully activated and `--no-fork` was specified,
      // we will wait indefinitely for Neovide to exit.
      // Otherwise, we’ll check a fixed number of times.
      let waitOptions = if activated && !doFork { Int32(0) } else { WNOHANG }
      var status = Int32(0)
      let rc = waitpid(pid, &status, waitOptions)
      guard rc == 0 || status == 0 else {
        print("\(path) \(status.descriptionAsWaitStatus)", to: &stderr)
        status = if wifexited(status) { wexitstatus(status) } else { EX_SOFTWARE }
        exit(status)
      }

      // If we waited indefinitely for Neovide and it exited without
      // error, we do not need to continue checking.
      if waitOptions == 0 { break }
    }
  }
}

extension Int32 {
  /// Return a description of the wait status this represents.
  var descriptionAsWaitStatus: String {
    if wifexited(self) {
      "exited with status \(wexitstatus(self))"
    } else if wifsignaled(self) {
      "terminated on signal \(wtermsig(self))"
    } else if wifstopped(self) {
      "stopped on signal \(wstopsig(self))"
    } else {
      "unknown status value \(self)"
    }
  }
}
