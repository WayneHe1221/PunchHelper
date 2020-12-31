import 'dart:async';
import 'dart:core';

import 'package:http/http.dart' as http;

// 資料實體
class ItemEntity{
  final String value;
  final String type;

  ItemEntity({this.value,this.type});

  Map<String, dynamic> toJson(){
    return {
      'value': value,
      'type': type,
    };
  }
}

String companyUrl = "https://punch.stratevision.com/Punch/";

var loginData = {
  'name' : "waynehe",
  'password' : "1221",
  'isRemeber' : "true"
};

class HttpRequestSession {
  Map<String, String> headers = {};

  Future<String> get(String url) async {
    print("show the get header: ");
    headers.entries.forEach((element) {
      print(element.key + " : " + element.value + "\n");
    });
    http.Response response = await http.get(url, headers: headers);
    updateCookie(response);
    return response.body;
  }

  Future<String> post(String url, dynamic data) async{
    print("show the post header: ");
    headers.entries.forEach((element) {
      print(element.key + " : " + element.value + "\n");
    });
    print("============================================");
    http.Response response = await http.post(url, body: data, headers: headers);
    updateCookie(response);
    return response.body;
  }

  Future<String> connectMyLogIn(String url, dynamic data) async{
    print("show the post header: ");
    headers.entries.forEach((element) {
      print(element.key + " : " + element.value + "\n");
    });
    print("============================================");
    http.Response response = await http.post("https://punch.stratevision.com/Punch/0-0action.jsp", body: data, headers: headers);
    updateCookie(response);

    print("show the get header: ");
    headers.entries.forEach((element) {
      print(element.key + " : " + element.value + "\n");
    });
    response = await http.get("https://punch.stratevision.com/Punch/1-1.jsp", headers: headers);
    return response.body;
  }

  void updateCookie(http.Response response) {
    String rawCookie = response.headers['set-cookie'];
    print("show the update cookie: " + rawCookie);
    if (rawCookie != null) {
      headers['cookie'] = rawCookie;
      headers['set-cookie'] = rawCookie;
    }
    // response.headers.entries.forEach((element) {
    //   print(element.key + " : " + element.value + "\n");
    // });
  }
}