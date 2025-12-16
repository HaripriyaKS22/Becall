import 'dart:convert';

import 'package:becall2/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as https;
import 'package:shared_preferences/shared_preferences.dart';

class CustomerDetailsView extends StatefulWidget {
  final String customerName;
  final String phoneNumber;
  final dynamic date;
  final String? stateName;
  final int id;

  const CustomerDetailsView({
    super.key,
    required this.customerName,
    required this.phoneNumber,
    required this.date,
    required this.stateName,
    required this.id,
  });

  @override
  State<CustomerDetailsView> createState() => _CustomerDetailsViewState();
}

class _CustomerDetailsViewState extends State<CustomerDetailsView> {
  bool saveNotes = false;
  DateTime? _reminderDate;
  final TextEditingController _noteController = TextEditingController();

  List<CallLogEntry> _displayCalls = [];
  String _headerDate = '';
  List<dynamic> _customers = [];
   bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchCalls();
    _fetchCustomers();
  }
   Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
 Future<String?> getid() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  final id = prefs.getInt('id'); // fetch as int
  return id?.toString();         // convert safely to String
}

Future<void> _fetchCustomers() async {
  var token = await getToken();
  var id = await getid();

  setState(() => _loading = true);
  try {
    var response = await https.get(
      Uri.parse("$api/api/contact/info/staff/$id/"),
      headers: {"Authorization": "Bearer $token"},
    );

    print('Customer fetch status: ${response.statusCode}');
    print('Customer fetch body: ${response.body}');

    if (response.statusCode == 200) {
      // decode once
      final data = List<dynamic>.from(jsonDecode(response.body));

      // 🔹 find this customer (matching widget.id) and read note
      String? existingNote;
      for (var c in data) {
        if (c['id'] == widget.id) {
          existingNote = c['note'];
          break;
        }
      }

      setState(() {
        _customers = data;
        _loading = false;
      });

      // 🔹 set the text of the notes field if note exists
      if (existingNote != null && existingNote.toString().trim().isNotEmpty) {
        _noteController.text = existingNote.toString();
      }
    } else {
      setState(() => _loading = false);
    }
  } catch (e) {
    setState(() {
      _customers = [];
      _loading = false;
    });
  }
}

Future<void> _updateContact() async {
  final id = await getid();

  try {
    final token = await getToken();

    final response = await https.put(
      Uri.parse('$api/api/contact/info/${widget.id}/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'note': _noteController.text}),
    );

  print('Update response status: ${response.statusCode}');
  print('Update response body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update contact. Code: ${response.statusCode}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error updating contact: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> _fetchCalls() async {
  if (!await Permission.phone.request().isGranted) return;

  final logs = await CallLog.query(number: widget.phoneNumber);
  if (logs.isEmpty) return;

  // Define "today" and "yesterday" ranges
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  final yesterdayStart = todayStart.subtract(const Duration(days: 1));
  final yesterdayEnd = todayStart;

  // 1️⃣ Filter today's calls
  List<CallLogEntry> filtered = logs.where((c) {
    final ts = DateTime.fromMillisecondsSinceEpoch(c.timestamp ?? 0);
    return ts.isAfter(todayStart) && ts.isBefore(todayEnd);
  }).toList();

  // 2️⃣ If no calls today → use yesterday
  bool showingYesterday = false;
  if (filtered.isEmpty) {
    filtered = logs.where((c) {
      final ts = DateTime.fromMillisecondsSinceEpoch(c.timestamp ?? 0);
      return ts.isAfter(yesterdayStart) && ts.isBefore(yesterdayEnd);
    }).toList();
    showingYesterday = true;
  }

  // Sort newest first
  filtered.sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));

  // Set header text
  _headerDate = showingYesterday ? 'Yesterday' : 'Today';

  setState(() {
    _displayCalls = filtered;
  });
}

  Future<void> _callDirect(String n) async =>
      FlutterPhoneDirectCaller.callNumber(n);

  Future<void> _pickReminderDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reminderDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder:
          (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color.fromARGB(255, 26, 164, 143),
                onPrimary: Colors.white,
                surface: Colors.black,
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          ),
    );
    if (picked != null) setState(() => _reminderDate = picked);
  }
  final FocusNode _focusNode = FocusNode();

