import 'package:flutter/material.dart';

class BottomSheetContent extends StatelessWidget {
  TextEditingController _accountController;
  TextEditingController _passwordController;

  BottomSheetContent(TextEditingController accountController, TextEditingController passwordController,){
    _accountController = accountController;
    _passwordController = passwordController;
  }

  final sheetHeight = 200.0;

  @override
  Widget build(BuildContext context) {
    return Container(
        height: sheetHeight,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
                topRight: Radius.circular(40.0),
                topLeft: Radius.circular(40.0),
            ),
            gradient: new LinearGradient(
              colors: [Colors.amber, Colors.orange],
                begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          color: Colors.amber,
        ),
        child: Column(
          children: [
            SizedBox(
              height: sheetHeight/10*3,
            ),
            Center(
              child: Container(
                height: sheetHeight/10*2,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(
                    Radius.circular(4.0),
                  ),
                ),
                width: 200,
                child: TextField(
                  controller: _accountController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Account',
                  ),
                ),
              ),
            ),
            Center(
              child: SizedBox(
                height: sheetHeight/10,
              ),
            ),
            Center(
              child: Container(
                height: sheetHeight/10*2,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(
                    Radius.circular(4.0),
                  ),
                ),
                width: 200,
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Password',
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }
}

