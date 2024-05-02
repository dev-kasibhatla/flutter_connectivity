library flutter_connectivity;

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:log_plus/log_plus.dart';

/// Enum representing the connectivity status.
///
/// The connectivity status is categorized as follows:
/// - `ConnectivityStatus.disconnected`: Represents a state where the network latency is too high or there is no network connection.
/// - `ConnectivityStatus.slow`: Represents a state where the network latency is high, but there is a network connection.
/// - `ConnectivityStatus.moderate`: Represents a state where the network latency is moderate.
/// - `ConnectivityStatus.fast`: Represents a state where the network latency is low, indicating a fast network connection.
enum ConnectivityStatus {
  disconnected,
  slow,
  moderate,
  fast,
}

class FlutterConnectivity {
  /// Simulates a network request to a server every [_checkInterval].
  Duration _checkInterval = const Duration(seconds: 3);

  /// History of latencies from the network requests with timestamps.
  final Map<int, int> _latencies = <int, int>{};
  Map<int,int> get latencyHistory => _latencies;

  static const int _latencyHistoryLimit = 100;

  Function? _onLatencyChange;

  /// The endpoint to send network requests to.
  String _endpoint = 'https://example.com';

  Logs _log = Logs(
    inReleaseMode: false,
    printLogLevelWhenDebug: LogLevel.debug,
    printLogLevelWhenRelease: LogLevel.error,
    storeLimit: 100,
    storeLogLevel: LogLevel.warning,
  );

  /// The number of failed requests allowed before the connectivity status is downgraded.
  int _allowedFailedRequests = 2;

  /// The latency thresholds for each connectivity status.
  final Map<ConnectivityStatus, int> _latencyThresholds = {
    ConnectivityStatus.disconnected: 3000,
    ConnectivityStatus.slow: 1000,
    ConnectivityStatus.moderate: 500,
    ConnectivityStatus.fast: 200,
  };

  /// The latency thresholds are used to categorize the connectivity status based on the network latency.
  /// The connectivity status is categorized as follows:
  /// - `ConnectivityStatus.disconnected` if the latency is greater than or equal to the `disconnected` threshold.
  /// - `ConnectivityStatus.slow` if the latency is less than the `disconnected` threshold and greater than or equal to the `slow` threshold.
  /// - `ConnectivityStatus.moderate` if the latency is less than the `slow` threshold and greater than or equal to the `moderate` threshold.
  /// - `ConnectivityStatus.fast` if the latency is less than the `moderate` threshold.
  ConnectivityStatus _currentStatus = ConnectivityStatus.fast;
  ConnectivityStatus get currentStatus => _currentStatus;

  /// The last time a network request was made.
  int _lastRequestTime = 0;

  FlutterConnectivity({String endpoint = 'https://example.com'}) {
    _endpoint = endpoint;
    _currentStatus = ConnectivityStatus.fast;
    _startTimer();
  }

  /// Sets the latency thresholds for each connectivity status.
  ///
  /// The default thresholds are:
  /// - `disconnected`: 3000 milliseconds
  /// - `slow`: 1000 milliseconds
  /// - `moderate`: 500 milliseconds
  /// - `fast`: 200 milliseconds
  ///
  /// These defaults can be overridden by providing new values as parameters to this method.
  ///
  /// [disconnected] The latency threshold for the `ConnectivityStatus.disconnected` status. Default is 3000 milliseconds.
  /// [slow] The latency threshold for the `ConnectivityStatus.slow` status. Default is 1000 milliseconds.
  /// [moderate] The latency threshold for the `ConnectivityStatus.moderate` status. Default is 500 milliseconds.
  /// [fast] The latency threshold for the `ConnectivityStatus.fast` status. Default is 200 milliseconds.
  void setLatencyThresholds({
    int disconnected = 3000,
    int slow = 1000,
    int moderate = 500,
    int fast = 200,
  }) {
    _latencyThresholds[ConnectivityStatus.disconnected] = disconnected;
    _latencyThresholds[ConnectivityStatus.slow] = slow;
    _latencyThresholds[ConnectivityStatus.moderate] = moderate;
    _latencyThresholds[ConnectivityStatus.fast] = fast;
  }

  /// Configures the parameters for the FlutterConnectivity instance.
  ///
  /// This method allows you to set the following parameters:
  /// - `checkInterval`: The interval in milliseconds at which network requests are made to check the connectivity status. Default is 3000 milliseconds i.e every 3 seconds.
  /// - `allowedFailedRequests`: The number of failed network requests allowed before the connectivity status is downgraded. Default is 2.
  ///
  /// [checkInterval] The interval in milliseconds at which network requests are made. Default is 1000 milliseconds.
  /// [allowedFailedRequests] The number of failed network requests allowed before the connectivity status is downgraded. Default is 2.
  void configure({
    Duration checkInterval = const Duration(seconds: 3),
    int allowedFailedRequests = 2,
    LogLevel logLevel = LogLevel.error,
  }) {
    _checkInterval = checkInterval;
    _allowedFailedRequests = allowedFailedRequests;

    _log = Logs(
      inReleaseMode: true,
      printLogLevelWhenDebug: logLevel,
      printLogLevelWhenRelease: logLevel,
      storeLimit: 100,
      storeLogLevel: LogLevel.warning,
    );
    //since the configuration has changed, we need to restart the timer
    pause();
    resume();
  }

