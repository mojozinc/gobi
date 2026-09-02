import 'package:uuid/uuid.dart';

/// Hybrid Logical Clock (HLC) implementation for local-first event ordering.
/// Ensures consistent, monotonic ordering across distributed offline devices.
class HLC implements Comparable<HLC> {
  final int millis;
  final int counter;
  final String node;

  const HLC({
    required this.millis,
    required this.counter,
    required this.node,
  });

  /// Factory to generate a new HLC based on current physical time and last known HLC.
  factory HLC.now(String nodeId, [HLC? lastHlc]) {
    final physicalMillis = DateTime.now().toUtc().millisecondsSinceEpoch;

    if (lastHlc == null) {
      return HLC(millis: physicalMillis, counter: 0, node: nodeId);
    }

    if (physicalMillis > lastHlc.millis) {
      return HLC(millis: physicalMillis, counter: 0, node: nodeId);
    } else if (physicalMillis == lastHlc.millis) {
      return HLC(millis: lastHlc.millis, counter: lastHlc.counter + 1, node: nodeId);
    } else {
      // Clock drift backwards: preserve monotonicity
      return HLC(millis: lastHlc.millis, counter: lastHlc.counter + 1, node: nodeId);
    }
  }

  /// Parse HLC from serialized string: "millis:counter:node"
  factory HLC.parse(String str) {
    final parts = str.split(':');
    if (parts.length < 3) {
      return HLC(
        millis: DateTime.now().toUtc().millisecondsSinceEpoch,
        counter: 0,
        node: const Uuid().v4(),
      );
    }
    return HLC(
      millis: int.tryParse(parts[0]) ?? 0,
      counter: int.tryParse(parts[1]) ?? 0,
      node: parts.sublist(2).join(':'),
    );
  }

  /// Format HLC as sortable string
  String toHlcString() {
    return '$millis:$counter:$node';
  }

  @override
  int compareTo(HLC other) {
    if (millis != other.millis) {
      return millis.compareTo(other.millis);
    }
    if (counter != other.counter) {
      return counter.compareTo(other.counter);
    }
    return node.compareTo(other.node);
  }

  @override
  String toString() => toHlcString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HLC &&
          runtimeType == other.runtimeType &&
          millis == other.millis &&
          counter == other.counter &&
          node == other.node;

  @override
  int get hashCode => millis.hashCode ^ counter.hashCode ^ node.hashCode;
}
