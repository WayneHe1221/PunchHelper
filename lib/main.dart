import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:work_punch_app/CalendarTable.dart';

import 'BottomSheetContent.dart';

Map<String, String> headers = {};
Map<String, String> captcha = {"insrand": "AAAA"};
String imageFolderPath = "";
String dataFolderPath = "";
String imagePath = "";
String loginDataPath = "";
String companyUrl = "https://punch.stratevision.com/Punch/";

var loginData = {'name': "", 'password': "", 'isRemeber': "true"};

void main() {
  return runApp(PunchHelper());
}

class PunchHelper extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<PunchHelper>{
  bool _scanning = false, punchIn = false, punchOut = false, loginSuccess = false, isButtonLock = false, isBottomShow = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  PersistentBottomSheetController _controller;
  String _extractText = "Identification result";
  int _scanTime = 0;
  var _image;
  var punchResult;
  CalendarController _calendarControllerController;
  TextEditingController accountController, passwordController;

  @override
  void initState() {
    super.initState();
    print("init");
    _setStoragePath();
    _loadLoginData();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _calendarControllerController = CalendarController();
  }

  void _showPersistentBottomSheet() {
    if(isBottomShow){
      print("bottom close");
      _controller.close();
    }else{
      print("bottom open");
      _controller = _scaffoldKey.currentState.showBottomSheet<void>((context) {
          return BottomSheetContent(accountController, passwordController);
        },
      );
    }
    setState(() {
      isBottomShow = !isBottomShow;
    });
  }
  _setStoragePath() async {
    var documentDirectory = await getApplicationDocumentsDirectory();
    setState(() {
      imageFolderPath = documentDirectory.path + "/images";
      imagePath = imageFolderPath + "/pic.jpg";
      dataFolderPath = documentDirectory.path + "/data";
      loginDataPath = dataFolderPath + "/loginData.txt";
    });
    await Directory(imageFolderPath).create(recursive: true);
    await Directory(dataFolderPath).create(recursive: true);
  }

  Future<void> _loadLoginData() async {
    // loginData = jsonDecode(File(loginDataPath).readAsStringSync());
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      loginData['name'] = prefs.getString("name");
      loginData['password'] = prefs.getString("password");

      accountController = TextEditingController();
      accountController.text = loginData['name'];
      passwordController = TextEditingController();
      passwordController.text = loginData['password'];
    });
    print(loginData['name']);
    print(loginData['password']);

    if(loginData['name'] != "" && loginData['password'] != ""){
      updateCurrentCaptchaImage(loginData);
    }
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
    File imageFile = new File(imagePath);
    imageFile.writeAsBytesSync(response.bodyBytes);

    print("punchUrl: image exist ? " + imageFile.existsSync().toString());
    updateImage(imagePath);

    loadingControl();
    // parse captcha to text
    var translatedText;
    try {
      translatedText = await TesseractOcr.extractText(imagePath);
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
    File imageFile = new File(imagePath);
    imageFile.writeAsBytesSync(response.bodyBytes);

    print("updateCurrentCaptchaImage: image exist ? " +
        imageFile.existsSync().toString());
    updateImage(imagePath);

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
        theme: new ThemeData(
          primarySwatch: Colors.deepPurple,
          canvasColor: Colors.transparent,
        ),
        home: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.white,
          body: Column(children: [
            SizedBox(
          height: 30,
        ),
            new CalendarTable(_calendarControllerController),
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
      ]),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              print('Go punch: start');
              if(isButtonLock){
                print('Go punch: block punch button');
              }else{
                if(punchIn && punchOut){
                  print('Go punch: already finish punch');
                }else{
                  isButtonLock = true;
                  await punchUrl(loginData);
                  isButtonLock = false;
                }
              }
            },
            child: (punchIn && punchOut) ? Icon(Icons.done) : punchIn ? Icon(Icons.logout) : Icon(Icons.login),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
          bottomNavigationBar: BottomAppBar(
            shape: new CircularNotchedRectangle(),
            color: Colors.orange,
            child: IconTheme(
              data: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                  ),
                  RaisedButton.icon(
                    icon: isBottomShow ? Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.white,) : Icon(Icons.person, color: Colors.white,),
                    label: Text( isBottomShow ? "Save" : "Account setting",
                      style: TextStyle(color: Colors.white),),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                      ),
                    color: Colors.black45,
                    onPressed: () async {
                      if(isBottomShow){
                        print(accountController.text);
                        print(passwordController.text);
                        if(accountController.text != "" && passwordController.text != ""){
                          loginData['name'] = accountController.text;
                          loginData['password'] = passwordController.text;

                          final prefs = await SharedPreferences.getInstance();
                          prefs.setString("name", loginData['name']);
                          prefs.setString("password", loginData['password']);
                        }
                      }
                      _showPersistentBottomSheet();
                    },
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
