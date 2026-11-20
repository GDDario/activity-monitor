import 'package:app/data/repositories/tracking_repository.dart';
import 'package:app/data/services/tracking_database.dart';
import 'package:app/domain/models/task_tracking.dart';

class FakeTrackingRepository extends TrackingRepository {
  FakeTrackingRepository() : super(const TrackingDatabase('unused'));
  @override
  Future<List<TaskType>> loadTypes() async => builtinTaskTypes();
}
