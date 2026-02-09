import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityStatusWidget extends StatefulWidget {
  final Widget child;

  const ConnectivityStatusWidget({Key? key, required this.child}) : super(key: key);

  @override
  State<ConnectivityStatusWidget> createState() => _ConnectivityStatusWidgetState();
}

class _ConnectivityStatusWidgetState extends State<ConnectivityStatusWidget> {
  late Stream<ConnectivityResult> _connectionStatusStream;
  bool isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
    _connectionStatusStream = Connectivity().onConnectivityChanged;
  }

  Future<void> _checkInitialConnection() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      isOnline = result != ConnectivityResult.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityResult>(
      stream: _connectionStatusStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final isConnected = snapshot.data != ConnectivityResult.none;
          if (isConnected != isOnline) {
            isOnline = isConnected;
          }
        }

        return Stack(
          children: [
            widget.child,
            if (!isOnline)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.red[900],
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.cloud_off, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'You are offline',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
