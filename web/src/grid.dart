import 'dart:html';
import 'dart:math';

import 'io.dart';
import 'project.dart';

class Grid {
  final Project project;
  final DivElement el = querySelector('#grid');

  String _gridColor = '#fff';
  String get gridColor => _gridColor;
  set gridColor(String gridColor) {
    _gridColor = gridColor;
  }

  String get subGridColor => _gridColor + 'a';

  String _outsideColor = '#000c';
  String get outsideColor => _outsideColor;
  set outsideColor(String outsideColor) {
    _outsideColor = outsideColor;
    project.redraw();
  }

  Point<int> _array = Point(3, 3);
  Point<int> get array => _array;
  Point<int> get arrayPlus => _array + const Point(1, 1);
  set array(Point<int> array) {
    _array = array;
    (querySelector('#arrX') as InputElement).value = array.x.toString();
    (querySelector('#arrY') as InputElement).value = array.y.toString();
    _recalculateElementSize();
  }

  int _subdivisions = 2;
  int get subdivisions => _subdivisions;
  set subdivisions(int subdivisions) {
    _subdivisions = subdivisions;
  }

  Point _position;
  Point get position => _position;
  set position(Point position) {
    _position = position;
    el.style.left = (_position.x / project.zoom).toString() + 'px';
    el.style.top = (_position.y / project.zoom).toString() + 'px';
  }

  static Point<T> clamp<T extends num>(
      Point<T> point, Point<T> pMin, Point<T> pMax,
      [num inset = 0]) {
    return Point<T>(min(max(point.x, pMin.x), pMax.x + inset),
        min(max(point.y, pMin.y), pMax.y + inset));
  }

  Point _size;
  Point get size => _size;
  set size(Point size) {
    _size = size;
    _recalculateElementSize();
  }

  void _recalculateElementSize() {
    el.style.width = ((_size.x * arrayPlus.x) / project.zoom).toString() + 'px';
    el.style.height =
        ((_size.y * arrayPlus.y) / project.zoom).toString() + 'px';
  }

  static const minSize = Point<int>(50, 50);

  void immediateClamp() {
    size = clamp(size, minSize, project.size);
    position = clamp(position, Point(0, 0), project.size - size);
  }

  static const dragSensitivity = 0; // minimum distance to enable dragging

  Grid(this.project) {
    _position = Point(200, 200);
    _size = Point(100, 100);

    el.onMouseDown.listen((e) {
      var pos1 = position;
      var size1 = size;
      var arr1 = array;

      void Function(Point<int>) action;
      if (e.target != el) {
        var classes = (e.target as HtmlElement).classes;
        if (e.shiftKey) {
          var diffPosMax = arr1;
          var diffSizeMin = arr1 * -1;

          action = (diff) {
            diff = Point<int>(diff.x ~/ size.x, diff.y ~/ size.y);
            var x = pos1.x;
            var y = pos1.y;
            var width = arr1.x;
            var height = arr1.y;

            if (classes.contains('top')) {
              var v = min(diff.y, diffPosMax.y);
              y += v * size.y;
              height -= v;
            }
            if (classes.contains('right')) {
              width += max(diff.x, diffSizeMin.x);
            }
            if (classes.contains('bottom')) {
              height += max(diff.y, diffSizeMin.y);
            }
            if (classes.contains('left')) {
              var v = min(diff.x, diffPosMax.x);
              x += v * size.x;
              width -= v;
            }

            array = Point(width, height);
            position = Point(x, y);
          };
        } else {
          var diffPosMin = pos1 * -1;
          var diffPosMax = Point(size1.x * arrayPlus.x, size1.y * arrayPlus.y) -
              Point<num>(minSize.x, minSize.y);
          var diffSizeMin = Point<num>(minSize.x, minSize.y) -
              Point(size1.x * arrayPlus.x, size1.y * arrayPlus.y);
          var diffSizeMax = project.size -
              (pos1 + Point(size1.x * arrayPlus.x, size1.y * arrayPlus.y));

          action = (diff) {
            var x = pos1.x;
            var y = pos1.y;
            var width = size1.x;
            var height = size1.y;

            if (classes.contains('top')) {
              var v = min(max(diff.y, diffPosMin.y), diffPosMax.y);
              y += v;
              height -= v / arrayPlus.y;
            }
            if (classes.contains('right')) {
              width +=
                  min(max(diff.x, diffSizeMin.x), diffSizeMax.x) / arrayPlus.x;
            }
            if (classes.contains('bottom')) {
              height +=
                  min(max(diff.y, diffSizeMin.y), diffSizeMax.y) / arrayPlus.y;
            }
            if (classes.contains('left')) {
              var v = min(max(diff.x, diffPosMin.x), diffPosMax.x);
              x += v;
              width -= v / arrayPlus.x;
            }

            size = Point(width, height);
            position = Point(x, y);
          };
        }
      } else {
        var diffMax =
            project.size - Point(size1.x * arrayPlus.x, size1.y * arrayPlus.y);

        action = (diff) {
          position = clamp(pos1 + diff, Point(0, 0), diffMax);
        };
      }

      var mouse1 = Point<int>(e.client.x, e.client.y);
      var drag = false;
      var subMove = document.onMouseMove.listen((e) {
        if (e.movement.magnitude == 0) return;
        var diff = (Point<int>(e.client.x, e.client.y) - mouse1) * project.zoom;
        if (!drag &&
            diff.x * diff.x + diff.y * diff.y >=
                dragSensitivity * dragSensitivity) {
          drag = true;
        }

        if (drag) {
          action(diff);
          project.redraw();
        }
      });

      var subUp;
      subUp = document.onMouseUp.listen((e) {
        subMove.cancel();
        subUp.cancel();
      });
    });
  }

