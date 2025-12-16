import 'dart:convert';
import 'package:becall2/api.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class Statewise extends StatefulWidget {
  final String id; // actually the state name, e.g. "Kerala"
  const Statewise({super.key, required this.id});

  @override
  State<Statewise> createState() => _StatewiseState();
}

class _StatewiseState extends State<Statewise> {
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
Future<int?> getUserId() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  var idValue = prefs.get('id');
  if (idValue is int) return idValue;
  if (idValue is String) return int.tryParse(idValue);
  return null;
}

  Future<void> _resolveStateIdAndFetch() async {
    try {
      final token = await getToken();
      final url = Uri.parse("$api/api/states/");
      final response = await http.get(url, headers: {"Authorization": "Bearer $token","Content-Type": "application/json",});

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final List<dynamic> states = jsonResponse['data'] ?? [];

        final matched = states.firstWhere(
          (s) => (s['name'] ?? '').toString().trim().toLowerCase() ==
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
  final userId = await getUserId();   // logged-in staff ID

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

      // FILTER ONLY LOGGEDIN STAFF'S CALLS
      final filteredByUser = data.where((c) {
        return c['created_by'] == userId;
      }).toList();

      // Sort by date (latest first)
      filteredByUser.sort((a, b) {
        final da = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1900);
        final db = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1900);
        return db.compareTo(da);
      });

      setState(() {
        _allCustomers = filteredByUser;
        _applyDateFilter();
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
        title: Text("Calls in ${widget.id}", style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                      : Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Table(
                              border: TableBorder.all(color: Colors.white24),
                              columnWidths: const {
                                0: FlexColumnWidth(3), // Customer Name
                                1: FlexColumnWidth(1.5), // Duration (now used for count)
                                2: FlexColumnWidth(1), // Status
                                3: FlexColumnWidth(1.5), // Amount
                              },
                              children: [
                                // Header Row
                                const TableRow(
                                  decoration: BoxDecoration(color: Color(0xFF1AA48F)),
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.all(10.0),
                                      child: Text("Customer Name",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(10.0),
                                      child: Text("Duration",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                          textAlign: TextAlign.center),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(10.0),
                                      child: Text("Status",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                          textAlign: TextAlign.center),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(10.0),
                                      child: Text("Amount",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                          textAlign: TextAlign.center),
                                    ),
                                  ],
                                ),

                                // Data Rows
                                ..._filteredCustomers.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final c = entry.value;
                                  final isProductive = c['status'] == 'Productive';
                                  final amount = c['amount'];

                                  return TableRow(
                                    decoration: BoxDecoration(
                                      color: index.isEven
                                          ? Colors.grey.shade900
                                          : Colors.grey.shade800,
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          c['customer_name'] ?? '-',
                                          style: const TextStyle(color: Colors.white, fontSize: 14),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          c['duration'] ?? '-',
                                          style: const TextStyle(
                                              color: Colors.orangeAccent, fontSize: 13),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          c['status'] ?? '-',
                                          style: TextStyle(
                                            color: isProductive
                                                ? Colors.greenAccent
                                                : Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          isProductive && amount != null
                                              ? '₹${amount.toString()}'
                                              : '-',
                                          style: TextStyle(
                                            color: isProductive
                                                ? Colors.yellowAccent
                                                : Colors.white24,
                                            fontWeight: isProductive
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList()

                                // ✅ Total Row
                                ..add(
                                  TableRow(
                                    decoration: const BoxDecoration(color: Color(0xFF1AA48F)),
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.all(10.0),
                                        child: Text(
                                          "TOTAL",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),

                                      // 📞 Total calls shown under Duration
                                      Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Text(
                                          _filteredCustomers.length.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),

                                      const SizedBox(),

                                      // 💰 Total productive amount
                                      Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Text(
                                          '₹${_filteredCustomers.where((c) => c['status'] == 'Productive' && c['amount'] != null)
                                              .fold<double>(0, (sum, c) => sum + (c['amount'] ?? 0))}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
