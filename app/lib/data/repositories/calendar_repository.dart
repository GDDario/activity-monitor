import 'package:app/data/services/calendar_database.dart';
import 'package:app/domain/models/calendar_data.dart';

class CalendarRepository {
  CalendarRepository(this.service);
  final CalendarDatabase service;

  Future<CalendarData> load() async {
    return service.load();
  }
}
