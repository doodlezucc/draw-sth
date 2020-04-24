import 'dart:convert';
import 'dart:math';

final _encoder = JsonEncoder.withIndent('  ');
String toJsonString(Object o) => _encoder.convert(o);

Map<String, dynamic> pointToJson(Point p) => {'x': p.x, 'y': p.y};

Point<T> pointFromJson<T extends num>(Map<String, dynamic> json) =>
    Point<T>(json['x'], json['y']);
