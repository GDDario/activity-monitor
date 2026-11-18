import 'package:flutter/widgets.dart';
import 'package:app/domain/models/local_profile.dart';

class ProfileLocalizations {
  const ProfileLocalizations(this.locale);
  final Locale locale;
  bool get pt => locale.languageCode == 'pt';
  static ProfileLocalizations of(BuildContext context) =>
      ProfileLocalizations(Localizations.localeOf(context));
  String text(String key) => (pt ? _pt : _en)[key] ?? _en[key] ?? key;
  String appearance(ProfileAppearance a) => text(a.name);
  String language(ProfileLanguage l) => switch (l) {
    ProfileLanguage.device => text('device'),
    ProfileLanguage.enUs => 'English (United States)',
    ProfileLanguage.ptBr => 'Português (Brasil)',
  };
  String avatarFailure(AvatarFailure f) => text(f.name);
  static const _en = {
    'profile': 'Profile',
    'phrase': 'Make this space yours',
    'setup': 'Welcome to your rhythm',
    'setupBody': 'Choose a name for your local profile. Everything stays on this device.',
    'identity': 'Your identity',
    'name': 'Display name',
    'nameError': 'Enter a name with 1–100 characters.',
    'avatar': 'Profile avatar',
    'choosePhoto': 'Change photo',
    'removePhoto': 'Use initials',
    'appearance': 'Appearance',
    'system': 'Follow system',
    'light': 'Light',
    'dark': 'Dark',
    'language': 'Language',
    'device': 'Follow device',
    'save': 'Save profile',
    'continue': 'Save and continue',
    'cancel': 'Cancel',
    'edit': 'Edit profile',
    'saved': 'Profile saved',
    'close': 'Close',
    'retry': 'Retry',
    'unavailable': 'Your profile is unavailable. Please try again.',
    'savingError': 'Could not save your profile. Your changes are still here.',
    'stale': 'This profile changed. Reload the latest version before saving.',
    'reload': 'Reload profile',
    'discard': 'Discard changes?',
    'discardBody': 'Your unsaved profile changes will be lost.',
    'keep': 'Keep editing',
    'discardAction': 'Discard',
    'unsupportedPlatform': 'Photo selection is unavailable on this platform. You can use initials.',
    'selectionUnavailable': 'Could not select this photo. Please try again.',
    'unsupportedFormat': 'Choose a JPEG or PNG photo.',
    'invalidImage': 'This photo could not be read. Choose another image.',
    'tooLarge': 'Choose a photo no larger than 5 MiB.',
    'photoHint': 'JPEG or PNG, up to 5 MiB.',
    'openProfile': 'Open profile for',
  };
  static const _pt = {
    'profile': 'Perfil',
    'phrase': 'Um espaço com a sua identidade',
    'setup': 'Boas-vindas ao seu ritmo',
    'setupBody':
        'Escolha um nome para seu perfil local. Tudo fica neste dispositivo.',
    'identity': 'Sua identidade',
    'name': 'Nome de exibição',
    'nameError': 'Informe um nome com 1–100 caracteres.',
    'avatar': 'Avatar do perfil',
    'choosePhoto': 'Alterar foto',
    'removePhoto': 'Usar iniciais',
    'appearance': 'Aparência',
    'system': 'Seguir o sistema',
    'light': 'Clara',
    'dark': 'Escura',
    'language': 'Idioma',
    'device': 'Seguir o dispositivo',
    'save': 'Salvar perfil',
    'continue': 'Salvar e continuar',
    'cancel': 'Cancelar',
    'edit': 'Editar perfil',
    'saved': 'Perfil salvo',
    'close': 'Fechar',
    'retry': 'Tentar novamente',
    'unavailable': 'Seu perfil está indisponível. Tente novamente.',
    'savingError':
        'Não foi possível salvar seu perfil. Suas alterações continuam aqui.',
    'stale':
        'Este perfil foi alterado. Recarregue a versão atual antes de salvar.',
    'reload': 'Recarregar perfil',
    'discard': 'Descartar alterações?',
    'discardBody': 'Suas alterações de perfil não salvas serão perdidas.',
    'keep': 'Continuar editando',
    'discardAction': 'Descartar',
    'unsupportedPlatform': 'A seleção de fotos está indisponível nesta plataforma. Você pode usar iniciais.',
    'selectionUnavailable':
        'Não foi possível selecionar esta foto. Tente novamente.',
    'unsupportedFormat': 'Escolha uma foto JPEG ou PNG.',
    'invalidImage': 'Não foi possível ler esta foto. Escolha outra imagem.',
    'tooLarge': 'Escolha uma foto de até 5 MiB.',
    'photoHint': 'JPEG ou PNG, até 5 MiB.',
    'openProfile': 'Abrir perfil de',
  };
}
