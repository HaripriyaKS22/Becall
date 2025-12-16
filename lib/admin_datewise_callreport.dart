import 'dart:convert';
import 'package:becall2/admin_personwise_report.dart';
import 'package:becall2/api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class admin_CallreportDateWise extends StatefulWidget {
  const admin_CallreportDateWise({super.key});

  @override
  State<admin_CallreportDateWise> createState() => _admin_CallreportDateWiseState();
}

class _admin_CallreportDateWiseState extends State<admin_CallreportDateWise> {
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

  try {
    var res = await http.get(
      Uri.parse("$api/api/call/report/"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode == 200) {
      List<dynamic> allData = jsonDecode(res.body);

      // ---------------- FILTER BY DATE RANGE ----------------
      List<dynamic> data = allData.where((call) {
        if (call['date'] == null &&
            call['call_datetime'] == null &&
            call['created_at'] == null) {
          return false;
        }

        try {
          String dateStr =
              call['date'] ?? call['call_datetime'] ?? call['created_at'];

          DateTime callDate = DateTime.parse(dateStr).toLocal();
          String formatted = DateFormat('yyyy-MM-dd').format(callDate);

          DateTime onlyDate = DateTime.parse(formatted); // remove time

          return onlyDate.isAfter(from.subtract(const Duration(days: 1))) &&
              onlyDate.isBefore(to.add(const Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }).toList();

      // ---------------- GROUP BY STAFF ----------------
      Map<String, Map<String, dynamic>> grouped = {};

      for (var call in data) {
        String name = call['created_by_name'] ?? 'Unknown';
        int creatorId = call['created_by'] ?? 0;

        String status = (call['status'] ?? '').toString().toLowerCase();
        String durationStr = call['duration'] ?? '0 sec';

        double amount =
            (call['amount'] == null) ? 0.0 : (call['amount'] as num).toDouble();

        grouped.putIfAbsent(
          name,
          () => {
            'created_by': creatorId, // ADDED
            'productive_count': 0,
            'active_count': 0,
            'total_count': 0,
            'productive_duration': 0,
            'active_duration': 0,
            'total_duration': 0,
            'amount': 0.0,
          },
        );

        int dur = parseDuration(durationStr);

        if (status == 'productive') {
          grouped[name]!['productive_count'] += 1;
          grouped[name]!['productive_duration'] += dur;
          grouped[name]!['amount'] += amount;
        }

        if (status == 'active') {
          grouped[name]!['active_count'] += 1;
          grouped[name]!['active_duration'] += dur;
        }

        grouped[name]!['total_count'] += 1;
        grouped[name]!['total_duration'] += dur;
      }

      // ---------------- SORT BY TOTAL DURATION DESC ----------------
      List<Map<String, dynamic>> sortedList = grouped.entries
          .map((e) => {
                'created_by': e.value['created_by'],
                'name': e.key,
                'productive_count': e.value['productive_count'],
                'active_count': e.value['active_count'],
                'total_count': e.value['total_count'],
                'productive_duration': e.value['productive_duration'],
                'active_duration': e.value['active_duration'],
                'total_duration': e.value['total_duration'],
                'amount': e.value['amount'],
              })
          .toList()
        ..sort((a, b) => b['total_duration'].compareTo(a['total_duration']));

      setState(() {
        groupedData = sortedList;
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
  scrollDirection: Axis.horizontal,
  child: ConstrainedBox(
    constraints: BoxConstraints(
      minWidth: MediaQuery.of(context).size.width * 2,
    ),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 1),
      ),

      child: Table(
        border: TableBorder.symmetric(
          inside: const BorderSide(color: Colors.white24, width: 0.5),
          outside: const BorderSide(color: Colors.white24, width: 1),
        ),

        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1.5),
          4: FlexColumnWidth(2),
          5: FlexColumnWidth(2),
          6: FlexColumnWidth(2),
          7: FlexColumnWidth(2),
        },

        children: [
          // ---------------- HEADER ----------------
          const TableRow(
            decoration: BoxDecoration(color: Color.fromARGB(255, 26, 164, 143)),
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Staff", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Productive", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Active", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Total", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Productive Duration", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Active Duration", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Total Duration", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Amount", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),

          // ------------------- SUMMARY ROW -------------------
          (() {
            int totalProd = groupedData.fold<int>(0, (sum, item) => sum + (((item['productive_count'] ?? 0) as num).toInt()));
            int totalAct = groupedData.fold<int>(0, (sum, item) => sum + (((item['active_count'] ?? 0) as num).toInt()));
            int totalCnt = groupedData.fold<int>(0, (sum, item) => sum + (((item['total_count'] ?? 0) as num).toInt()));

            int totalProdDur = groupedData.fold<int>(0, (sum, item) => sum + (((item['productive_duration'] ?? 0) as num).toInt()));
            int totalActDur = groupedData.fold<int>(0, (sum, item) => sum + (((item['active_duration'] ?? 0) as num).toInt()));
            int totalDur = groupedData.fold<int>(0, (sum, item) => sum + (((item['total_duration'] ?? 0) as num).toInt()));

            double totalAmt = groupedData.fold<double>(0.0, (sum, item) => sum + (((item['amount'] ?? 0) as num).toDouble()));

            String format(int sec) => "$sec sec";

            return TableRow(
              
              decoration: const BoxDecoration(color: Color.fromARGB(255, 173, 168, 38)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("TOTAL",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("$totalProd",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("$totalAct",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("$totalCnt",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(format(totalProdDur),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(format(totalActDur),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(format(totalDur),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("₹${totalAmt.toStringAsFixed(0)}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          })(),

          // ------------------- ALL STAFF ROWS -------------------
          ...groupedData.map((item) {
            String format(int sec) => "$sec sec";

            return TableRow(
              decoration: const BoxDecoration(color: Color(0xFF181818)),
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Admin_PersonwiseReport(id: item['created_by']),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(item['name'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("${item['productive_count']}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("${item['active_count']}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("${item['total_count']}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(format(item['productive_duration']),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(format(item['active_duration']),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(format(item['total_duration']),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("₹${item['amount'].toStringAsFixed(0)}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          }).toList(),
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