  late Timer _timer;

  void _startTimer() {
    _checkConnectivity();
    _timer = Timer.periodic(_checkInterval, (timer) {
      _checkConnectivity();
    });
  }

  void dispose() {
    _timer.cancel();
  }

  void pause() {
    _timer.cancel();
  }

  void resume() {
    _startTimer();
  }

  Future _checkConnectivity() async {
    //send a GET request to the endpoint
    try {
      final Request request = http.Request('GET', Uri.parse(_endpoint));
      int startTime = DateTime.now().millisecondsSinceEpoch;
      http.StreamedResponse response = await request.send();
      int endTime = DateTime.now().millisecondsSinceEpoch;
      if (response.statusCode == 200) {
        _lastRequestTime = endTime;
        _latencies[_lastRequestTime] = endTime - startTime;
      } else {
        _log.e('Failed request. Status code: ${response.statusCode}');
        _latencies[_lastRequestTime] = -1;
      }
    } catch (e) {
      _log.e('Failed request. $e', includeTrace: true);
      _latencies[_lastRequestTime] = -1;
    }
    _trimLatencies();
    _setStatus();
  }

  /// If history of latencies exceeds [_latencyHistoryLimit], remove the oldest latency.
  void _trimLatencies() {
    if (_latencies.length > _latencyHistoryLimit) {
      int oldestTime = _latencies.keys.first;
      _latencies.remove(oldestTime);
    }
  }

  void _setStatus() {
    int latency = getCurrentLatency();
    if (latency == -1) {
      _currentStatus = ConnectivityStatus.disconnected;
    } else {
      _currentStatus = ConnectivityStatus.disconnected;
      for (ConnectivityStatus status in _latencyThresholds.keys.toList().reversed) {
        if (latency <= _latencyThresholds[status]!) {
          _currentStatus = status;
          break;
        }
      }
    }

    if (_onLatencyChange != null) {
      _onLatencyChange!(_currentStatus, latency);
    }

  }

  /// Sets the callback function to be called when there are changes in network latency.
  ///
  /// This method allows you to listen to changes in network latency and perform actions based on the current connectivity status and latency.
  ///
  /// Note: Setting a callback function will remove any previously set callback function.
  ///
  /// [callback] The function to be called when there are changes in network latency. The function should take two parameters: a `ConnectivityStatus` indicating the current connectivity status, and an `int` representing the current network latency.
  void listenToLatencyChanges(
      Function(ConnectivityStatus connectivityStatus, int latency) callback) {
    _onLatencyChange = callback;
  }

  /// Returns the current network latency.
  ///
  /// This method calculates the current network latency based on the history of latencies stored in [_latencies].
  ///
  /// **Developer notes:**
  ///
  /// Returns:
  /// - `-1` if [_latencies] is empty.
  /// - The last recorded latency or `-1` if there is no recorded latency and the length of [_latencies] is less than 3.
  /// - `-1` if all of the missed latencies are -1 and the length of [_latencies] is greater than or equal to [_allowedFailedRequests].
  /// - The last latency that is not -1 if any of the last 3 latencies is -1.
  /// - The average of the last 3 latencies if none of the above conditions are met.
  int getCurrentLatency() {
    if (_latencies.isEmpty) {
      return -1;
    }
    if (_latencies.length < 3) {
      _log.v('latencies length < 3');
      return _latencies[_lastRequestTime] ?? -1;
    }

    //check missed latencies
    if (_latencies.length >= _allowedFailedRequests) {
      List<int> missedLatencies = _latencies.values
          .toList()
          .reversed
          .toList()
          .sublist(0, _allowedFailedRequests);
      //if all of missed latencies are -1, return -1
      if (missedLatencies.every((element) => element == -1)) {
        return -1;
      } 
      if (missedLatencies.contains(-1)) {
        //return the last latency that is not -1. Note that the list is reversed
        return missedLatencies.firstWhere((element) => element != -1);
      }
    }

    //get last 3 latencies (average for better consistency)
    List<int> last3Latencies =
        _latencies.values.toList().reversed.toList().sublist(0, 3);
    if (last3Latencies.contains(-1)) {
      // return the last latency that is not -1 from [_latencies]
      return _latencies.values.lastWhere((element) => element != -1);
    }
    return last3Latencies.reduce((a, b) => a + b) ~/ last3Latencies.length;
  }
}
