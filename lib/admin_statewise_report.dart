  import 'dart:convert';
import 'package:becall2/admin_single_state_report.dart';
import 'package:becall2/api.dart';
  import 'package:flutter/material.dart';
  import 'package:http/http.dart' as http;
  import 'package:intl/intl.dart';
  import 'package:shared_preferences/shared_preferences.dart';

  class admin_CallreportStatewise extends StatefulWidget {
    const admin_CallreportStatewise({super.key});

    @override
    State<admin_CallreportStatewise> createState() => _admin_CallreportStatewiseState();
  }

  class _admin_CallreportStatewiseState extends State<admin_CallreportStatewise> {
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
          headers: {'Authorization': 'Bearer $token',"Content-Type": "application/json",},
        );


        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            allCalls = data;
            // ✅ Filter only today's calls initially
            filteredCalls = _filterByDateRange(
              data,
              today,
              today,
            );
            isLoading = false;
          });
              print('filteredCalls count: ${filteredCalls}'); // Debug log

        } else {
          setState(() => isLoading = false);
        }
      } catch (e) {
        setState(() => isLoading = false);
      }
    }

    /// ✅ Utility to filter data between dates
  List<dynamic> _filterByDateRange(List<dynamic> data, DateTime start, DateTime end) {
    return data.where((call) {
      final createdAt = call['created_at'];
      if (createdAt == null) return false;

      try {
        final callDate = DateTime.parse(createdAt).toLocal();
        final callDay = DateTime(callDate.year, callDate.month, callDate.day);
        final startDay = DateTime(start.year, start.month, start.day);
        final endDay = DateTime(end.year, end.month, end.day);

        return (callDay.isAtSameMomentAs(startDay) || callDay.isAfter(startDay)) &&
              (callDay.isAtSameMomentAs(endDay) || callDay.isBefore(endDay));
      } catch (_) {
        return false;
      }
    }).toList();
  }


    Future<void> _selectDateRange() async {
    DateTime now = DateTime.now();

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: selectedRange ??
          DateTimeRange(
            start: today,
            end: today,
          ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith( // 👈 Force DARK theme globally
            scaffoldBackgroundColor: Colors.black,
            dialogBackgroundColor: Colors.black, // 👈 Dialog background
            canvasColor: Colors.black, // 👈 Calendar background
            cardColor: Colors.black, // 👈 Inner surfaces
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1AA48F), // Turquoise highlight
              onPrimary: Colors.white, // Text on highlight
              surface: Colors.black, // Calendar cells surface
              onSurface: Colors.white, // Text color for unselected items
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white, // Buttons like OK / CANCEL
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
        filteredCalls = _filterByDateRange(
          allCalls,
          picked.start,
          picked.end,
        );
      });

      print('filteredCalls count: ${filteredCalls}'); // Debug log
    }
  }

    @override
    Widget build(BuildContext context) {
      // ✅ Grouping logic by state
      Map<String, Map<String, dynamic>> stateSummary = {};

      for (var call in filteredCalls) {
        // Enhanced state detection
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
          stateSummary[state] = {
            'Active': 0,
            'Productive': 0,
            'Amount': 0.0,
          };
        }

        if (status == 'Active') {
          stateSummary[state]!['Active']++;
        } 
        else if (status == 'Productive')
        {
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
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
          0: FlexColumnWidth(2),   // State
          1: FlexColumnWidth(1),   // Active
          2: FlexColumnWidth(1),   // Productive
          3: FlexColumnWidth(1),   // Total Calls
          4: FlexColumnWidth(1.5), // Amount
        },
        children: [
          // ---------------- HEADER ROW ----------------
          const TableRow(
            decoration: BoxDecoration(color: Color(0xFF1AA48F)),
            children: [
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Text("State",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    )),
              ),
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Text("Active",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    )),
              ),
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Text("Productive",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    )),
              ),
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Text("Total Calls",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    )),
              ),
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Text("Amount (₹)",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ],
          ),

          // ---------------- DATA ROWS ----------------
          ...stateSummary.entries.toList().asMap().entries.map((entry) {
            final index = entry.key;
            final state = entry.value.key;
            final stats = entry.value.value;

            int active = stats['Active'] ?? 0;
            int prod = stats['Productive'] ?? 0;
            int total = active + prod;

            return TableRow(
              decoration: BoxDecoration(
                color: index.isEven ? Colors.grey.shade900 : Colors.grey.shade800,
              ),
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => admin_Statewise(id: state),
                      ),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Text(
                      state,
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Text(
                    active.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orangeAccent),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Text(
                    prod.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color(0xFF1AA48F), fontWeight: FontWeight.bold),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Text(
                    total.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Text(
                    stats['Amount'].toStringAsFixed(2),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.yellowAccent,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          }),

          // ---------------- TOTAL ROW (BOTTOM) ----------------
          TableRow(
            decoration: BoxDecoration(color: const Color.fromARGB(221, 129, 131, 47)),
            children: [
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Text(
                  "TOTAL",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),

              // TOTAL ACTIVE
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Text(
                  stateSummary.values
                      .fold<int>(0, (sum, v) => sum + ((v['Active'] ?? 0) as num).toInt())
                      .toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                ),
              ),

              // TOTAL PRODUCTIVE
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Text(
                  stateSummary.values
                      .fold<int>(0, (sum, v) => sum + ((v['Productive'] ?? 0) as num).toInt())
                      .toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF1AA48F), fontWeight: FontWeight.bold),
                ),
              ),

              // TOTAL CALLS
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Text(
                  stateSummary.values
                      .fold<int>(
                        0,
                        (sum, v) => sum + ((((v['Productive'] ?? 0) as num) + ((v['Active'] ?? 0) as num)).toInt()),
                      )
                      .toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),

              // TOTAL AMOUNT
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Text(
                  stateSummary.values
                      .fold<double>(0.0, (sum, v) => sum + (v['Amount'] ?? 0))
                      .toStringAsFixed(2),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.yellowAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  )

                    ],
                  ),
      );
    }
  }
