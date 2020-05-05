import 'dart:html';

import 'grid.dart';
import 'project.dart';

abstract class Canvas {
  final CanvasElement e;

  void resize(int width, int height) {
    e.width = width;
    e.height = height;
  }

  Canvas(String canvasId) : e = querySelector('canvas#$canvasId');
}

class SimpleCanvas extends Canvas {
  final void Function(CanvasRenderingContext2D ctx, int width, int height)
      _draw;

  SimpleCanvas(String canvasId, this._draw) : super(canvasId);

  void redraw() {
    _draw(e.context2D, e.width, e.height);
  }

  @override
  void resize(int width, int height, {bool redraw = true}) {
    e.width = width;
    e.height = height;
    if (redraw) this.redraw();
  }
}

class EditorCanvas extends Canvas {
  final void Function(CanvasRenderingContext2D ctx, int width, int height,
      Rectangle<int> dest, double zoom) _draw;

  EditorCanvas(String canvasId, this._draw) : super(canvasId);

  void redraw(Rectangle<int> dest, double zoom) {
    _draw(e.context2D, e.width, e.height, dest, zoom);
  }
}

class Canvases {
  static String filter = 'none';
  static Project project;

  static final ImageElement img = querySelector('img#main');

  static final filteredImg = SimpleCanvas('img', (ctx, w, h) {
    ctx
      ..filter = filter
      ..drawImage(img, 0, 0);
  });

  static final inverted = SimpleCanvas('inverted', (ctx, w, h) {
    ctx
      ..filter = 'invert(1) grayscale(1) brightness(0.8) contrast(1000)'
      ..drawImage(filteredImg.e, 0, 0);
  });

  static void resizeEditor(int width, int height) {
    _gridified.resize(width, height);
    _main.resize(width, height);
  }

  static void redrawEditor() {
    var client = project.editor.client;
    var center = client.bottomRight * 0.5;

    var dest = Rectangle.fromPoints(
        Grid.round(center +
            (project.size * -0.5 + project.offset) * (1 / project.zoom)),
        Grid.round(center +
            (project.size * 0.5 + project.offset) * (1 / project.zoom)));

    redrawEditorCustom(dest, project.zoom);
  }

  static void redrawEditorCustom(Rectangle<int> dest, double zoom) {
    _gridified.redraw(dest, zoom);
    _main.redraw(dest, zoom);
  }

  static String editorExport() {
    var w = _main.e.width;
    var h = _main.e.height;

    resizeEditor(img.width, img.height);
    redrawEditorCustom(Rectangle(0, 0, img.width, img.height), 1);

    var dataUrl = _main.e.toDataUrl('image/png');

    resizeEditor(w, h);
    redrawEditor();

    return dataUrl;
  }

  static final _gridified = EditorCanvas('gridified', (ctx, w, h, dest, zoom) {
    ctx.globalCompositeOperation = 'source-over';
    ctx.imageSmoothingQuality = 'high';
    ctx.clearRect(0, 0, w, h);

    ctx.drawImageToRect(filteredImg.e, dest);
    project.grid.drawOn(ctx, dest, zoom);
  });

  static final _main = EditorCanvas('main', (ctx, w, h, dest, zoom) {
    ctx.clearRect(0, 0, w, h);
    ctx.drawImageToRect(inverted.e, dest);
    ctx.drawImage(_gridified.e, 0, 0);
  });
}
