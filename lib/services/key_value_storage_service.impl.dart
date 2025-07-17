import 'package:shared_preferences/shared_preferences.dart';
import 'key_value_storage_service.dart';

class KeyValueStorageServiceImpl extends KeyValueStorageService {

  Future <SharedPreferences>getSharedPreferences() async {
    return await SharedPreferences.getInstance();
  }
  
  @override
  Future<T?> getValue<T>(String key) async {
    final prefs = await getSharedPreferences();
    if (T == String) {
      return prefs.getString(key) as T?;
    } else if (T == int) {
      return prefs.getInt(key) as T?;
    } else if (T == double) {
      return prefs.getDouble(key) as T?;
    } else if (T == bool) {
      return prefs.getBool(key) as T?;
    } else {
      throw Exception('GET not implemented for type ${T.runtimeType}');
    }
  }

  @override
  Future<bool> removeKey(String key) async{
    final prefs = await getSharedPreferences();
    return prefs.remove(key);
  }

  @override
  Future<void> setKeyValue<T>(String key, T value) async {
    final prefs = await getSharedPreferences();
    if (T == String) {
      prefs.setString(key, value as String);
    } else if (T == int) {
      prefs.setInt(key, value as int);
    } else if (T == double) {
      prefs.setDouble(key, value as double);
    } else if (T == bool) {
      prefs.setBool(key, value as bool);
    } else {
      throw Exception('SET not implemented for type ${T.runtimeType}');
    }
  }
}