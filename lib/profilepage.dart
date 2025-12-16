import 'dart:convert';


import 'package:becall2/add_contact.dart';
import 'package:becall2/add_contry.dart';
import 'package:becall2/add_distric.dart';
import 'package:becall2/add_state.dart';
import 'package:becall2/add_state_cubit.dart';
import 'package:becall2/api.dart';
import 'package:becall2/call_report.dart';
import 'package:becall2/callreport_date_wise.dart';
import 'package:becall2/callreport_statewise.dart';
import 'package:becall2/countries_cubit.dart';
import 'package:becall2/dialerpage.dart';
import 'package:becall2/homepage.dart';
import 'package:becall2/product_wise_manual_report.dart';
import 'package:becall2/survay.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as https;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<dynamic> _customers = [];
  Map<String, dynamic>? _user;
  bool _loading = true;

  int _selectedIndex = 1; // Contacts is default

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    if (index == 2) {
      // Keypad tapped
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DialerPage()),
      );
    } else if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const Homepage()),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const Homepage()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CallReport()),
      );
    } else if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      ); // Reports tapped
      // Navigate to Reports page if implemented
    } else if (index == 4) {
      // Settings tapped
      // Navigate to Settings page if implemented
    }
    // you can add more conditions for other tabs if needed
  }

  @override
  initState() {
    super.initState();
    _fetchUser();
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

  Future<void> _fetchUser() async {
    var token = await getToken();
    if (token == null) return;

    try {
      final response = await https.get(
        Uri.parse("$api/api/profile/"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final jsonBody = jsonDecode(response.body);
        setState(() {
          _user = jsonBody['data']; // ✅ only take the 'data' field
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  // ...existing code...
  Future<void> _updateUserName(int userId, String newName) async {
    var token = await getToken();
    try {
      var response = await https.put(
        Uri.parse("$api/api/users/$userId/"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"name": newName}),
      );
    } catch (e) {}
  }

  String? _editedName;

  void _showEditNameDialog() {
    TextEditingController controller = TextEditingController(
      text: _user?['name'] ?? '',
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('Edit Name', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter new name',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1AA48F),
              ),
              onPressed: () async {
                setState(() {
                  _user?['name'] = controller.text;
                });
                Navigator.pop(context);
                if (_user?['id'] != null) {
                  await _updateUserName(_user!['id'], controller.text);
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                // Profile icon and text
                // Profile icon and text
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color.fromARGB(
                          255,
                          26,
                          164,
                          143,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.black,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ✅ Display user name
                      Text(
                        _user?['name'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      // ✅ Display family name below
                      if (_user?['family_name'] != null)
                        Text(
                          "Family: ${_user!['family_name']}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                      // Edit icon for name
                      // IconButton(
                      //   icon: const Icon(
                      //     Icons.edit,
                      //     color: Colors.white,
                      //     size: 18,
                      //   ),
                      //   onPressed: _showEditNameDialog,
                      //   tooltip: 'Edit Name',
                      // ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Settings List
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _settingsTile(
                        icon: Icons.person_2,
                        label: 'Contacts',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) =>
                                      const AddContactFormPage(phoneNumber: ''),
                            ),
                          );
                        },
                      ),
                      const Divider(color: Colors.black54, height: 1),
                      _settingsTile(
                        icon: Icons.location_city_rounded,
                        label: 'States',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => MultiBlocProvider(
                                    providers: [
                                      BlocProvider(
                                        create: (_) => AddStateCubit(),
                                      ),
                                      BlocProvider(
                                        create: (_) => CountriesCubit(),
                                      ),
                                      BlocProvider(
                                        create: (_) => StatesCubit(),
                                      ),
                                    ],
                                    child: const AddstateFormPage(),
                                  ),
                            ),
                          );
                        },
                      ),

                      const Divider(color: Colors.black54, height: 1),

                      _settingsTile(
                        icon: Icons.location_city_outlined,
                        label: 'District',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddDistric()),
                          );
                        },
                      ),

                      const Divider(color: Colors.black54, height: 1),
                      _settingsTile(
                        icon: Icons.location_city,
                        label: 'Countries',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddContryFormPage(),
                            ),
                          );
                        },
                      ),
                      const Divider(color: Colors.black54, height: 1),

                      _settingsTile(
                        icon: Icons.summarize,
                        label: 'Survey',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const Survay()),
                          );
                        },
                      ),
                      const Divider(color: Colors.black54, height: 1),
                      _settingsTile(
                        icon: Icons.report,
                        label: 'product report',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductWiseManualReport(),
                            ),
                          );
                        },
                      ),

                      const Divider(color: Colors.black54, height: 1),

                      _settingsTile(
                        icon: Icons.report,
                        label: 'datewise Call Report',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CallreportDateWise(),
                            ),
                          );
                        },
                      ),
                      const Divider(color: Colors.black54, height: 1),
                      _settingsTile(
                        icon: Icons.report,
                        label: 'state wise Call Report',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CallreportStatewise(),
                            ),
                          );
                        },
                      ),
                      const Divider(color: Colors.black54, height: 1),

                      // _settingsTile(
                      //   icon: Icons.star,
                      //   label: 'Stared',
                      //   onTap: () {},
                      // ),
                      // const Divider(color: Colors.black54, height: 1),
                      // _settingsTile(
                      //   icon: Icons.favorite,
                      //   label: 'Favourite',
                      //   onTap: () {},
                      // ),
                      const Divider(color: Colors.black54, height: 1),
                      _settingsTile(
                        icon: Icons.folder,
                        label: 'Logout',
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // Bottom navigation bar
      // bottomNavigationBar: BottomNavigationBar(
      //   backgroundColor: Colors.black,
      //   type: BottomNavigationBarType.fixed,
      //   selectedItemColor: const Color.fromARGB(255, 26, 164, 143),
      //   unselectedItemColor: Colors.grey,
      //   currentIndex: _selectedIndex, // highlight Settings
      //          onTap: _onItemTapped,

      //   items: const [
      //     BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Calls'),
      //     BottomNavigationBarItem(icon: Icon(Icons.contacts), label: 'Contacts'),
      //     BottomNavigationBarItem(icon: Icon(Icons.dialpad), label: 'Keypad'),
      //     BottomNavigationBarItem(icon: Icon(Icons.insert_chart), label: 'Reports'),
      //     BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      //   ],
      // ),
    );
  }

  // Reusable list tile with teal icon
  Widget _settingsTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color.fromARGB(255, 26, 164, 143)),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Colors.white,
        size: 16,
      ),
      onTap: onTap,
    );
  }
}
