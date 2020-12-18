import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import 'dart:convert';
import 'dart:io';

// 資料實體
class ItemEntity{
  final String title;
  final String imgUrl;

  ItemEntity({this.title,this.imgUrl});

  Map<String, dynamic> toJson(){
    return {
      'title': title,
      'imgUrl': imgUrl,
    };
  }
}

// 構造請求頭
var header = {
  'user-agent' : 'Mozilla/5.0 (Windows NT 6.1; Win64; x64) '+
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.102 Safari/537.36',
};

// 資料的請求
Future<String> requestData() async{
  var url = "https://www.mzitu.com/";

  var response = await http.get(url,headers: header);
  if (response.statusCode == 200) {
    return response.body;
  }
  return '<html>error! status:${response.statusCode}</html>';
}

// 資料的解析
Future<List<ItemEntity>> htmlParse() async{
  var html = await requestData();
  Document document = parse(html);
  // 這裡使用css選擇器語法提取資料
  List<Element> images = document.querySelectorAll('#pins > li > a > img');
  List<ItemEntity> data = [];
  if(images.isNotEmpty){
    data = List.generate(images.length, (i){
      return ItemEntity(
          title: images[i].attributes['alt'],
          imgUrl: images[i].attributes['data-original']);
    });
  }
  return data;
}

// 資料的儲存
void saveData() async{
  var data = await htmlParse();

  var jsonStr = json.encode({'items':data});
  // 將json寫入檔案中
  await File('data.json').writeAsString(jsonStr,flush: true);
}