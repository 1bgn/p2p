/// concat_dart_files.dart
///
/// Concatenates all Dart source files **and every `pubspec.yaml`** (without
/// `pubspec.lock`) into a single text file with clear path markers – handy for
/// passing an entire Melos mono‑repo to an LLM.
///
/// Features
/// --------
/// * **Melos‑aware**: if `melos.yaml` is present, scans only packages from
///   `melos list --json`.
/// * **Self‑exclusion**: this script (`concat_dart_files.dart`) never lands in
///   the dump.
/// * Skips common build/cache dirs (`build/`, `.dart_tool/`, `.git/`, …).
/// * Deduplicates files even if reachable via several package roots.
///
/// Usage
/// -----
/// ```bash
/// dart concat_dart_files.dart [output_file] [root_directory]
/// ```
/// * `output_file`    – optional (default: `project_dump.txt`).
/// * `root_directory` – optional (default: current directory).
///
/// Example
/// -------
/// ```bash
/// dart concat_dart_files.dart all.txt .
/// ```
///
/// **Install Melos CLI** (for workspace support):
/// ```bash
/// dart pub global activate melos
/// ```
import 'dart:io';
import 'dart:convert';

Future<void> main(List<String> args) async {
  final outputPath = args.isNotEmpty ? args[0] : 'project_dump.txt';
  final rootDirPath = args.length > 1 ? args[1] : Directory.current.path;
  final rootDir = Directory(rootDirPath);

  if (!await rootDir.exists()) {
    stderr.writeln('Root directory does not exist: $rootDirPath');
    exit(1);
  }

  // Directories to ignore entirely.
  const ignoreDirs = {
    'build',
    '.dart_tool',
    '.pub',
    '.git',
  };

  // If inside a Melos workspace, limit scanning to declared packages.
  final melosDirs = await _detectMelosPackages(rootDir);
  final scanDirs = melosDirs ?? [rootDir];

  // Absolute path of this script so we can exclude it.
  final selfPath = File.fromUri(Platform.script).absolute.path;

  // Prepare / truncate output file.
  final outputFile = File(outputPath);
  if (await outputFile.exists()) {
    await outputFile.writeAsString('');
  }
  final output = outputFile.openWrite();

  final visited = <String>{};

  bool _isPubspecYaml(String p) => p.endsWith('pubspec.yaml');

  for (final dir in scanDirs) {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      final segments = entity.uri.pathSegments;
      if (segments.any(ignoreDirs.contains)) continue;

      final isDart = path.endsWith('.dart');
      final isPubspec = _isPubspecYaml(path);

      if (!(isDart || isPubspec)) continue;
      if (isDart && File(path).absolute.path == selfPath) continue; // skip self

      if (!visited.add(path)) continue; // avoid duplicates

      final relativePath = path.replaceFirst(
        rootDir.path.endsWith(Platform.pathSeparator)
            ? rootDir.path
            : rootDir.path + Platform.pathSeparator,
        '',
      );

      output.writeln('//== FILE: $relativePath ==//');
      output.write(await entity.readAsString());
      output.writeln('\n//== END FILE: $relativePath ==//\n');
    }
  }

  await output.close();
  stdout.writeln('✓ Concatenated ${visited.length} Dart/pubspec.yaml file(s) into "$outputPath"');
}

/// Detects Melos workspace packages using `melos list --json`.
/// Returns `null` if no `melos.yaml` is found or Melos isn’t available.
Future<List<Directory>?> _detectMelosPackages(Directory root) async {
  final melosConfig = File('${root.path}${Platform.pathSeparator}melos.yaml');
  if (!await melosConfig.exists()) return null;

  try {
    final result = await Process.run(
      'melos',
      ['list', '--json'],
      workingDirectory: root.path,
    );

    if (result.exitCode != 0) {
      stderr.writeln('melos list failed (exit ${result.exitCode}). Falling back.');
      return null;
    }

    final dynamic data = jsonDecode(result.stdout as String);
    if (data is! List) return null;

    return data
        .whereType<Map>()
        .map((pkg) => Directory(pkg['path'] as String))
        .toList();
  } on ProcessException {
    stderr.writeln('Melos CLI not found; install with "dart pub global activate melos".');
  } catch (e) {
    stderr.writeln('Error while detecting Melos packages: $e');
  }
  return null;
}
