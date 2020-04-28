import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:math';

import 'grid.dart';
import 'io.dart';

class Project {
  static const zoomSpeed = 10;

  final CanvasElement fg = querySelector('canvas#fg');
  final CanvasElement bg = querySelector('canvas#bg');
  final ImageElement img = querySelector('img');
  final InputElement urlInput = querySelector('#imgUrl');
  final DivElement offsetElement = querySelector('#offset');
  final DivElement editor = querySelector('.image');
  final InputElement ratioCheckbox = querySelector('#keepRatio');
  final InputElement cellX = querySelector('#cellX');
  final InputElement cellY = querySelector('#cellY');
  final InputElement lockCheckbox = querySelector('#lockGrid');
  final HtmlElement loader = querySelector('#loader');
  Grid _grid;
  String _fileName = 'draw_sth.json';
  final Storage _storage = window.localStorage;
  bool _updateStorage = false;

  bool get lockGrid => lockCheckbox.checked;
  bool get keepRatio => ratioCheckbox.checked;

  set loading(bool v) => v ? editor.append(loader) : loader.remove();

  int get minWidth {
    var rect = editor.client;
    var width = (img.width / img.height) * rect.height;
    return (width < rect.width ? width : rect.width).round() ~/ 2;
  }

  int _zoomWidth = 500;
  int get zoomWidth => _zoomWidth;
  set zoomWidth(int zoomWidth) {
    _zoomWidth = max(minWidth, zoomWidth);
    setSize();
  }

  double get zoom => img.width / zoomWidth;

  Point get zoomedSize => Point(_zoomWidth, img.height / zoom);
  Point get size => Point(img.width, img.height);

  Point _offset = Point(0, 0);
  Point get offset => _offset;
  set offset(Point offset) {
    _offset = offset;
    var point = (_offset * (1 / zoom)) - zoomedSize * 0.5;
    offsetElement.style.left = 'calc(50% + ${point.x}px)';
    offsetElement.style.top = 'calc(50% + ${point.y}px)';
  }

  void registerIntInput(
      InputElement e,
      void Function(double value, bool bonus) apply,
      String Function() applyBackwards,
      {void Function() onMouseUp}) {
    void parse(bool executeBonus) {
      var s = e.value;
      var v = double.tryParse(s);
      if (v != null && v >= 0) {
        apply(v, executeBonus);
        if (executeBonus) redraw();
      }
    }

    if (onMouseUp != null) {
      e.onMouseDown.listen((ev) {
        var sub;
        sub = window.onMouseUp.listen((ev) {
          onMouseUp();
          sub.cancel();
        });
      });
    }

    e.onInput.listen((ev) {
      parse(true);
    });
    parse(false);

    e.onBlur.listen((ev) {
      e.value = applyBackwards();
      if (onMouseUp != null) onMouseUp();
    });

    e.onKeyDown.listen((ev) {
      if (ev.keyCode == 13) {
        e.blur();
      }
    });
  }

  void setSrc(String src) {
    loading = true;
    var sub;
    sub = img.onLoad.listen((e) {
      sub.cancel();
      _grid.immediateClamp();
      setSize();
      offset = Point(0, 0);
      zoomWidth = minWidth * 2;
      loading = false;
    });
    img.src = src;
    urlInput.value = img.src;
  }

  void applyCellSize(bool x, bool y) {
    if (x) cellX.value = _grid.cellSize.x.toStringAsFixed(1);
    if (y) cellY.value = _grid.cellSize.y.toStringAsFixed(1);
  }

