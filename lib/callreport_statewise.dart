import 'dart:convert';
import 'package:becall2/api.dart';
import 'package:becall2/callreport_in_a_state.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallreportStatewise extends StatefulWidget {
  const CallreportStatewise({super.key});

  @override
  State<CallreportStatewise> createState() => _CallreportStatewiseState();
}

class _CallreportStatewiseState extends State<CallreportStatewise> {
  bool isLoading = true;
  List<dynamic> allCalls = [];
  List<dynamic> filteredCalls = [];

  DateTimeRange? selectedRange;
  DateTime today = DateTime.now();

  @override
  void initState() {
    super.initState();
    fetchCallReports();
    
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

  Future<void> fetchCallReports() async {
    try {
      var token = await getToken();
      var userId = await getUserId();

      if (userId == null) {
        return;
      }

      final response = await http.get(
        Uri.parse('$api/api/call/report/'),
        headers: {
          'Authorization': 'Bearer $token',
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          // 1. Only logged-in staff calls
          allCalls = data.where((c) => c['created_by'] == userId).toList();

          // 2. Only Productive calls
          allCalls =
              allCalls.where((c) => c['status'] == 'Productive').toList();

          // 3. Apply today filter initially
          filteredCalls = _filterByDateRange(allCalls, today, today);

          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  List<dynamic> _filterByDateRange(
    List<dynamic> data,
    DateTime start,
    DateTime end,
  ) {
    return data.where((call) {
      final createdAt = call['date'];
      if (createdAt == null) return false;

      try {
        final callDate = DateTime.parse(createdAt).toLocal();
        final callDay = DateTime(callDate.year, callDate.month, callDate.day);
        final startDay = DateTime(start.year, start.month, start.day);
        final endDay = DateTime(end.year, end.month, end.day);

        return (callDay.isAtSameMomentAs(startDay) ||
                callDay.isAfter(startDay)) &&
            (callDay.isAtSameMomentAs(endDay) || callDay.isBefore(endDay));
      } catch (_) {
        return false;
      }
    }).toList();
  }


  Future<void> _selectDateRange() async
   {
    DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          selectedRange ?? DateTimeRange(start: today, end: today),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: Colors.black,
            dialogBackgroundColor: Colors.black, 
            canvasColor: Colors.black, 
            cardColor: Colors.black,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1AA48F),
              onPrimary: Colors.white, 
              surface: Colors.black, 
              onSurface: Colors.white, 
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedRange = picked;
        filteredCalls = _filterByDateRange(allCalls, picked.start, picked.end);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, Map<String, dynamic>> stateSummary = {};

    for (var call in filteredCalls) {
      String state = '';
      if (call['state'] != null && call['state'].toString().trim().isNotEmpty) {
        state = call['state'].toString();
      } else if (call['state_name'] != null &&
          call['state_name'].toString().trim().isNotEmpty) {
        state = call['state_name'].toString();
      } else {
        state = 'Unknown';
      }

      String status = (call['status'] ?? '').toString();
      double amount = double.tryParse(call['amount']?.toString() ?? '0') ?? 0.0;

      if (!stateSummary.containsKey(state)) {
        stateSummary[state] = {'Active': 0, 'Productive': 0, 'Amount': 0.0};
      }

      if (status == 'Active') {
        stateSummary[state]!['Active']++;
      } else if (status == 'Productive') {
        stateSummary[state]!['Productive']++;
        stateSummary[state]!['Amount'] += amount;
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "State-wise Call Summary",
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: const Color(0xFF1AA48F),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : stateSummary.isEmpty
              ? const Center(
                child: Text(
                  "No datas found for selected range",
                  style: TextStyle(color: Colors.white70),
                ),
              )
              : Column(
                children: [
                  if (selectedRange != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Showing: ${DateFormat('dd MMM yyyy').format(selectedRange!.start)} → ${DateFormat('dd MMM yyyy').format(selectedRange!.end)}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Showing: ${DateFormat('dd MMM yyyy').format(today)}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Table(
                        border: TableBorder.all(color: Colors.white24),
                        columnWidths: const {
                          0: FlexColumnWidth(2),
                          1: FlexColumnWidth(1),
                          2: FlexColumnWidth(1),
                          3: FlexColumnWidth(1.5),
                        },
                        children: [
                          // ✅ Header Row
                          const TableRow(
                            decoration: BoxDecoration(color: Color(0xFF1AA48F)),
                            children: [
                              Padding(
                                padding: EdgeInsets.all(10.0),
                                child: Text(
                                  "State",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              // Padding(
                              //   padding: EdgeInsets.all(10.0),
                              //   child: Text(
                              //     "Active",
                              //     textAlign: TextAlign.center,
                              //     style: TextStyle(
                              //         color: Colors.white,
                              //         fontWeight: FontWeight.bold,
                              //         fontSize: 16),
                              //   ),
                              // ),
                              Padding(
                                padding: EdgeInsets.all(10.0),
                                child: Text(
                                  "Productive",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(10.0),
                                child: Text(
                                  "Amount (₹)",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // ✅ Data Rows
                          ...stateSummary.entries.toList().asMap().entries.map((
                            entry,
                          ) {
                            final index = entry.key;
                            final state = entry.value.key;
                            final stats = entry.value.value;

                            return TableRow(
                              decoration: BoxDecoration(
                                color:
                                    index.isEven
                                        ? Colors.grey.shade900
                                        : Colors.grey.shade800,
                              ),
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => Statewise(id: state),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Text(
                                      state,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                                // Padding(
                                //   padding: const EdgeInsets.all(10.0),
                                //   child: Text(
                                //     stats['Active'].toString(),
                                //     textAlign: TextAlign.center,
                                //     style: const TextStyle(
                                //         color: Colors.orange,
                                //         fontWeight: FontWeight.bold),
                                //   ),
                                // ),
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Text(
                                    stats['Productive'].toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF1AA48F),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Text(
                                    stats['Amount'].toStringAsFixed(2),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.yellowAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),

                          // ✅ Total Row
                          TableRow(
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                            ),
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(10.0),
                                child: Text(
                                  "TOTAL",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Padding(
                              //   padding: const EdgeInsets.all(10.0),
                              //   child: Text(
                              //     stateSummary.values
                              //         .fold<int>(
                              //             0,
                              //             (sum, v) =>
                              //                 sum + ((v['Active'] ?? 0) as int))
                              //         .toString(),
                              //     textAlign: TextAlign.center,
                              //     style: const TextStyle(
                              //         color: Colors.orange,
                              //         fontWeight: FontWeight.bold),
                              //   ),
                              // ),
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Text(
                                  stateSummary.values
                                      .fold<int>(
                                        0,
                                        (sum, v) =>
                                            sum +
                                            ((v['Productive'] ?? 0) as int),
                                      )
                                      .toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF1AA48F),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Text(
                                  stateSummary.values
                                      .fold<double>(
                                        0.0,
                                        (sum, v) => sum + (v['Amount'] ?? 0),
                                      )
                                      .toStringAsFixed(2),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.yellowAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
