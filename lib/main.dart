import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_liquidcore/liquidcore.dart';

void main() {
  //enableLiquidCoreLogging = true;
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Random _rng;
  MicroService _microService;
  JSContext _jsContext;

  String _jsContextResponse = '<empty>';
  String _microServiceResponse = '<empty>';
  int _microServiceWorld = 0;

  static const platform = const MethodChannel('samples.flutter.dev/startApp');

  @override
  void initState() {
    super.initState();
  }

  testLanuch() async {
    try {
      final bool result = await platform.invokeMethod('launchPackage', {
        "appName": "微信"
      });
      print(result);
      print("lanuch=");
    } on PlatformException catch (e) {
      print(e);
    }

  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FlutterLiquidcore App'),
        ),
        body: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              RaisedButton(
                child: const Text('MicroService'),
                onPressed: initMicroService,
              ),
              Center(
                child: Text('MicroService response: $_microServiceResponse\n'),
              ),
              RaisedButton(
                child: const Text('Execute JSContext'),
                onPressed: _initializeJsContext,
              ),
              RaisedButton(
                child: const Text('Test App'),
                onPressed: testLanuch,
              ),
              Center(
                child: Text('JSContext response: $_jsContextResponse\n'),
              )
            ]),
      ),
    );
  }

  @override
  void dispose() {
    if (_microService != null) {
      // Exit and free up the resources.
      // _microService.exitProcess(0); // This API call might not always be available.
      _microService.emit('exit');
    }
    if (_jsContext != null) {
      // Free up the context resources.
      _jsContext.cleanUp();
    }
    super.dispose();
  }

  void _initializeJsContext() async {
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      if (_jsContext == null) {
        _jsContext = new JSContext();
        const code = """
        // Attached as a property of the current global context scope.
        var obj = {
          number: 1,
          string: 'string',
          date: new Date(),
          array: [1, 'string', null, undefined],
          func: function () {}
        };
        var a = 10;
        // Is a variable, and not attached as a property of the context.
        let objLet = { number: 1, yayForLet: true };
        """;
        await _jsContext.evaluateScript(code);
        try {
          // Evaluate an invalid javascript call.
          await _jsContext.evaluateScript('invalid.call()');
        } catch(e) {
          print(e);
        }
        try {
          // Catch an exception.
          await _jsContext.evaluateScript('throw new Error("My exception message")');
        } catch(e) {
          print(e);
        }
        // This will return a promise object, but you won't be able to manipulate it from Dart.
        var promise = await _jsContext.evaluateScript('''
            var response;
            (async () => {
              response = await Promise.reject();
            })();
            ''');
        var obj = await _jsContext.property("obj");
        var aValue = await _jsContext.property("a");
        var objLet = await _jsContext.evaluateScript("objLet");

        // Add factorial function.
        await _jsContext.setProperty("factorial", (double x) {
          print("factorial($x)");
          int factorial = 1;
          for (; x > 1; x--) {
            factorial *= x.toInt();
          }
          return factorial;
        });
        // Return a declared function (currently only works with dart functions).
        var factorialFn = await _jsContext.property("factorial");

        await _jsContext.setProperty("factorialThen",
                (double factorial) async {
              var f = await _jsContext.property("f");
              print("factorialThen($f) = $factorial");
              _setJsContextResponse(
                  "Factorial of ${f.toInt()} = ${factorial.toInt()} !");

              return factorial;
            });

        print("******************************");
        print("obj = $obj");
        print("a = $aValue");
        print("promise = $promise");
        print("objLet = $objLet");
        print("factorialFn = ${factorialFn.runtimeType.toString()}");
        print("******************************");
      }

      if (_rng == null) {
        _rng = new Random();
      }
      // Generate a random number.
      var factorialNumber = _rng.nextInt(10);
      await _jsContext.setProperty("f", factorialNumber);
      await _jsContext.evaluateScript("factorial(f).then(factorialThen);");

      //returnVal = await context.evaluateScript("( function(){ return factorial($factorialNumber).then(factorialThen) })() ");
    } on PlatformException {
      _setJsContextResponse('Failed to get factorial from Javascript. $e');
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  void initMicroService() async {
    if (_microService == null) {
      String uri;

      // Android doesn't allow dashes in the res/raw directory.
      //uri = "android.resource://io.jojodev.flutter.liquidcoreexample/raw/liquidcore_sample";
//      uri = "@flutter_assets/Resources/liquidcore_sample.js";
      uri = "http://192.168.1.8:8080/index.js";

      _microService = new MicroService(uri);
      await _microService.addEventListener('ready',
              (service, event, eventPayload) {
            // The service is ready.
            if (!mounted) {
              return;
            }

            print('ready '+uri);
            //_emit();
          });
      await _microService.addEventListener('pong',
              (service, event, eventPayload) {
            if (!mounted) {
              return;
            }

            _setMicroServiceResponse(eventPayload['message']);
          });
      await _microService.addEventListener('object',
              (service, event, eventPayload) {
            if (!mounted) {
              return;
            }

            print("received obj: $eventPayload | type: ${eventPayload.runtimeType}");
          });

      // Start the service.
      await _microService.start();
    }

    if (_microService.isStarted) {
      _emit();
    }
  }

  void _emit() async {
    // Send the name over to the MicroService.
    await _microService.emit('ping', 'World ${++_microServiceWorld}');
  }

  void _setMicroServiceResponse(message) {
    if (!mounted) {
      print("microService: widget not mounted");
      return;
    }

    setState(() {
      _microServiceResponse = message;
    });
  }

  void _setJsContextResponse(value) {
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) {
      print("jsContext: widget not mounted");
      return;
    }

    setState(() {
      _jsContextResponse = value;
    });
  }
}