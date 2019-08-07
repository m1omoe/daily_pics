import 'dart:convert';

import 'package:daily_pics/misc/bean.dart';
import 'package:daily_pics/misc/utils.dart';
import 'package:daily_pics/widget/image_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TodayComponent extends StatefulWidget {
  @override
  _TodayComponentState createState() => _TodayComponentState();
}

class _TodayComponentState extends State<TodayComponent>
    with AutomaticKeepAliveClientMixin {
  ScrollController controller = ScrollController();

  String text;
  List<Picture> data;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (data == null) {
      return Center(
        child: CupertinoActivityIndicator(),
      );
    }
    bool iPad = Device.isIPad(context, true);
    bool portrait = Device.isPortrait(context);
    int cnt = Device.isIPad(context) ? iPad && !portrait ? 6 : 2 : 1;
    return CupertinoScrollbar(
      controller: controller,
      child: CustomScrollView(
        controller: controller,
        physics: BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: <Widget>[
          CupertinoSliverRefreshControl(onRefresh: _fetchData),
          SliverSafeArea(
            sliver: SliverPadding(
              padding: Device.isIPad(context)
                  ? EdgeInsets.fromLTRB(12, 12, 12, 0)
                  : EdgeInsets.only(left: 4, top: 15, right: 4),
              sliver: SliverStaggeredGrid.countBuilder(
                crossAxisCount: cnt,
                itemCount: (data?.length ?? 0) + 1,
                staggeredTileBuilder: (i) {
                  if (i == 0) {
                    return StaggeredTile.fit(cnt);
                  } else if (iPad && !portrait) {
                    if (_needWiden(i)) {
                      return StaggeredTile.count(4, 3);
                    } else {
                      return StaggeredTile.count(2, 3);
                    }
                  } else {
                    return StaggeredTile.fit(1);
                  }
                },
                itemBuilder: (_, int i) {
                  if (i == 0) {
                    return _buildHeader();
                  } else if (iPad && !portrait) {
                    return ImageCard(
                      data[i - 1],
                      '#$i',
                      aspectRatio: _needWiden(i) ? 4 / 3 : 2 / 3,
                    );
                  } else {
                    return ImageCard(data[i - 1], '#$i');
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _getDate(),
            style: TextStyle(
              color: CupertinoColors.inactiveGray,
              fontSize: 12,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Offstage(
                  offstage: true,
                  child: Icon(CupertinoIcons.profile_circled, size: 42),
                ),
              ],
            ),
          ),
          Text(
            text ?? '',
            style: TextStyle(
              color: CupertinoColors.inactiveGray,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _getDate() {
    DateTime date = DateTime.now();
    List<String> weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '${date.month} 月 ${date.day} 日 星期${weekdays[date.weekday - 1]}';
  }

  bool _needWiden(int index) {
    return index % 4 == 1 || index % 4 == 0;
  }

  Future<void> _fetchData() async {
    _fetchText();
    String source = await Http.get('https://v2.api.dailypics.cn/today');
    Response res = Response.fromJson({'data': jsonDecode(source)});
    data = res.data ?? [];
    await _fetchBing();
    await _parseMark();
    setState(() {});
  }

  Future<void> _fetchText() async {
    String url = 'https://yijuzhan.com/api/word.php?m=json';
    String source = await Http.get(url);
    if (source.startsWith('{') && source.endsWith('}')) {
      setState(() => text = jsonDecode(source)['content']);
    } else {
      setState(() => text = source);
    }
  }

  Future<void> _fetchBing() async {
    String url = 'https://cn.bing.com/HPImageArchive.aspx?format=js&n=1&idx=0';
    String source = await Http.get(url);
    Map<String, dynamic> json = jsonDecode(source)['images'][0];
    String copyright = json['copyright'];
    data.add(Picture(
      id: '${json['urlbase']}_1080x1920'.split('?')[1],
      title: _parseBing(copyright)[0],
      content: _parseBing(copyright)[1],
      width: 1080,
      height: 1920,
      user: '',
      url: 'https://cn.bing.com${json['urlbase']}_1080x1920.jpg',
      date: json['enddate'],
      type: ' 必应',
    ));
  }

  List<String> _parseBing(String copyright) {
    List<String> split = copyright.split('，');
    if (split.length > 1) {
      return split;
    }

    split = copyright.replaceAll(RegExp('[【|】]'), '').split(' (');
    return [split[0], split[1].substring(0, split[1].length - 2)];
  }

  Future<void> _parseMark() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList('marked') ?? [];
    for (int i = 0; i < data.length; i++) {
      data[i].marked = list.contains(data[i].id);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => data != null;
}
