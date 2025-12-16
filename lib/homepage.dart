import 'dart:convert';
import 'package:becall2/api.dart';
import 'package:becall2/call_report.dart';
import 'package:becall2/customer_details_view.dart';
import 'package:becall2/dialerpage.dart';
import 'package:becall2/profilepage.dart';
import 'package:becall2/recent_calls_page.dart';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Homepage extends StatefulWidget {
  final int initialIndex;
  const Homepage({super.key, this.initialIndex = 0});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _selectedIndex = 1; // Default tab -> Contacts
  final Map<String, int> _phoneToCustomerId = {};
  List<dynamic> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    _fetchCustomers();
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

  Future<int?> getid() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('id');
  }

  Future<void> _fetchCustomers() async {
    print("Fetching customers...");
    var token = await getToken();
    var id = await getid();

    setState(() => _loading = true);
    try {
      var response = await http.get(
        Uri.parse("$api/api/contact/info/staff/$id/"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        setState(() {
          _customers = List<dynamic>.from(jsonDecode(response.body));
          _loading = false;
        });
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

  // Bottom navigation tap handler
void _onItemTapped(int index) async {
  setState(() => _selectedIndex = index);

  // 🔥 When user comes back to Contacts tab → refresh list
  if (index == 1) {
    await _fetchCustomers();
  }
}

  // --- Build Page Body ---
  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const RecentCallsPage(),
      _buildContactsPage(),
      const DialerPage(),
      const CallReport(),
      const SettingsPage(),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color.fromARGB(255, 26, 164, 143),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Calls'),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.dialpad), label: 'Keypad'),
          BottomNavigationBarItem(
            icon: Icon(Icons.insert_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // --- Contacts Page ---
  Widget _buildContactsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Contacts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(30),
            ),
            child: const TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                icon: Icon(Icons.search, color: Colors.grey),
                hintText: 'Search',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child:
              _loading
                  ? const Center(
                    child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 26, 164, 143),
                    ),
                  )
                  : _customers.isEmpty
                  ? const Center(
                    child: Text(
                      'No contacts found.',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                  : ListView.builder(
                    itemCount: _customers.length,
                    itemBuilder: (context, index) {
                      final customer = _customers[index];
                      final firstName = customer['first_name'] ?? '';
                      final lastName = customer['last_name'] ?? '';
                      final name = (firstName + ' ' + lastName).trim();
                      final phone = customer['phone'] ?? 'N/A';
                      final stateName = customer['state_name'] ?? 'N/A';

                      return Column(
                        children: [
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.white,
                              child: Icon(Icons.person, color: Colors.black),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    name.isNotEmpty ? name : 'Unknown',
                                    style: const TextStyle(color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.info_outline,
                                    color: Color.fromARGB(255, 26, 164, 143),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => CustomerDetailsView(
                                              id: customer['id'],
                                              customerName: name,
                                              phoneNumber: phone,
                                              date: DateTime.now(),
                                              stateName: stateName,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            subtitle: Text(
                              phone,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => CustomerDetailsView(
                                        id: customer['id'],
                                        customerName: name,
                                        phoneNumber: phone,
                                        date: DateTime.now(),
                                        stateName: stateName,
                                      ),
                                ),
                              );
                            },
                          ),
                          const Divider(
                            color: Colors.white24,
                            thickness: 0.7,
                            indent: 16,
                            endIndent: 16,
                          ),
                        ],
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
