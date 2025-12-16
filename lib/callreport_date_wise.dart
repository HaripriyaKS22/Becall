import 'dart:convert';
import 'package:becall2/api.dart';
import 'package:becall2/call_report_person_wise.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CallreportDateWise extends StatefulWidget {
  const CallreportDateWise({super.key});

  @override
  State<CallreportDateWise> createState() => _CallreportDateWiseState();
}

class _CallreportDateWiseState extends State<CallreportDateWise> {
  List<Map<String, dynamic>> groupedData = [];
  bool isLoading = true;

  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    DateTime today = DateTime.now();
    startDate = today;
    endDate = today;
    getDateWise(today, today);
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<int?> getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('id');
  }

  int parseDuration(String duration) {
    int totalSeconds = 0;
    final minMatch = RegExp(r'(\d+)\s*min').firstMatch(duration);
    final secMatch = RegExp(r'(\d+)\s*sec').firstMatch(duration);
    if (minMatch != null) totalSeconds += int.parse(minMatch.group(1)!) * 60;
    if (secMatch != null) totalSeconds += int.parse(secMatch.group(1)!);
    return totalSeconds;
  }

  String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return "${minutes}m ${remainingSeconds}s";
    } else {
      return "${remainingSeconds}s";
    }
  }

  var id;
  Future<void> getDateWise(DateTime from, DateTime to) async {
    setState(() {
      isLoading = true;
    });

    var token = await getToken();
    String fromStr = DateFormat('yyyy-MM-dd').format(from);
    String toStr = DateFormat('yyyy-MM-dd').format(to);

    try {
      // ✅ If your backend supports date-range:
      var res = await http.get(
        Uri.parse(
          "$api/api/call/report/staff/date-range?from=$fromStr&to=$toStr",
        ),
        headers: {"Authorization": "Bearer $token"},
      );

      int? userId = await getUserId();

      // ✅ Fallback to single date
      if (res.statusCode != 200) {
        res = await http.get(
          Uri.parse(
            "$api/api/call/report/staff/$userId/?from=$fromStr&to=$toStr",
          ),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
        );
      }
      print(res.statusCode);
      print(res.body);
      if (res.statusCode == 200) {
        List<dynamic> data = jsonDecode(res.body);
        Map<String, Map<String, dynamic>> grouped = {};

        for (var call in data) {
          id = call['created_by'];

          String name = call['created_by_name'] ?? 'Unknown';
          String status = call['status'] ?? '';
          String durationStr = call['duration'] ?? '0 sec';
          double amount = (call['amount'] ?? 0).toDouble();

          if (status.toLowerCase() == 'productive' ||
              status.toLowerCase() == 'Active') {
            grouped.putIfAbsent(
              name,
              () => {'count': 0, 'duration': 0, 'amount': 0.0},
            );

            grouped[name]!['count'] += 1;
            grouped[name]!['duration'] += parseDuration(durationStr);
            grouped[name]!['amount'] += amount;
          }
        }

        setState(() {
          groupedData =
              grouped.entries
                  .map(
                    (e) => {
                      'name': e.key,
                      'count': e.value['count'],
                      'duration': e.value['duration'],
                      'amount': e.value['amount'],
                    },
                  )
                  .toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: startDate ?? DateTime.now(),
        end: endDate ?? DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1AA48F),
              onPrimary: Colors.white,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      getDateWise(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    String rangeText = "";
    if (startDate != null && endDate != null) {
      final fmt = DateFormat('dd MMM');
      rangeText =
          "${fmt.format(startDate!)} - ${fmt.format(endDate!)} (${DateFormat('yyyy').format(startDate!)})";
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1AA48F),
        title: const Text(
          "Productive Calls",
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            onPressed: pickDateRange,
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : Column(
                children: [
                  // 🔹 Date Range Header
                  Container(
                    width: double.infinity,
                    color: Colors.grey[900],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      rangeText.isEmpty ? "Today" : rangeText,
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Table(
                          border: TableBorder.all(
                            color: Colors.white24,
                            width: 1,
                          ),
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1.3),
                            3: FlexColumnWidth(1.5),
                          },
                          children: [
                            // 🔹 Table Header
                            TableRow(
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                              ),
                              children: const [
                                Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text(
                                    "Created By",
                                    style: TextStyle(
                                      color: Colors.tealAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text(
                                    "Calls",
                                    style: TextStyle(
                                      color: Colors.tealAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text(
                                    "Duration",
                                    style: TextStyle(
                                      color: Colors.tealAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text(
                                    "Amount",
                                    style: TextStyle(
                                      color: Colors.tealAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),

                            // 🔹 TOTAL Row (Cumulative)
                            if (groupedData.isNotEmpty)
                              TableRow(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E1E1E),
                                ),
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Text(
                                      "TOTAL",
                                      style: TextStyle(
                                        color: Colors.tealAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                      groupedData
                                          .fold<int>(
                                            0,
                                            (sum, row) =>
                                                sum +
                                                ((row['count'] ?? 0) as int),
                                          )
                                          .toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                      formatDuration(
                                        groupedData.fold<int>(
                                          0,
                                          (sum, row) =>
                                              sum +
                                              ((row['duration'] ?? 0) as int),
                                        ),
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                      "₹${groupedData.fold<double>(0, (sum, row) => sum + (row['amount'] ?? 0.0)).toStringAsFixed(2)}",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.tealAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                            // 🔹 Data Rows
                            ...groupedData.map((row) {
                              return TableRow(
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                ),
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  CallreportpersonWise(id: id),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Text(
                                        row['name'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                      row['count'].toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                      formatDuration(row['duration']),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                      "₹${row['amount'].toStringAsFixed(2)}",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.tealAccent,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
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
