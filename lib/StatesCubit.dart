import 'dart:convert';
import 'package:becall2/api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StatesCubit extends Cubit<StatesState> {
  StatesCubit() : super(StatesInitial());

  Future<String?> gettokenFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
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
        final List<dynamic> data = jsonDecode(response.body);
        emit(StatesLoaded(data));
      } 
      else {
           emit(StatesError("Failed to load states. Code: ${response.statusCode}"));
      }
    } 
    catch (e) 
    {
      emit(StatesError("Error: $e"));
    }
  }
}

// States
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
