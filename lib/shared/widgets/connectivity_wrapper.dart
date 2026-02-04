import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _isOnline = true;
  late StreamSubscription<bool> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    // Listen to Firestore's snapshot-in-sync events to detect online/offline
    _connectivitySubscription = FirebaseFirestore.instance
        .collection('_connectivity_check')
        .doc('status')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => !snapshot.metadata.isFromCache)
        .distinct()
        .listen((isOnline) {
          if (mounted) {
            setState(() => _isOnline = isOnline);
          }
        });

    // Also try a simple network check
    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      await FirebaseFirestore.instance
          .collection('_connectivity_check')
          .doc('status')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 3));
      if (mounted) setState(() => _isOnline = true);
    } catch (e) {
      if (mounted) setState(() => _isOnline = false);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Offline banner
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isOnline ? 0 : 32,
          child: _isOnline
              ? const SizedBox.shrink()
              : Material(
                  color: Colors.orange.shade700,
                  child: const SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'You are offline - Changes will sync when online',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        // Main content
        Expanded(child: widget.child),
      ],
    );
  }
}

// A simple provider to check connectivity status anywhere in the app
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void updateStatus(bool isOnline) {
    _isOnline = isOnline;
    _connectivityController.add(isOnline);
  }

  void dispose() {
    _connectivityController.close();
  }
}
