import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/backend_test.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(TrashTaggerApp());
}

class TrashTaggerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrashTagger',
      theme: ThemeData(primarySwatch: Colors.green),
      home: BackendTestScreen(),
    );
  }
}

class BackendTestScreen extends StatefulWidget {
  @override
  _BackendTestScreenState createState() => _BackendTestScreenState();
}

class _BackendTestScreenState extends State<BackendTestScreen> {
  Map<String, String> _testResults = {};
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('TrashTagger Backend Test')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TrashTagger Backend Status',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 20),

            if (_testResults.isNotEmpty) ...[
              ...(_testResults.entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${entry.key.toUpperCase()}: ${entry.value}',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              )),
              SizedBox(height: 20),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _runTests,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Test Backend'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runTests() async {
    setState(() {
      _isLoading = true;
      _testResults = {};
    });

    try {
      final testService = BackendTestService();
      final results = await testService.runAllTests();

      setState(() {
        _testResults = results;
      });
    } catch (e) {
      setState(() {
        _testResults = {'error': '❌ Test failed: $e'};
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
