import 'dart:convert';
import 'package:becall2/api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ---- States ----
abstract class CountriesState {}
class CountriesInitial extends CountriesState {}
class CountriesLoading extends CountriesState {}
class CountriesLoaded extends CountriesState {
  final List<Map<String, dynamic>> countries;
  CountriesLoaded(this.countries);
}
class CountriesError extends CountriesState {
  final String error;
  CountriesError(this.error);
}

class CountriesCubit extends Cubit<CountriesState> {
  CountriesCubit() : super(CountriesInitial());

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> fetchCountries() async {
    emit(CountriesLoading());
    try {
      final token = await _getToken();
      final url = Uri.parse('$api/api/country/codes/');
      final res = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

 
      if (res.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(res.body);
        final List<dynamic> data = jsonResponse['data'] ?? [];

        final countries = data.map<Map<String, dynamic>>((e) => {
          "id": e["id"],
          "name": e["country_code"], // or e["country_name"] if you prefer
        }).toList();

        emit(CountriesLoaded(countries));
      } else {
        emit(CountriesError('Failed: ${res.statusCode}'));
      }
    } catch (e) {
      emit(CountriesError('Error: $e'));
    }
  }
}