  Point<int> round(Point<num> p) {
    return Point<int>(p.x.round(), p.y.round());
  }

  void drawOn(CanvasRenderingContext2D ctx, Rectangle rect) {
    var zoom = project.zoom;
    var position = round(
        rect.topLeft + Point(this.position.x / zoom, this.position.y / zoom));
    var pos = Point<int>(position.x + 1, position.y + 1);
    var size = Point<int>(arrayPlus.x * this.size.x ~/ zoom + 1,
        arrayPlus.y * this.size.y ~/ zoom + 1);
    var sizeMinus = Point<int>(size.x - 1, size.y - 1);

    ctx.fillStyle = outsideColor;

    ctx.fillRect(0, 0, position.x, project.canvas.height);
    ctx.fillRect(position.x + size.x, 0,
        project.canvas.width - size.x - position.x, project.canvas.height);
    ctx.fillRect(position.x, 0, size.x, position.y);
    ctx.fillRect(position.x, position.y + size.y, size.x,
        project.canvas.height - size.y - position.y);

    ctx.strokeStyle = gridColor;
    ctx.strokeRect(
        pos.x.round() - 0.5, pos.y.round() - 0.5, size.x - 1, size.y - 1);

    for (var i = 1; i <= arrayPlus.x; i++) {
      ctx.strokeStyle = gridColor;

      var x = (pos.x + this.size.x * i / zoom).round() - 0.5;
      ctx.beginPath();
      ctx.moveTo(x, pos.y);
      ctx.lineTo(x, pos.y + sizeMinus.y - 1);
      ctx.stroke();

      ctx.strokeStyle = subGridColor;
      for (var sub = 0; sub < subdivisions; sub++) {
        var x1 = (x - (this.size.x * (sub + 1) / (subdivisions + 1)) / zoom)
                .round() -
            0.5;
        ctx.beginPath();
        ctx.moveTo(x1, pos.y);
        ctx.lineTo(x1, pos.y + sizeMinus.y - 1);
        ctx.stroke();
      }
    }
    for (var i = 1; i <= arrayPlus.y; i++) {
      ctx.strokeStyle = gridColor;

      var y = (pos.y + this.size.y * i / zoom).round() - 0.5;
      ctx.beginPath();
      ctx.moveTo(pos.x, y);
      ctx.lineTo(pos.x + sizeMinus.x - 1, y);
      ctx.stroke();

      ctx.strokeStyle = subGridColor;
      for (var sub = 0; sub < subdivisions; sub++) {
        var y1 = (y - (this.size.y * (sub + 1) / (subdivisions + 1)) / zoom)
                .round() -
            0.5;
        ctx.beginPath();
        ctx.moveTo(pos.x, y1);
        ctx.lineTo(pos.x + sizeMinus.x - 1, y1);
        ctx.stroke();
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'array': pointToJson(array),
        'subdivisions': subdivisions,
        'position': pointToJson(position),
        'size': pointToJson(size)
      };
  void fromJson(Map<String, dynamic> json) {
    array = pointFromJson(json['array']);
    subdivisions = json['subdivisions'];
    position = pointFromJson(json['position']);
    size = pointFromJson(json['size']);
  }
}
