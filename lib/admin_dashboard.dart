import 'dart:convert';

import 'package:becall2/admin_datewise_callreport.dart';
import 'package:becall2/admin_statewise_report.dart';
import 'package:becall2/api.dart';
import 'package:becall2/familyuserwisepage.dart';
import 'package:becall2/login_page.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as https;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<dynamic> _customers = [];
  int totalRecords = 0;
  int productiveCount = 0;
  int activeCount = 0;
  double totalAmount = 0.0;
  int productiveCountmonthly = 0;
  int activeCountmonthly = 0;
  double totalAmountmonthly = 0.0;
  List<Map<String, dynamic>> groupedData = [];
  bool isLoading = true;
  List<dynamic> allCalls = [];
  List<dynamic> filteredCalls = [];

  DateTime? startDate;
  DateTime? endDate;

  String? _username;
  List<dynamic> familyWiseData = [];

  @override
  void initState() {
    super.initState();
    _fetchUser();
    _loadUserName();
    _fetchDashboardSummary();
    fetchCallReports();
    fetchCallSummaryByFamily();

    // Fetch today's data
    final today = DateTime.now();
    getDateWise();
  }

  Future<int?> getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var idValue = prefs.get('id');
    if (idValue is int) return idValue;
    if (idValue is String) {
      return int.tryParse(idValue);
    }
    return null;
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  String formatDurationSmart(int totalSeconds) {
    if (totalSeconds <= 0) return "0 sec";

    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    final List<String> parts = [];

    if (hours > 0) {
      parts.add("$hours h");
    }

    if (minutes > 0) {
      parts.add("$minutes m");
    }

    // Show seconds only if:
    // - less than 1 min
    // - OR hours exist
    // - OR minutes < 60 and seconds > 0
    if (seconds > 0 && (hours > 0 || minutes > 0 || totalSeconds < 60)) {
      parts.add("$seconds s");
    }

    return parts.join(" ");
  }

  Future<void> _loadUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'Admin';
    });
  }

  int parseDuration(String duration) {
    int totalSeconds = 0;
    final minMatch = RegExp(r'(\d+)\s*min').firstMatch(duration);
    final secMatch = RegExp(r'(\d+)\s*sec').firstMatch(duration);
    if (minMatch != null) totalSeconds += int.parse(minMatch.group(1)!) * 60;
    if (secMatch != null) totalSeconds += int.parse(secMatch.group(1)!);
    return totalSeconds;
  }

  Future<void> getDateWise() async {
    setState(() {
      isLoading = true;
    });

    var token = await getToken();

    DateTime today = DateTime.now();
    String todayStr = DateFormat('yyyy-MM-dd').format(today);

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

        // filter today only
        List<dynamic> data = allData.where((call) {
          if (call['date'] == null &&
              call['created'] == null &&
              call['call_datetime'] == null) {
            return false;
          }
          try {
            String dateStr =
                call['date'] ?? call['created'] ?? call['call_datetime'];
            DateTime createdDate = DateTime.parse(dateStr).toLocal();
            String createdStr = DateFormat('yyyy-MM-dd').format(createdDate);
            return createdStr == todayStr;
          } catch (e) {
            return false;
          }
        }).toList();

        Map<String, Map<String, dynamic>> grouped = {};

        for (var call in data) {
          String name = call['created_by_name'] ?? 'Unknown';
          String status = (call['status'] ?? '').toString().toLowerCase();
          String durationStr = call['duration'] ?? '0 sec';
          double amount = (call['amount'] ?? 0).toDouble();

          grouped.putIfAbsent(
            name,
            () => {
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

        // ✅ SORT BY HIGHEST TOTAL DURATION FIRST
        List<Map<String, dynamic>> sortedList =
            grouped.entries.map((e) {
              return {
                'name': e.key,
                'productive_count': e.value['productive_count'],
                'active_count': e.value['active_count'],
                'total_count': e.value['total_count'],
                'productive_duration': e.value['productive_duration'],
                'active_duration': e.value['active_duration'],
                'total_duration': e.value['total_duration'],
                'amount': e.value['amount'],
              };
            }).toList()..sort(
              (a, b) => b['total_duration'].compareTo(a['total_duration']),
            );

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
        DateTime today = DateTime.now();
        String todayStr =
            "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

        // Filter only today’s calls
        List<dynamic> todayCalls = data.where((call) {
          if (call["call_datetime"] == null) return false;
          try {
            DateTime createdDate = DateTime.parse(
              call["call_datetime"],
            ).toLocal();
            String createdStr =
                "${createdDate.year}-${createdDate.month.toString().padLeft(2, '0')}-${createdDate.day.toString().padLeft(2, '0')}";
            return createdStr == todayStr;
          } catch (e) {
            return false;
          }
        }).toList();

        setState(() {
          allCalls = data;
          filteredCalls = todayCalls;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchDashboardSummary() async {
    var token = await getToken();

    try {
      final response = await https.get(
        Uri.parse("$api/api/call/report/summary/"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("response.body: ${response.body}");
      print("response................statusCode: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("data: $data");
        setState(() {
          totalRecords = data['today_summary']['total_records'] ?? 0;

          productiveCount = data['today_summary']['productive_count'] ?? 0;

          totalAmount = (data['today_summary']['total_amount'] ?? 0).toDouble();

          activeCount = data['today_summary']['active_count'] ?? 0;

          productiveCountmonthly =
              data['current_month_summary']['productive_count'] ?? 0;

          totalAmountmonthly =
              (data['current_month_summary']['total_amount'] ?? 0).toDouble();

          activeCountmonthly =
              data['current_month_summary']['active_count'] ?? 0;
        });
      } else {}
    } catch (e) {
      print("Error fetching dashboard summary: $e");
    }
  }

  Future<void> _fetchUser() async {
    var token = await getToken();
    var userId = await getUserId();
    if (userId == null) {
      return;
    }

    try {
      var response = await https.get(
        Uri.parse("$api/api/users/$userId/"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _customers = [jsonDecode(response.body)];
        });
      } else {}
    } catch (e) {}
  }

  Future<void> fetchCallSummaryByFamily() async {
    try {
      var token = await getToken();
      final url = Uri.parse("$api/api/call/reports/family-wise-call/report/");

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("Family-wise response.statusCode: ${response.statusCode}");
      print("Family-wise response.body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final List<dynamic> data = jsonResponse['data'] ?? [];

        setState(() {
          familyWiseData = data;
        });
      }
    } catch (e) {
      print("Family-wise error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Colors.black;

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
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 26, 164, 143),
        elevation: 4,
        shadowColor: const Color.fromARGB(255, 26, 164, 143).withOpacity(0.4),
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: const Text(
          'BE CALL',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onSelected: (String value) async {
                if (value == 'logout') {
                  // ✅ Logout logic (no confirmation)
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('token');
                  await prefs.remove('role');

                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  }
                } else if (value == 'Survay Questions') {
                  Navigator.pushNamed(context, '/add_questions');
                } else if (value == 'Survay Report') {
                  Navigator.pushNamed(context, '/survay_report');
                } else if (value == 'product Report') {
                  Navigator.pushNamed(context, '/product_report_view');
                } else if (value == 'profile') {
                  // Example: open profile page
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.teal),
                      SizedBox(width: 8),
                      Text('Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Survay Questions',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.teal),
                      SizedBox(width: 8),
                      Text('Survay Questions'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Survay Report',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.teal),
                      SizedBox(width: 8),
                      Text('Survay Report'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'product Report',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.teal),
                      SizedBox(width: 8),
                      Text('product Report'),
                    ],
                  ),
                ),

                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            // Text(
            //   "Welcome back, ${_username ?? 'Admin'} 👋",
            //   style: const TextStyle(
            //     color: Colors.white,
            //     fontSize: 15,
            //     fontWeight: FontWeight.bold,
            //   ),
            // ),
            const SizedBox(height: 20),
            _buildSectionTitle(
              "Today's Summary - ${DateFormat('dd MMM yyyy').format(DateTime.now())}",
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoCard(Icons.people, "Active calls", "$activeCount"),
                _buildInfoCard(
                  Icons.receipt_long_rounded,
                  "Invoices",
                  "$productiveCount",
                ),
                _buildInfoCard(Icons.currency_rupee, "Amount", "$totalAmount"),
              ],
            ),
            const SizedBox(height: 15),
            _buildSectionTitle(
              "Monthly Summary - ${DateFormat('MMMM yyyy').format(DateTime.now())}",
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoCard(
                  Icons.people,
                  "Active calls",
                  "$activeCountmonthly",
                ),
                _buildInfoCard(
                  Icons.receipt_long_rounded,
                  "Invoices",
                  "$productiveCountmonthly",
                ),
                _buildInfoCard(
                  Icons.currency_rupee,
                  "Amount",
                  "$totalAmountmonthly",
                ),
              ],
            ),

            const SizedBox(height: 30),
            // 🟢 STAFF PERFORMANCE OVERVIEW
            _buildSectionTitle("Staff Performance (Top 3)"),
            const SizedBox(height: 10),
            SingleChildScrollView(
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
                      inside: const BorderSide(
                        color: Colors.white24,
                        width: 0.5,
                      ),
                      outside: const BorderSide(
                        color: Colors.white24,
                        width: 1,
                      ),
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
                      /// ---------------- HEADER ----------------
                      const TableRow(
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 26, 164, 143),
                        ),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Staff",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Productive",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Active",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Total",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Productive Duration",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Active Duration",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Total Duration",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Amount",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),

                      /// ---------------- BODY: Only Top 3 ----------------
                      ...(() {
                        final top3 = groupedData.take(3).toList();

                        return top3.map((item) {
                          String formatDuration(int sec) =>
                              formatDurationSmart(sec);

                          return TableRow(
                            decoration: const BoxDecoration(
                              color: Color(0xFF181818),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  item['name'],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "${item['productive_count']}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "${item['active_count']}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "${item['total_count']}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  formatDuration(item['productive_duration']),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  formatDuration(item['active_duration']),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  formatDuration(item['total_duration']),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "₹${item['amount'].toStringAsFixed(0)}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          );
                        }).toList();
                      })(),

                      /// ---------------- SEE MORE ROW ----------------
                      TableRow(
                        decoration: const BoxDecoration(
                          color: Color(0xFF151515),
                        ),
                        children: [
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                          TableCell(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const admin_CallreportDateWise(),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Center(
                                  child: Text(
                                    "See More →",
                                    style: TextStyle(
                                      color: const Color.fromARGB(
                                        255,
                                        26,
                                        164,
                                        143,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),
            _buildSectionTitle("Family Wise Summary"),
            const SizedBox(height: 10),

            Column(
              children: familyWiseData.map((item) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FamilyUserWisePage(
                          familyId: item['created_by__family__id'],
                          familyName: item['created_by__family__name'],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101010),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// 🔹 FAMILY NAME ROW (UNCHANGED)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['created_by__family__name']
                                    .toString()
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 32, 248, 216),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: const Color.fromARGB(255, 26, 164, 143),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        /// 🔹 TABLE GRID (ROWS + COLUMNS)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _familyGridRow(
                                titles: const [
                                  "Productive Calls",
                                  "Active Calls",
                                  "Total Calls",
                                ],
                                values: [
                                  "${item['productive_calls']}",
                                  "${item['active_calls']}",
                                  "${item['total_calls']}",
                                ],
                              ),

                              const Divider(height: 1, color: Colors.white24),

                              _familyGridRow(
                                titles: const [
                                  "Prod Duration",
                                  "Active Duration",
                                  "Total Amount",
                                ],
                                values: [
                                  formatDurationSmart(
                                    item['productive_duration'],
                                  ),
                                  formatDurationSmart(item['active_duration']),
                                  "₹ ${(item['productive_amount'] ?? 0).toStringAsFixed(0)}",
                                ],
                                highlightLast: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: 30),
            // 🟢 STATE WISE SUMMARY
            _buildSectionTitle("State Wise Summary (Top 3)"),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
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
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                },
                children: [
                  // Header Row
                  const TableRow(
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, 26, 164, 143),
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          "State",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          "Productive",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          "Amount",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ✅ Data Rows (Top 3 States by Productive Count)
                  ...(() {
                    // Convert to a list for sorting
                    final entries = stateSummary.entries.toList();

                    // Sort by Productive count descending
                    entries.sort(
                      (a, b) => (b.value['Productive'] as int).compareTo(
                        a.value['Productive'] as int,
                      ),
                    );

                    // Take top 3 states
                    final top3 = entries.take(3).toList();

                    // Map to TableRow widgets
                    return top3.map((entry) {
                      final state = entry.key;
                      final data = entry.value;
                      return TableRow(
                        decoration: const BoxDecoration(
                          color: Color(0xFF181818),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              state,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "${data['Productive']}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "₹${(data['Amount'] as double).toStringAsFixed(0)}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  })(),

                  // ✅ “See More” Row
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFF151515)),
                    children: [
                      const TableCell(child: SizedBox()),
                      const TableCell(child: SizedBox()),
                      TableCell(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const admin_CallreportStatewise(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                "See More →",
                                style: TextStyle(
                                  color: const Color.fromARGB(
                                    255,
                                    26,
                                    164,
                                    143,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Financial Summary
            _buildSectionTitle("Financial Summary"),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(
                      255,
                      26,
                      164,
                      143,
                    ).withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _AccountRow(
                    label: "Total Invoice Amount",
                    amount: "₹${totalAmount.toStringAsFixed(2)}",
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 🔹 Info Card Widget
  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF101010), Color(0xFF1A1A1A)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withOpacity(0.65),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: const Color.fromARGB(255, 26, 164, 143),
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Color.fromARGB(255, 26, 164, 143),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Section Title Widget
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color.fromARGB(255, 32, 248, 216),
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    );
  }
}

// 🔹 Financial Summary Row
class _AccountRow extends StatelessWidget {
  final String label;
  final String amount;

  const _AccountRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        Text(
          amount,
          style: const TextStyle(
            color: Color.fromARGB(255, 26, 164, 143),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

Widget _familyGridRow({
  required List<String> titles,
  required List<String> values,
  bool highlightLast = false,
}) {
  return IntrinsicHeight(
    child: Stack(
      children: [
        // 🔹 VERTICAL DIVIDERS (FULL HEIGHT)
        Positioned.fill(
          child: Row(
            children: [
              Expanded(child: Container()),
              Container(width: 1, color: Colors.white24),
              Expanded(child: Container()),
              Container(width: 1, color: Colors.white24),
              Expanded(child: Container()),
            ],
          ),
        ),

        // 🔹 CONTENT
        Row(
          children: List.generate(3, (index) {
            final bool highlight = highlightLast && index == 2;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      titles[index],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 15, 236, 214),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      values[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: highlight
                            ? const Color.fromARGB(255, 3, 177, 29)
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    ),
  );
}
