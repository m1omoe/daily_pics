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

import 'package:daily_pics/misc/bean.dart';
import 'package:flutter/cupertino.dart';
import 'package:scoped_model/scoped_model.dart';

class AppModel extends Model {
  List<Picture> _today = [];
  List<Picture> get today => _today;
  set today(List<Picture> data) {
    _today = data;
    notifyListeners();
  }

  List<Picture> _recent = [];
  List<Picture> get recent => _recent;
  set recent(List<Picture> data) {
    _recent = data;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
  }

  static AppModel of(BuildContext context) {
    return ScopedModel.of<AppModel>(context, rebuildOnChange: true);
  }
}
