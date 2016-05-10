#!/usr/bin/swift

import Foundation

typealias ArgsArray = Array<String>

// MARK: - Functions
func collectArgs(env: [String : String]) -> ArgsArray {
    var args = ArgsArray()

    if let platform = env["platform"] {
        args.append("--platform " + platform)
    }

    if let verboseOutput = env["verbose_output"] where verboseOutput == "true" {
        args.append("--verbose")
    }

    if let noUseBinaries = env["no_use_binaries"] where noUseBinaries == "true" {
        args.append("--no-use-binaries")
    }

    if let sshOutput = env["ssh_output"] where sshOutput == "true" {
        args.append("--use-ssh")
    }

    if let carthageOptions = env["carthage_options"] {
        args.append(carthageOptions)
    }

    return args
}

/// Runs `carthage ${carthage_command}`. Returns true iff successful.
func carthage(env: [String: String]) -> Bool {
    let task = NSTask()

    if let workingDir = env["working_dir"] where workingDir != "" {
        task.currentDirectoryPath = workingDir
    }

    guard let carthageCommand = env["carthage_command"] else {
        print("No carthage command to execute.")
        exit(1)
    }

    let command = "carthage \(carthageCommand)"
    let args = " " + ( collectArgs(env).map { "\($0)" } ).joinWithSeparator(" ")

    task.launchPath = "/bin/bash"
    task.arguments = ["-c", command + args]

    print("Running carthage command: \(task.arguments!.reduce("") { str, arg in str + "\(arg) " })")

    // run the shell command
    task.launch()
    //
    // // ensure to be finished before another command can run
    task.waitUntilExit()

    return task.terminationStatus == 0
}

func requiresCarthage(env: [String: String]) -> Bool {
    guard let command = env["carthage_command"] where command != "update" else {
        return true
    }

    let task = NSTask()

    if let directory = env["working_dir"] {
        task.currentDirectoryPath = directory
    }

    task.launchPath = "/usr/bin/diff"
    task.arguments = ["Cartfile.resolved", "Carthage/bitrise-Cartfile.resolved"]
    task.standardError = nil
    task.standardOutput = nil
    task.launch()
    task.waitUntilExit()

    return task.terminationStatus != 0
}

/// Copies the resolved Cartfile to Carthage. Returns true iff successful
@available(OSX, introduced=10.11)
func copyCartfile(env: [String: String]) -> Bool {
    let fm = NSFileManager.defaultManager()
    let currentDirectoryPath = NSURL(fileURLWithPath: fm.currentDirectoryPath, isDirectory: true)
    let workingDirectoryURL = NSURL(fileURLWithPath: (env["working_dir"] ?? "."), relativeToURL: currentDirectoryPath)

    let cartfileURL = workingDirectoryURL.URLByAppendingPathComponent("Cartfile.resolved")
    let cartfileCopyURL = workingDirectoryURL.URLByAppendingPathComponent("Carthage/bitrise-Cartfile.resolved")

    do {
      try fm.copyItemAtURL(cartfileURL, toURL: cartfileCopyURL)
      print("Copying Cartfile.resolved to '\(cartfileCopyURL.path!)'")
      return true
    } catch {
      print("Error copying Cartfile.resolved to '\(cartfileCopyURL.path!)'")
      return false
    }
}

// MARK: Step

if #available(OSX 10.11, *) {
  let env = NSProcessInfo.processInfo().environment

  if requiresCarthage(env) {
      guard carthage(env) else {
          print("Error while running carthage.")
          exit(1)
      }

      copyCartfile(env)
  } else {
      print("Cached carthage content matches Cartfile.resolved, skipping Carthage.")
      exit(0)
  }  
} else {
  print("Carthage step requires at least OS X 10.11")
  exit(1)
}