final FocusNode _notesFocus = FocusNode();

@override
void dispose() {
  _noteController.dispose();
  _notesFocus.dispose();
  super.dispose();
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ---------- Header ----------
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 24),
            width: double.infinity,
            decoration: const BoxDecoration(
              // ✅ Gradient replacing the solid color
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF009688), // top: deep teal
                  Color(0xFF26A69A), // bottom: lighter teal
                ],
              ),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 50, color: Colors.black),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.customerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.phoneNumber,
                  style: const TextStyle(color: Colors.white70),
                ),

                // --- Curved container with location and icons ---
                Container(
                  margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(129, 13, 125, 114),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.stateName ?? '', // 👈 dynamic state name
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      Row(
                        children: [
                          _circleAction(
                            icon: Icons.call,
                            onTap: () => _callDirect(widget.phoneNumber),
                          ),
                          const SizedBox(width: 12),
                          _circleAction(icon: Icons.message, onTap: () {}),
                          const SizedBox(width: 12),
                          _circleAction(icon: Icons.chat, onTap: () {}),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ---------- Body ----------
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.date != null)
                    Text(
                      _headerDate.isEmpty ? 'Loading…' : _headerDate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 8),

                  // ✅ NEW SECTION — Recent Calls
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Calls',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_displayCalls.isEmpty)
                          const Text(
                            'No recent calls',
                            style: TextStyle(color: Colors.white70),
                          )
                        else
                          Column(
                            children:
                                _displayCalls.take(5).map((c) {
                                  final dt =
                                      DateTime.fromMillisecondsSinceEpoch(
                                        c.timestamp ?? 0,
                                      );
                                  final date =
                                      '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}';
                                  final time =
                                      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                  final dur = c.duration ?? 0;
                                  final type = c.callType?.name ?? 'Call';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '$date $time',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$type • ${dur}s',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

            // ✅ Notes section — only show if contact id exists
if (widget.id != 0 && widget.id != null) ...[
  const Text(
    'Notes',
    style: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  ),
  const SizedBox(height: 8),

  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey[900],
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _noteController,
            focusNode: _notesFocus,
            style: const TextStyle(color: Colors.white),
            maxLines: 5,
            onChanged: (text) {
              if (saveNotes) {
                _updateContact();
              }
            },
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText:
                  saveNotes ? 'Type notes here...' : 'Type notes (not saving)…',
              hintStyle: const TextStyle(color: Colors.white54),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Transform.scale(
          scale: 1.2,
          child: Switch(
            value: saveNotes,
            activeColor: const Color.fromARGB(255, 26, 164, 143),
            onChanged: (v) async {
              setState(() => saveNotes = v);

              if (v) {
                await _updateContact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notes saving enabled and synced!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                _noteController.clear();
                _notesFocus.requestFocus();
              }
            },
          ),
        ),
      ],
    ),
  ),
] else ...[
  // 👇 Show message if no contact id
  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey[900],
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Center(
      child: Text(
        'Notes unavailable (contact not saved)',
        style: TextStyle(color: Colors.white70),
      ),
    ),
  ),
],

                  const SizedBox(height: 20),

                  // SizedBox(
                  //   width: double.infinity,
                  //   child: ElevatedButton.icon(
                  //     icon: const Icon(
                  //       Icons.calendar_today,
                  //       color: Colors.white,
                  //     ),
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Colors.grey[850],
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //       padding: const EdgeInsets.symmetric(vertical: 16),
                  //     ),
                  //     onPressed: _pickReminderDate,
                  //     label: Text(
                  //       _reminderDate == null
                  //           ? 'Set Reminder'
                  //           : 'Reminder: ${_reminderDate!.day}-${_reminderDate!.month}-${_reminderDate!.year}',
                  //       style: const TextStyle(color: Colors.white),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleAction({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
