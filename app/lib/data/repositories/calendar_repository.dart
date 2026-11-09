import 'package:app/data/services/calendar_database.dart';
import 'package:app/domain/models/calendar_data.dart';
import 'package:app/domain/value_objects/local_date_range.dart';

class CalendarRepository {
  CalendarRepository(this.service);
  final CalendarDatabase service;

  Future<CalendarData> load({LocalDateRange? range}) async {
    return service.load(range: range);
  }
}
