import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:work_punch_app/CalendarTable.dart';

Map<String, String> headers = {};
Map<String, String> captcha = {"insrand": "AAAA"};
String imagePath = "";
String companyUrl = "https://punch.stratevision.com/Punch/";

var loginData = {'name': "waynehe", 'password': "1221", 'isRemeber': "true"};

void main() {
  return runApp(PunchHelper());
}

class PunchHelper extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<PunchHelper> {
  bool _scanning = false, punchIn = false, punchOut = false, loginSuccess = false;
  String _extractText = "Identification result";
  int _scanTime = 0;
  var _image;
  var punchResult;
  CalendarController _controller;

  @override
  void initState() {
    super.initState();
    print("init");
    checkPunchStatus(loginData);
    updateCurrentCaptchaImage(loginData);
    _controller = CalendarController();
  }

  void updateImage(String imgPath) {
    setState(() {
      _image = Image.memory(File(imgPath).readAsBytesSync());
    });
  }

  void loadingControl() {
    setState(() {
      _scanning = !_scanning;
    });
  }

  void updateExtractResult(String result) {
    setState(() {
      _extractText = result;
    });
  }

  void updatePunchState(bool punchIn, bool punchOut) {
    setState(() {
      this.punchIn = punchIn;
      this.punchOut = punchOut;
    });
  }

  void checkLogin(int statusCode){
    if(statusCode == HttpStatus.ok){
      loginSuccess = true;
    }else{
      loginSuccess = false;
    }
  }

  Future<int> punchUrl(dynamic data) async {
    var response;
    if(!loginSuccess){
      // login the web
      response = await http.post(companyUrl + "0-0action.jsp",
          body: data, headers: headers);
      updateCookie(response);
      checkLogin(response.statusCode);
    }

    // request login page
    response = await http.get(companyUrl + "1-1.jsp", headers: headers);
    var statusCode = response.statusCode;
    print("punchUrl: login status: $statusCode");

    // parse the result
    var document = parse(response.body);
    var imageUrl = companyUrl;
    var images = document
        .querySelectorAll('div.col-sm-5 > img'); // take the target image url
    for (var image in images) {
      print(image.attributes['src']);
      imageUrl = imageUrl + image.attributes['src'];
    }

    // save the image
    response = await http.get(imageUrl, headers: headers);
    var documentDirectory = await getApplicationDocumentsDirectory();
    var firstPath = documentDirectory.path + "/images";
    var filePathAndName = documentDirectory.path + '/images/pic.jpg';
    imagePath = filePathAndName;
    await Directory(firstPath).create(recursive: true);
    File imageFile = new File(filePathAndName);
    imageFile.writeAsBytesSync(response.bodyBytes);

    print("punchUrl: image exist ? " + imageFile.existsSync().toString());
    updateImage(imagePath);

    loadingControl();
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
    updateExtractResult(translatedText);

    // use the captcha to do punch in
     response = await http.post(companyUrl + "1-1action.jsp",
        body: captcha, headers: headers);
     statusCode = response.statusCode;
    print("punchUrl: punch status: $statusCode");
    loadingControl();

    if (punchIn && punchOut) {}
    response = await http.post(companyUrl + "1-1.jsp", headers: headers);
    document = parse(response.body);
    var hasPunchIn = false, hasPunchOut = false;
    if (document.outerHtml.contains("label label-default\">on")) {
      hasPunchIn = true;
    }
    if (document.outerHtml.contains("label label-default\">off")) {
      hasPunchOut = true;
    }
    updatePunchState(hasPunchIn, hasPunchOut);

    return statusCode;
  }

  Future<void> checkPunchStatus(dynamic data) async {
    // login the web
    var response = await http.post(companyUrl + "0-0action.jsp",
        body: data, headers: headers);
    updateCookie(response);
    checkLogin(response.statusCode);

    // request login page
    response = await http.get(companyUrl + "1-1.jsp", headers: headers);
    var statusCode = response.statusCode;
    print("punchUrl: login status: $statusCode");

    var document = parse(response.body);
    var hasPunchIn = false, hasPunchOut = false;
    print(document.outerHtml);
    if (document.outerHtml.contains("label label-default\">on")) {
      hasPunchIn = true;
    }
    if (document.outerHtml.contains("label label-default\">off")) {
      hasPunchOut = true;
    }
    updatePunchState(hasPunchIn, hasPunchOut);
  }

  Future<void> updateCurrentCaptchaImage(dynamic data) async {
    // login the web
    var response = await http.post(companyUrl + "0-0action.jsp",
        body: data, headers: headers);
    updateCookie(response);
    checkLogin(response.statusCode);

    // request login page
    response = await http.get(companyUrl + "1-1.jsp", headers: headers);
    var statusCode = response.statusCode;
    print("updateCurrentCaptchaImage: login status: $statusCode");

    // parse the result
    var document = parse(response.body);
    var imageUrl = companyUrl;
    var images = document
        .querySelectorAll('div.col-sm-5 > img'); // take the target image url
    for (var image in images) {
      imageUrl = imageUrl + image.attributes['src'];
    }

    // save the image
    response = await http.get(imageUrl, headers: headers);
    var documentDirectory = await getApplicationDocumentsDirectory();
    var firstPath = documentDirectory.path + "/images";
    var filePathAndName = documentDirectory.path + '/images/pic.jpg';
    imagePath = filePathAndName;
    await Directory(firstPath).create(recursive: true);
    File imageFile = new File(filePathAndName);
    imageFile.writeAsBytesSync(response.bodyBytes);

    print("updateCurrentCaptchaImage: image exist ? " +
        imageFile.existsSync().toString());
    updateImage(imagePath);
  }

  void updateCookie(http.Response response) {
    String rawCookie = response.headers['set-cookie'];
    print("show the update cookie: " + rawCookie);
    if (rawCookie != null) {
      headers['cookie'] = rawCookie;
      headers['set-cookie'] = rawCookie;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      body: Column(children: [
        SizedBox(
          height: 30,
        ),
        new CalendarTable(_controller),
        SizedBox(
          height: 20,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text('Punch In: '),
              ),
            ),
            punchIn
                ? Icon(Icons.done, color: Colors.green)
                : Icon(
                    Icons.close,
                    color: Colors.red,
                  ),
            Card(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text('Punch Out:'),
              ),
            ),
            punchOut
                ? Icon(Icons.done, color: Colors.green)
                : Icon(
                    Icons.close,
                    color: Colors.red,
                  ),
          ],
        ),
        SizedBox(
          height: 20,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _image != null
                ? _image
                : SpinKitCircle(
                    color: Colors.black,
                  ),
            Center(
                child: Text(
              _extractText,
              style: TextStyle(fontSize: 20),
            )),
          ],
        ),
        SizedBox(
          height: 20,
        ),
        Center(
            child: Text(
          'Scanning took $_scanTime ms',
          style: TextStyle(color: Colors.red),
        )),
        Expanded(
          child: Align(
            alignment: FractionalOffset.bottomCenter,
            child: MaterialButton(
                child: Text(punchIn ? 'Punch Out' : "Punch In",
                    style: TextStyle(color: Colors.black)),
                minWidth: 200,
                height: 50,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22.0)),
                color: Colors.white,
                onPressed: () async {
                  await punchUrl(loginData);
                }),
          ),
        ),
        SizedBox(
          height: 20,
        ),
      ]),
    ));
  }
}
