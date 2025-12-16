
import 'package:becall2/add_contact.dart';
import 'package:becall2/add_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';


class ContactsListPage extends StatefulWidget {
  const ContactsListPage({super.key});

  @override
  State<ContactsListPage> createState() => _ContactsListPageState();
}

class _ContactsListPageState extends State<ContactsListPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchCtrl.addListener(_onSearch);
  }

  Future<void> _callDirect(String n) async =>
      FlutterPhoneDirectCaller.callNumber(n);

  Future<void> _loadContacts() async {
    if (await FlutterContacts.requestPermission()) {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      setState(() {
        _allContacts = contacts;
        _filteredContacts = contacts;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredContacts =
          q.isEmpty
              ? _allContacts
              : _allContacts.where((c) {
                final name = c.displayName.toLowerCase();
                final numbers =
                    c.phones.map((p) => p.number).join(' ').toLowerCase();
                return name.contains(q) || numbers.contains(q);
              }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Contacts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            tooltip: 'Add Contact',
            onPressed: () async {
              // Navigate to AddContactFormPage
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => BlocProvider(
                        create: (_) => StatesCubit()..fetchStates(),
                        child: const AddContactFormPage(phoneNumber: '',),
                      ),
                ),
              );
              // After returning, refresh contacts
              if (result != null) _loadContacts();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white10,
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                hintText: 'Search',
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child:
                _loading
                    ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                    : _filteredContacts.isEmpty
                    ? const Center(
                      child: Text(
                        'No contacts found',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                    : ListView.separated(
                      itemCount: _filteredContacts.length,
                      separatorBuilder:
                          (_, __) =>
                              Divider(color: Colors.grey[800], height: 1),
                      itemBuilder: (context, i) {
                        final c = _filteredContacts[i];
                        final phone =
                            c.phones.isNotEmpty
                                ? c.phones.first.number
                                : 'No number';

                        return ListTile(
                          onTap: () {},
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white10,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            c.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            phone,
                            style: const TextStyle(color: Colors.white54),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.call,
                              color: Colors.greenAccent,
                            ),
                            onPressed: () {
                              if (c.phones.isNotEmpty) {
                                _callDirect(c.phones.first.number);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No phone number available'),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
