// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';

// class CallPage extends StatefulWidget {
//   final String room;
//   const CallPage({required this.room});

//   @override
//   State<CallPage> createState() => _CallPageState();
// }

// class _CallPageState extends State<CallPage> {
//   final _localRenderer = RTCVideoRenderer();
//   final _remoteRenderer = RTCVideoRenderer();
//   late RTCPeerConnection _pc;
//   late WebSocketChannel _channel;

//   @override
//   void initState() {
//     super.initState();
//     _initRenderers();
//     _connect();
//     print('Connecting to room: ${widget.room}');
//   }

//   Future<void> _initRenderers() async {
//     await _localRenderer.initialize();
//     await _remoteRenderer.initialize();
//   }
// Future<void> _connect() async {
//   print('Connecting to WebSocket server…');

//   _channel = WebSocketChannel.connect(
//     Uri.parse(
//       'wss://amended-believe-happening-deposit.trycloudflare.com/ws/call/${widget.room}/',
//     ),
//   );

//   final config = {
//     'iceServers': [
//       {'urls': 'stun:stun.l.google.com:19302'},
//       // add TURN servers if needed
//     ]
//   };

//   // Create peer connection
//   _pc = await createPeerConnection(config);

//   // ✅ Use getUserMedia and addTrack instead of addStream
//   final stream = await navigator.mediaDevices
//       .getUserMedia({'audio': true, 'video': true});

//   // Set local video
//   _localRenderer.srcObject = stream;

//   // Add each track individually
//   for (var track in stream.getTracks()) {
//     _pc.addTrack(track, stream);
//   }

//   // ✅ Use onTrack instead of onAddStream
//   _pc.onTrack = (RTCTrackEvent event) {
//     if (event.streams.isNotEmpty) {
//       _remoteRenderer.srcObject = event.streams[0];
//     }
//   };

//   // ICE candidates
//   _pc.onIceCandidate = (candidate) {
//     _channel.sink.add(jsonEncode({'ice': candidate.toMap()}));
//   };

//   // Handle messages from the signaling server
//   _channel.stream.listen((msg) async {
//     final data = jsonDecode(msg);

//     if (data['from'] != null) {
//       debugPrint('Incoming call from: ${data['from']}');
//     }

//     if (data['sdp'] != null) {
//       await _pc.setRemoteDescription(
//         RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']),
//       );
//       if (data['sdp']['type'] == 'offer') {
//         final answer = await _pc.createAnswer();
//         await _pc.setLocalDescription(answer);
//         _channel.sink.add(jsonEncode({'sdp': answer.toMap()}));
//       }
//     } else if (data['ice'] != null) {
//       await _pc.addCandidate(RTCIceCandidate(
//         data['ice']['candidate'],
//         data['ice']['sdpMid'],
//         data['ice']['sdpMLineIndex'],
//       ));
//     }
//   });

//   // Caller creates offer and sends with caller ID
//   final offer = await _pc.createOffer();
//   await _pc.setLocalDescription(offer);

//   const myCallerId = '6282541243';
//   _channel.sink.add(jsonEncode({
//     'sdp': offer.toMap(),
//     'from': myCallerId,
//   }));
// }


//   @override
//   Widget build(BuildContext context) => Scaffold(
//         body: Row(
//           children: [
//             Expanded(child: RTCVideoView(_localRenderer, mirror: true)),
//             Expanded(child: RTCVideoView(_remoteRenderer)),
//           ],
//         ),
//       );

//   @override
//   void dispose() {
//     _localRenderer.dispose();
//     _remoteRenderer.dispose();
//     _pc.close();
//     _channel.sink.close();
//     super.dispose();
//   }
// }
