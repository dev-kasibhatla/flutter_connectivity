import 'dart:io';

import 'package:flutter_connectivity/flutter_connectivity.dart';
import 'package:log_plus/log_plus.dart';

Logs log = Logs();

void main() {
  startConnectivityMonitor();
}

void startConnectivityMonitor() {
  // Initialize the FlutterConnectivity instance. Endpoint is where the network requests are sent
  // to check the network latency.
  FlutterConnectivity connectivity =
      FlutterConnectivity(endpoint: 'https://example.com');

  // OPTIONAL: Configure the FlutterConnectivity instance.
  connectivity.configure(
    allowedFailedRequests: 2,
    checkInterval: const Duration(seconds: 3),
    logLevel: LogLevel.error,
  );

  // OPTIONAL: Set the latency thresholds for each connectivity status.
  connectivity.setLatencyThresholds(
    disconnected: 10000,
    slow: 5000,
    moderate: 2000,
    fast: 1000,
  );

  // Start the connectivity monitor.
  connectivity.listenToLatencyChanges((ConnectivityStatus status, int latency) {
    switch (status) {
      case ConnectivityStatus.disconnected:
        log.e('Disconnected: $latency ms\n');
        break;
      case ConnectivityStatus.slow:
        log.w('Slow: $latency ms\n');
        break;
      case ConnectivityStatus.moderate:
        log.i('Moderate: $latency ms\n');
        break;
      case ConnectivityStatus.fast:
        log.i('Fast: $latency ms\n');
        break;
    }
  });

  Future.delayed(const Duration(seconds: 41), () => {
    log.w('Pausing connectivity monitor\n'),
    // Pause the connectivity monitor.
    connectivity.pause(),
  });

  Future.delayed(const Duration(seconds: 51), () => {
    log.i('Resuming connectivity monitor\n'),
    // Resume the connectivity monitor when paused.
    connectivity.resume(),
  });

  Future.delayed(const Duration(seconds: 81), () => {
    log.w('Disposing connectivity monitor\n'),
    // Dispose the connectivity monitor when done.
    log.v(connectivity.latencyHistory),
    connectivity.dispose(),
    exit(0)
  });
}
