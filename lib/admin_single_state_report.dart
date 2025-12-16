import 'dart:convert';
import 'package:becall2/api.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class admin_Statewise extends StatefulWidget {
  final String id; // actually the state name, e.g. "Kerala"
  const admin_Statewise({super.key, required this.id});

  @override
  State<admin_Statewise> createState() => _admin_StatewiseState();
}

class _admin_StatewiseState extends State<admin_Statewise> {
  List<dynamic> _allCustomers = [];
  List<dynamic> _filteredCustomers = [];
  bool _loading = true;

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _resolveStateIdAndFetch(); // Fetch all data initially
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _resolveStateIdAndFetch() async {
    try {
      final token = await getToken();
      final url = Uri.parse("$api/api/states/");
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final List<dynamic> states = jsonResponse['data'] ?? [];

        final matched = states.firstWhere(
          (s) =>
              (s['name'] ?? '').toString().trim().toLowerCase() ==
              widget.id.trim().toLowerCase(),
          orElse: () => <String, dynamic>{},
        );

        if (matched.isNotEmpty) {
          final int stateId = matched['id'];
          await _fetchCustomers(stateId);
        } else {
          setState(() => _loading = false);
        }
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchCustomers(int stateId) async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse("$api/api/call/report/state/$stateId/"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        // Sort by date (latest first)
        data.sort((a, b) {
          final da = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1900);
          final db = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1900);
          return db.compareTo(da);
        });

        setState(() {
          _allCustomers = data;
          _applyDateFilter(); // Filter today's data initially
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _applyDateFilter() {
    final now = DateTime.now();
    final start = _startDate ?? now;
    final end = _endDate ?? now;

    final filtered = _allCustomers.where((c) {
      final d = DateTime.tryParse(c['call_datetime'] ?? '');
      if (d == null) return false;
      return d.isAfter(start.subtract(const Duration(days: 1))) &&
          d.isBefore(end.add(const Duration(days: 1)));
    }).toList();

    filtered.sort((a, b) {
      final da = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1900);
      final db = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1900);
      return db.compareTo(da);
    });

    setState(() {
      _filteredCustomers = filtered;
      print("Filtered customers count: ${_filteredCustomers.length}");
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyDateFilter();
    }
  }
void _showFullImage(String imageUrl) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black.withOpacity(0.95),
          child: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final dateLabel = _startDate == null
        ? "Showing Today's Calls"
        : "From ${DateFormat('dd MMM').format(_startDate!)} "
            "to ${DateFormat('dd MMM').format(_endDate!)}";

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1AA48F),
        title: Text("Calls in ${widget.id}",
            style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    dateLabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                Expanded(
                  child: _filteredCustomers.isEmpty
                      ? const Center(
                          child: Text("No calls found",
                              style: TextStyle(color: Colors.white70)),
                        )
                      :Padding(
  padding: const EdgeInsets.all(16),
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Table(
        border: TableBorder.all(color: Colors.white30, width: 1),
        defaultColumnWidth: const IntrinsicColumnWidth(), // Auto adjust like table
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: IntrinsicColumnWidth(),
          2: IntrinsicColumnWidth(),
          3: IntrinsicColumnWidth(),
          4: IntrinsicColumnWidth(),
          5: IntrinsicColumnWidth(),
        },

        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF1AA48F)),
            children: [
              _headerCell("Customer Name"),
              _headerCell("Duration"),
              _headerCell("Status"),
              _headerCell("Amount"),
              _headerCell("Created By"),
              _headerCell("Image")
            ],
          ),

          ..._filteredCustomers.map((c) {
            final isProductive = c['status'] == 'Productive';
            final amount = c['amount'];
            final imagePath = c['images'];

            return TableRow(
              decoration: BoxDecoration(
                color: _filteredCustomers.indexOf(c).isEven
                    ? Colors.grey.shade900
                    : Colors.grey.shade800,
              ),
              children: [
                _dataCell(c['customer_name']?.toString() ?? "-"),

                _dataCell(
                  c['duration']?.toString() ?? "-",
                  color: Colors.orangeAccent,
                ),

                _dataCell(
                  c['status'] ?? "-",
                  color: isProductive ? Colors.greenAccent : Colors.redAccent,
                  bold: true,
                ),

                _dataCell(
                  isProductive && amount != null ? "₹$amount" : "-",
                  color: isProductive ? Colors.yellowAccent : Colors.white24,
                ),

                _dataCell(c['created_by_name']?.toString() ?? "-"),

                Padding(
                  padding: const EdgeInsets.all(8),
                  child: imagePath != null && imagePath.toString().isNotEmpty
                      ? GestureDetector(
                          onTap: () => _showFullImage("$api$imagePath"),
                          child: Image.network(
                            "$api$imagePath",
                            height: 40,
                            width: 40,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Text(
                          "-",
                          style: TextStyle(color: Colors.white54),
                        ),
                ),
              ],
            );
          }).toList(),

          // TOTAL ROW
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF1AA48F)),
            children: [
              _headerCell("TOTAL"),
              _headerCell(_filteredCustomers.length.toString()),
              _headerCell(""),
              _headerCell(
                "₹${_filteredCustomers.where((c) => c['status'] == 'Productive' && c['amount'] != null)
                  .fold<double>(0, (sum, c) => sum + (c['amount'] ?? 0))}",
              ),
              _headerCell(""),
              _headerCell(""),
            ],
          ),
        ],
      ),
    ),
  ),
)




                ),
              ],
            ),
    );
  }
  
}
Widget _headerCell(String text) {
  return Padding(
    padding: const EdgeInsets.all(10),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
      textAlign: TextAlign.center,
    ),
  );
}

Widget _dataCell(String text, {Color color = Colors.white, bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.all(8),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
    ),
  );
}
