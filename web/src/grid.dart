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

  Point<num> _position = Point(50, 50);
  Point<num> get position => _position;
  set position(Point<num> position) {
    _position = position;
    project.redraw();
  }

  Point<num> _size = Point(100, 100);
  Point<num> get size => _size;
  set size(Point<num> size) {
    _size = size;
    // will redraw twice if position is also changed
    project.redraw();
  }

  Grid(this.project) {
    el.onMouseDown.listen((e) {
      var off1 = e.client;
      var subMove = document.onMouseMove.listen((e) {
        position += e.client - off1;
      });

      var subUp;
      subUp = document.onMouseUp.listen((e) {
        subMove.cancel();
        subUp.cancel();
      });
    });
  }

  void drawOn(CanvasRenderingContext2D ctx) {
    ctx.strokeStyle = '#fff';

    for (var i = 0; i <= divisions.x; i++) {
      var x = position.x + size.x * (i / divisions.x);
      ctx.moveTo(x, position.y);
      ctx.lineTo(x, position.y + size.y);
    }
  }
}
