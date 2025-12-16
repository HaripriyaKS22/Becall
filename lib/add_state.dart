import 'dart:convert';
import 'package:becall2/add_state_cubit.dart';
import 'package:becall2/api.dart';
import 'package:becall2/countries_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StatesCubit extends Cubit<StatesState> {
  StatesCubit() : super(StatesInitial());

  Future<String?> gettokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> fetchStates() async {
    emit(StatesLoading());
    try {
      final token = await gettokenFromPrefs();
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
        final List<dynamic> data = jsonResponse['data'] ?? [];
        emit(StatesLoaded(data));
      } else {
        emit(
          StatesError("Failed to load states. Code: ${response.statusCode}"),
        );
      }
    } catch (e) {
      emit(StatesError("Error: $e"));
    }
  }
}

abstract class StatesState {}

class StatesInitial extends StatesState {}

class StatesLoading extends StatesState {}

class StatesLoaded extends StatesState {
  
  final List<dynamic> states;
  StatesLoaded(this.states);
}

class StatesError extends StatesState {
  final String error;
  StatesError(this.error);
}

/// -------------------- ADD STATE FORM PAGE --------------------
class AddstateFormPage extends StatefulWidget {
  const AddstateFormPage({super.key});

  @override
  State<AddstateFormPage> createState() => _AddstateFormPageState();
}

class _AddstateFormPageState extends State<AddstateFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _stateCtrl = TextEditingController();
  final Color accent = const Color.fromARGB(255, 26, 164, 143);

  int? _selectedCountryId;

  @override
  void initState() {
    super.initState();
    context.read<StatesCubit>().fetchStates(); // load states initially
    context.read<CountriesCubit>().fetchCountries(); // load countries
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Add state'),
        backgroundColor: Colors.black,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: BlocConsumer<AddStateCubit, AddStateState>(
                listener: (context, state) {
                  if (state is AddStateSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: accent,
                      ),
                    );
                    _formKey.currentState?.reset();
                    _stateCtrl.clear();
                    _selectedCountryId = null;
                    context.read<StatesCubit>().fetchStates();
                  } else if (state is AddStateError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.error),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                builder: (context, addState) {
                  return Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        // Country Dropdown
                        BlocBuilder<CountriesCubit, CountriesState>(
                          builder: (context, cState) {
                            if (cState is CountriesLoading) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            } else if (cState is CountriesLoaded) {
                              return DropdownButtonFormField<int>(
                                value: _selectedCountryId,
                                decoration: InputDecoration(
                                  labelText: "Country",
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[900],
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Colors.white,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                dropdownColor: Colors.grey[900],
                                iconEnabledColor: Colors.white,
                                style: const TextStyle(color: Colors.white),
                                items:
                                    cState.countries.map((c) {
                                      return DropdownMenuItem<int>(
                                        value: c['id'],
                                        child: Text(c['name']),
                                      );
                                    }).toList(),
                                onChanged:
                                    (v) =>
                                        setState(() => _selectedCountryId = v),
                                validator:
                                    (v) =>
                                        v == null ? 'Select a country' : null,
                              );
                            } else if (cState is CountriesError) {
                              return Text(
                                'Error: ${cState.error}',
                                style: const TextStyle(color: Colors.red),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),

                        const SizedBox(height: 20),

                        // State name input
                        TextFormField(
                          controller: _stateCtrl,
                          decoration: InputDecoration(
                            labelText: "State Name",
                            labelStyle: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[900],
                          ),
                          validator:
                              (v) => v!.isEmpty ? 'Enter State name' : null,
                          style: const TextStyle(color: Colors.white),
                        ),

                        const SizedBox(height: 28),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed:
                              addState is AddStateLoading
                                  ? null
                                  : () {
                                    if (_formKey.currentState!.validate()) {
                                      context.read<AddStateCubit>().saveState(
                                        _stateCtrl.text,
                                        _selectedCountryId,
                                      );
                                    }
                                  },
                          child:
                              addState is AddStateLoading
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : const Text(
                                    'Save',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                        ),

                        const SizedBox(height: 28),

                        // States list
                        BlocBuilder<StatesCubit, StatesState>(
                          builder: (context, sState) {
                            if (sState is StatesLoading) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            } else if (sState is StatesLoaded) {
                              if (sState.states.isEmpty) {
                                return const Text(
                                  "No states yet",
                                  style: TextStyle(color: Colors.white),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "States:",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...sState.states.map((st) {
                                    final country = st['country'];
                                    final countryName =
                                        country is Map
                                            ? country['name']
                                            : country; // extract name

                                    return Card(
                                      color: Colors.grey[900],
                                      child: ListTile(
                                        title: Text(
                                          st['name'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),

                                        // SHOW SUBTITLE ONLY IF countryName IS NOT NULL AND NOT EMPTY
                                        subtitle:
                                            (countryName != null &&
                                                    countryName
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty)
                                                ? Text(
                                                  "Country: $countryName",
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.7),
                                                  ),
                                                )
                                                : null,
                                      ),
                                    );
                                  }),
                                ],
                              );
                            } else if (sState is StatesError) {
                              return Text(
                                "Error: ${sState.error}",
                                style: const TextStyle(color: Colors.red),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