  Project() {
    _grid = Grid(this);

    registerIntInput(cellX, (v, bonus) {
      if (v < 25 || !bonus) return;
      _grid.cellSize =
          Point(v, _grid.cellSize.y * (keepRatio ? v / _grid.cellSize.x : 1));
      applyCellSize(false, true);
    }, () {
      applyCellSize(true, false);
      return _grid.cellSize.x.toStringAsFixed(1);
    }, onMouseUp: _grid.fit);
    registerIntInput(cellY, (v, bonus) {
      if (v < 25 || !bonus) return;
      _grid.cellSize =
          Point(_grid.cellSize.x * (keepRatio ? v / _grid.cellSize.y : 1), v);
      applyCellSize(true, false);
    }, () {
      applyCellSize(true, true);
      return _grid.cellSize.y.toStringAsFixed(1);
    }, onMouseUp: _grid.fit);
    ratioCheckbox.checked = true;
    applyCellSize(true, true);
    registerIntInput(
        querySelector('#subdivisions'),
        (v, bonus) => _grid.subdivisions = v.round(),
        () => _grid.subdivisions.toString());

    urlInput.onKeyDown.listen((e) {
      if (e.keyCode == 13) {
        setSrc(urlInput.value);
      }
    });

    lockCheckbox.onInput.listen((e) {
      var lock = lockGrid;
      _grid.el.style.display = lock ? 'none' : 'block';
      cellX.disabled = lock;
      cellY.disabled = lock;
      ratioCheckbox.disabled = lock;
      urlInput.disabled = lock;
      _updateStorage = true;
    });

    window.onResize.listen((e) => resizeCanvas());

    editor.onMouseDown.listen((e) {
      HtmlElement el = e.target;
      if (el.matchesWithAncestors('#grid')) return;
      var pos1 = offset;

      var mouse1 = Point<int>(e.client.x, e.client.y);
      var subMove = document.onMouseMove.listen((e) {
        if (e.movement.magnitude == 0) return;
        var diff = (Point<int>(e.client.x, e.client.y) - mouse1);

        offset = pos1 + diff * zoom;
        redraw();
      });

      var subUp;
      subUp = document.onMouseUp.listen((e) {
        subMove.cancel();
        subUp.cancel();
      });
    });

    querySelector('#save').onClick.listen((e) => download());
    InputElement fileInput = querySelector('#upload');
    fileInput.onChange.listen((e) {
      var file = fileInput.files[0];
      if (file != null) {
        _fileName = file.name;
        var reader = FileReader();
        reader.onLoad.listen((e) {
          String jsonString = (e.target as dynamic).result;
          fromJson(json.decode(jsonString));
        });
        reader.readAsText(file);
      }
      fileInput.value = '';
    });

    document.onKeyDown.listen((e) {
      if (e.target is! InputElement) {
        if (e.shiftKey) {
          switch (e.key) {
            case 'R':
              reloadStylesheet(); //TODO remove from final version
              return;
          }
        }
        switch (e.key) {
          case '+':
            zoomWidth += zoomSpeed;
            return;
          case '-':
            zoomWidth -= zoomSpeed;
            return;
        }
      }
    });

    document.onMouseWheel.listen((e) {
      zoomWidth -= (zoomSpeed * min(max(e.deltaY, -5), 5)).round();
    });

    Timer.periodic(Duration(seconds: 1), (timer) {
      if (_updateStorage) {
        _updateStorage = false;
        saveToStorage();
      }
    });

    loadFromStorage();
  }

  Map<String, dynamic> toJson() => {
        'src': img.src,
        'offset': pointToJson(offset),
        'zoomWidth': zoomWidth,
        'lock': lockGrid,
        'grid': _grid.toJson()
      };
  void fromJson(Map<String, dynamic> json) {
    loading = true;
    var sub;
    sub = img.onLoad.listen((e) {
      sub.cancel();
      _offset = pointFromJson(json['offset']);
      _zoomWidth = json['zoomWidth'];
      _grid.fromJson(json['grid']);
      (querySelector('#subdivisions') as InputElement).value =
          _grid.subdivisions.toString();
      applyCellSize(true, true);
      setSize();
      bool shouldLock = json['lock'] ?? true;
      if ((shouldLock && !lockGrid) || (!shouldLock && lockGrid)) {
        lockCheckbox.click();
      }
      loading = false;
    });
    img.src = json['src'];
    urlInput.value = img.src;
  }

  void download() {
    var jsonString = toJsonString(this);
    var aElement = AnchorElement(
        href:
            'data:text/json;charset=utf-8,' + Uri.encodeComponent(jsonString));
    aElement.download = _fileName;
    document.body.append(aElement);
    aElement.click();
    aElement.remove();
  }

  void saveToStorage() {
    _storage['json'] = json.encode(this);
  }

  void loadFromStorage() {
    _updateStorage = false;
    if (_storage.isNotEmpty) {
      fromJson(json.decode(_storage['json']));
    } else {
      initDemo();
    }
  }

  void clearStorage() {
    _storage.clear();
  }

  void reloadStylesheet() {
    LinkElement cssLink = querySelector('link');
    cssLink.href = cssLink.href;
  }

  void initDemo() {
    setSrc('jon.png');
  }

  void setSize() {
    _grid.position = _grid.position;
    _grid.size = _grid.size;
    offset = offset;
    resizeCanvas();
  }

  void resizeCanvas() {
    fg.width = editor.clientWidth;
    fg.height = editor.clientHeight;
    bg.width = editor.clientWidth;
    bg.height = editor.clientHeight;
    redraw();
  }

  void redraw() {
    _updateStorage = true;
    var bgCtx = bg.context2D;

    bgCtx.clearRect(0, 0, bg.width, bg.height);

    var client = editor.client;
    var center = client.bottomRight * 0.5;

    var dest = Rectangle.fromPoints(
        Grid.round(center + (size * -0.5 + offset) * (1 / zoom)),
        Grid.round(center + (size * 0.5 + offset) * (1 / zoom)));

    bgCtx.filter = 'invert(1) grayscale(1) brightness(0.8) contrast(1000)';
    bgCtx.drawImageToRect(img, dest);

    var fgCtx = fg.context2D;
    fgCtx.globalCompositeOperation = 'source-over';
    fgCtx.clearRect(0, 0, fg.width, fg.height);

    fgCtx.drawImageToRect(img, dest);
    _grid.drawOn(fgCtx, dest);
  }
}
