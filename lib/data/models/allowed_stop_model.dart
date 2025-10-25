class AllowedStop {
  final String allowedStopId;
  final int officialRouteId;
  final String stopName;
  final String stopAddress;
  final double stopLat;
  final double stopLng;
  final int? stopOrder;
  final bool isActive;
  final DateTime createdAt;

  AllowedStop({
    required this.allowedStopId,
    required this.officialRouteId,
    required this.stopName,
    required this.stopAddress,
    required this.stopLat,
    required this.stopLng,
    this.stopOrder,
    required this.isActive,
    required this.createdAt,
  });

  factory AllowedStop.fromJson(Map<String, dynamic> json) {
    return AllowedStop(
      allowedStopId: json['allowedstop_id'] as String,
      officialRouteId: json['officialroute_id'] as int,
      stopName: json['stop_name'] as String,
      stopAddress: json['stop_address'] as String,
      stopLat: double.parse(json['stop_lat'] as String),
      stopLng: double.parse(json['stop_lng'] as String),
      stopOrder: json['stop_order'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allowedstop_id': allowedStopId,
      'officialroute_id': officialRouteId,
      'stop_name': stopName,
      'stop_address': stopAddress,
      'stop_lat': stopLat.toString(),
      'stop_lng': stopLng.toString(),
      'stop_order': stopOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => stopName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AllowedStop &&
          runtimeType == other.runtimeType &&
          allowedStopId == other.allowedStopId;

  @override
  int get hashCode => allowedStopId.hashCode;
}
