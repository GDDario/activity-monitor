import 'package:app/domain/models/person.dart';

String peopleSearchKey(String value) {
  const accents = 'àáâãäåèéêëìíîïòóôõöùúûüçñ';
  const plain = 'aaaaaaeeeeiiiiooooouuuucn';
  final lower = value.trim().toLowerCase();
  return String.fromCharCodes(
    lower.runes.where((r) => r < 0x300 || r > 0x36f).map((r) {
      final index = accents.indexOf(String.fromCharCode(r));
      return index < 0 ? r : plain.codeUnitAt(index);
    }),
  );
}

class BuildPeopleDirectory {
  List<Person> execute(
    PeopleSnapshot snapshot, {
    String query = '',
    String filter = 'all',
    Map<String, String> labels = const {},
  }) {
    final key = peopleSearchKey(query);
    final people = snapshot.people.where((p) {
      final matchesFilter =
          filter == 'all' ||
          (filter == 'frequent'
              ? (snapshot.stats[p.id]?.recent ?? 0) >= 3
              : p.categories.any((c) => c.name == filter));
      return matchesFilter &&
          peopleSearchKey(
            [
              p.name,
              p.role,
              ...p.categories.map((c) => labels[c.name] ?? c.name),
            ].join(' '),
          ).contains(key);
    }).toList();
    people.sort((a, b) {
      final name = peopleSearchKey(a.name).compareTo(peopleSearchKey(b.name));
      return name != 0 ? name : a.id.compareTo(b.id);
    });
    return List.unmodifiable(people);
  }
}
