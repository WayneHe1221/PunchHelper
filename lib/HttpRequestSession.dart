import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';


var loginData = {
  'name' : "waynehe",
  'password' : "1221",
  'isRemeber' : "true"
};

Map<String, String> headers = {};
Map<String, String> captcha = {"insrand" : "AAAA"};
String imagePath = "";
String companyUrl = "https://punch.stratevision.com/Punch/";

Future<int> punchUrl(dynamic data) async{
  // login the web
  var response = await http.post(companyUrl + "0-0action.jsp", body: data, headers: headers);
  updateCookie(response);

  // request login
  response = await http.get(companyUrl + "1-1.jsp", headers: headers);
  var statusCode = response.statusCode;
  print("punchUrl: login status: $statusCode");

  // parse the result
  var document = parse(response.body);
  var imageUrl = companyUrl;
  List<Element> images = document.querySelectorAll('div.col-sm-5 > img'); // take the target image url
  for (var image in images) {
    print(image.attributes['src']);
    imageUrl = imageUrl + image.attributes['src'];
  }

  // take the image
  response = await http.get(imageUrl, headers: headers);
  var documentDirectory = await getApplicationDocumentsDirectory();
  var firstPath = documentDirectory.path + "/images";
  var filePathAndName = documentDirectory.path + '/images/pic.jpg';
  imagePath = filePathAndName;
  //comment out the next three lines to prevent the image from being saved
  //to the device to show that it's coming from the internet
  await Directory(firstPath).create(recursive: true); // <-- 1
  File imageFile = new File(filePathAndName);             // <-- 2
  imageFile.writeAsBytesSync(response.bodyBytes);         // <-- 3

  print("punchUrl: image exist ? " + imageFile.existsSync().toString());

  // parse captcha to text
  var translatedText;
  try {
    translatedText = await TesseractOcr.extractText(filePathAndName);
    var num = int.parse(translatedText);
    translatedText = "$num";
  } catch (exception) {
    print(exception.toString());
  }
  captcha['insrand'] = translatedText;
  print(captcha['insrand']);

  // use the captcha to do punch in
  response = await http.post(companyUrl + "1-1action.jsp", body: captcha, headers: headers);
  statusCode = response.statusCode;
  print("punchUrl: punch status: $statusCode");

  return statusCode;
}

downloadPic() async {
  print("Start download");
  //comment out the next two lines to prevent the device from getting
  // the image from the web in order to prove that the picture is
  // coming from the device instead of the web.
  var url = "https://punch.stratevision.com/Punch/newImage.jsp?time=1609557107417"; // <-- 1
  var response = await http.get(url, headers: headers); // <--2
  var documentDirectory = await getApplicationDocumentsDirectory();
  var firstPath = documentDirectory.path + "/images";
  var filePathAndName = documentDirectory.path + '/images/pic.jpg';
  imagePath = filePathAndName;
  //comment out the next three lines to prevent the image from being saved
  //to the device to show that it's coming from the internet
  await Directory(firstPath).create(recursive: true); // <-- 1
  File file2 = new File(filePathAndName);             // <-- 2
  file2.writeAsBytesSync(response.bodyBytes);         // <-- 3

  print("Path: " + filePathAndName);
  print("File exist ? " + file2.existsSync().toString());
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