// Copyright 2019 KagurazakaHanabi<i@yaerin.com>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:daily_pics/misc/bean.dart';
import 'package:daily_pics/misc/local_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Utils {
  static MethodChannel _channel = MethodChannel('ml.cerasus.pics');

  static Future<void> share(File file) async {
    await _channel.invokeMethod('share', file.path);
  }

  static Future<void> useAsWallpaper(File file) async {
    await _channel.invokeMethod('useAsWallpaper', file.path);
  }

  static Future<void> requestReview(bool inApp) async {
    await _channel.invokeMethod('requestReview', inApp);
  }

  static Future<bool> isAlbumAuthorized() {
    return _channel.invokeMethod('isAlbumAuthorized');
  }

  static Future<void> openAppSettings() async {
    await _channel.invokeMethod('openAppSettings');
  }

  static Future<File> download(
    Picture data,
    void Function(int count, int total) cb,
  ) async {
    Completer<File> completer = Completer();
    String url = data.url;
    String dest = (await getTemporaryDirectory()).path;
    File file;
    String name;
    if (url.contains('bing.com/')) {
      name = url.substring(url.lastIndexOf('=') + 1);
    } else {
      name = url.substring(url.lastIndexOf('/') + 1) + '.jpg';
      url += '?p=0&f=jpg';
    }
    file = File('$dest/$name');
    if (file.existsSync()) {
      file.deleteSync();
    }
    HttpClient client = HttpClient();
    HttpClientRequest request = await client.getUrl(Uri.parse(url));
    HttpClientResponse response = await request.close();
    int count = 0;
    response.listen((data) {
      file.writeAsBytesSync(data, mode: FileMode.writeOnlyAppend);
      if (cb != null) {
        cb(count += data.length, response.contentLength);
      }
    }, onDone: () async {
      await _channel.invokeMethod('syncAlbum', {
        'file': file.path,
        'title': data.title,
        'content': data.content,
      });
      completer.complete(file);
    });
    return completer.future;
  }

  static Future<String> upload(
    File file,
    Map<String, String> data,
    void Function(int count, int total) cb,
  ) async {
    dynamic json = jsonDecode(
      await uploadFile('https://img.dpic.dev/upload', file, cb),
    );
    if (!json['ret']) {
      return jsonEncode({
        'code': 400,
        'msg': json['error']['message'],
      });
    }
    String url = 'https://img.dpic.dev/' + json['info']['md5'];
    data['url'] = url;
    return (await http.post('https://v2.api.dailypics.cn/tg', body: data)).body;
  }

  static Future<String> uploadFile(
    String url,
    File file,
    void Function(int, int) cb,
  ) async {
    HttpClient client = HttpClient();
    HttpClientRequest request = await client.postUrl(Uri.parse(url));
    String subType = file.path.substring(file.path.lastIndexOf('.') + 1);
    request.headers.set('content-type', 'image/$subType');
    int contentLength = file.statSync().size;
    int byteCount = 0;
    Stream<Uint8List> stream = file.openRead();
    await request.addStream(stream.transform(StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        byteCount += data.length;
        sink.add(data);
        if (cb != null) {
          cb(byteCount, contentLength);
        }
      },
      handleError: (_, __, ___) {},
      handleDone: (sink) => sink.close(),
    )));
    HttpClientResponse response = await request.close();
    return await response.cast<List<int>>().transform(utf8.decoder).join();
  }

  static String getCompressed(Picture data) {
    int width;
    if (data.width > data.height) {
      width = data.width > 1280 ? 1280 : data.width;
    } else {
      width = data.width > 720 ? 720 : data.width;
    }
    if (!data.url.contains('images.dailypics.cn/')) {
      return data.url;
    }
    return data.url + '?f=jpg&q=50&w=$width';
  }

  static bool isDarkColor(Color c) {
    if (c == null) return false;
    // See https://github.com/FooStudio/tinycolor
    return (c.red * 299 + c.green * 587 + c.blue * 114) / 1000 < 128;
  }

  static bool isUUID(String input) {
    RegExp regExp = RegExp(
      r'^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$',
      caseSensitive: false,
    );
    return regExp.hasMatch(input);
  }
}

class Device {
  static bool isIPad(BuildContext context, [bool strict = false]) {
    Size size = MediaQuery.of(context).size;
    if (strict) {
      return size.shortestSide >= 600;
    }
    return size.width >= 600;
  }

  static bool isPortrait(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return size.width < size.height;
  }
}

class Settings {
  static LocalStorage _prefs;

  static Future<void> initial() async {
    _prefs = LocalStorage(await SharedPreferences.getInstance());
  }

  static List<String> get marked => _prefs['marked'] ?? [];

  static set marked(List<String> value) => _prefs['marked'] = value;

  /// App 启动次数
  ///
  /// 示例：'[1, 2, 2, 0, 1]'
  static String get launchTimes => _prefs['launch_times'] ?? '[0]';

  static set launchTimes(String value) => _prefs['launch_times'] = value;

  /// 最后启动时间
  static String get lastLaunch => _prefs['last_launch'];

  static set lastLaunch(String value) => _prefs['last_launch'] = value;
}
