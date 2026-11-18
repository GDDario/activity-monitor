import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/app/dependencies/profile_dependencies.dart';
import 'package:app/domain/models/local_profile.dart';
import 'package:app/ui/profile/profile_localizations.dart';

class ProfileImage extends StatelessWidget {
  const ProfileImage({
    super.key,
    required this.name,
    this.image,
    this.radius = 24,
  });
  final String name;
  final Uint8List? image;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = Text(
      profileInitials(name),
      style: TextStyle(color: colors.onPrimaryContainer),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,
      child: ClipOval(
        child: image == null
            ? initials
            : Image.memory(
                image!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                cacheWidth: (radius * 4).ceil(),
                errorBuilder: (_, _, _) => initials,
              ),
      ),
    );
  }
}

class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(profileSessionProvider);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final p = model.state.profile, l = ProfileLocalizations.of(context);
        return Semantics(
          button: true,
          container: true,
          label: p == null
              ? (l.pt ? 'Iniciais do perfil AM' : 'Profile initials AM')
              : '${l.text('openProfile')} ${p.name.value}',
          child: InkResponse(
            onTap: onTap,
            radius: 28,
            child: ExcludeSemantics(
              child: ProfileImage(name: p?.name.value ?? '', image: p?.avatar),
            ),
          ),
        );
      },
    );
  }
}
