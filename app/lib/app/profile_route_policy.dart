import 'package:app/ui/profile/view_models/profile_view_model.dart';

class ProfileRoutePolicy {
  String? _returnTo;
  String? redirect(ProfileSessionState session, String path) {
    const destinations = {'/', '/people', '/calendar', '/profile'};
    if (session.status != ProfileStatus.ready) {
      if (path != '/profile') {
        _returnTo ??= destinations.contains(path) ? path : '/';
      }
      return path == '/profile' ? null : '/profile';
    }
    final target = _returnTo;
    _returnTo = null;
    if (path == '/profile' && target != null) return target;
    return null;
  }
}
