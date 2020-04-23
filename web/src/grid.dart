import 'dart:html';

import 'project.dart';

class Grid {
  final Project project;
  final DivElement el = querySelector('#grid');

  Point<int> _divisions = Point(1, 2);
  Point<int> get divisions => _divisions;
  set divisions(Point<int> divisions) {
    _divisions = divisions;
    project.redraw();
  }

  int _subdivisions = 2;
  int get subdivisions => _subdivisions;
  set subdivisions(int subdivisions) {
    _subdivisions = subdivisions;
    project.redraw();
  }

  Point<num> _position;
  Point<num> get position => _position;
  set position(Point<num> position) {
    _position = position;
    el.style.left = position.x.toString() + 'px';
    el.style.top = position.y.toString() + 'px';
  }

  Point<num> _size;
  Point<num> get size => _size;
  set size(Point<num> size) {
    _size = size;
    el.style.width = size.x.toString() + 'px';
    el.style.height = size.y.toString() + 'px';
  }

  static const dragSensitivity = 10;

  Grid(this.project) {
    position = Point(50, 50);
    size = Point(100, 100);

    el.onMouseDown.listen((e) {
      var mouse1 = e.client;
      var pos1 = position;
      var drag = false;
      var subMove = document.onMouseMove.listen((e) {
        if (e.movement.magnitude == 0) return;

        var newPos = pos1 + e.client - mouse1;
        if (!drag &&
            position.squaredDistanceTo(newPos) >=
                dragSensitivity * dragSensitivity) {
          drag = true;
        }

        if (drag) {
          position = newPos;
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

  void drawOn(CanvasRenderingContext2D ctx) {
    ctx.fillStyle = '#fff6';

    ctx.fillRect(position.x, position.y, size.x, size.y);

    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1;
    ctx.beginPath();

    var lines = Point<int>(divisions.x + 1, divisions.y + 1);

    for (var i = 0; i <= lines.x; i++) {
      var x = position.x + size.x * (i / lines.x) - 0.5;
      ctx.moveTo(x, position.y);
      ctx.lineTo(x, position.y + size.y);
    }
    for (var i = 0; i <= lines.y; i++) {
      var y = position.y + size.y * (i / lines.y) - 0.5;
      ctx.moveTo(position.x, y);
      ctx.lineTo(position.x + size.x, y);
    }
    ctx.closePath();
    ctx.stroke();
  }
}
