import 'package:flutter/widgets.dart';

class PeopleLocalizations {
  const PeopleLocalizations(this.locale);
  final Locale locale;
  bool get pt => locale.languageCode == 'pt';
  static PeopleLocalizations of(BuildContext context) =>
      PeopleLocalizations(Localizations.localeOf(context));
  String text(String key) => (pt ? _pt : _en)[key] ?? _en[key] ?? key;
  Map<String, String> get categories => {
    for (final key in ['work', 'household', 'creative', 'family'])
      key: text(key),
  };
  String active(int n) => pt
      ? '$n ${n == 1 ? 'tarefa ativa hoje' : 'tarefas ativas hoje'}'
      : '$n active ${n == 1 ? 'task' : 'tasks'} today';
  String range(int page, int total) => total == 0
      ? text('noHistory')
      : '${page * 20 + 1}–${((page + 1) * 20).clamp(0, total)} ${pt ? 'de' : 'of'} $total';
  String date(String date) => pt
      ? '${date.substring(8, 10)}/${date.substring(5, 7)}/${date.substring(0, 4)}'
      : date;
  static const _en = {
    'people': 'People',
    'directory': 'Shared rhythms',
    'new': 'New Person',
    'create': 'Create Person',
    'edit': 'Edit Person',
    'search': 'Search people or roles…',
    'collaborators': 'Collaborators',
    'totalPeople': 'Total people',
    'active': 'Active',
    'activeShared': 'Active shared tasks today',
    'dynamic': 'Work Dynamic · Today',
    'solo': 'Solo',
    'shared': 'Collaborative',
    'noToday': 'No activities today',
    'all': 'All',
    'frequent': 'Frequent collaborators',
    'work': 'Work',
    'household': 'Household',
    'creative': 'Creative',
    'family': 'Family',
    'empty': 'Your companions start here. Add someone to share a rhythm.',
    'noResults': 'No people match your search and filter.',
    'reset': 'Show everyone',
    'noHistory': 'No shared activities yet.',
    'noLast': 'No completed activity together yet',
    'last': 'Last activity with you',
    'retry': 'Retry',
    'unavailable': 'People are unavailable. Please try again.',
    'name': 'Full name',
    'role': 'Role (optional)',
    'categories': 'Category tags',
    'save': 'Save person',
    'cancel': 'Cancel',
    'close': 'Close',
    'invalid':
        'Enter a name (1–100 characters) and a role of at most 100 characters.',
    'stale': 'This person changed. Close and reopen the editor to load the latest version.',
    'history': 'Shared activities',
    'newest': 'Newest first',
    'oldest': 'Oldest first',
    'previous': 'Previous',
    'next': 'Next',
    'discard': 'Discard changes?',
    'discardBody': 'Your unsaved person details will be lost.',
    'keep': 'Keep editing',
    'discardAction': 'Discard',
    'companions': 'Companions',
    'selectPeople': 'Search companions',
    'noPeople': 'Create a person in People to share this task.',
    'taskWide': 'Companions apply to every occurrence of this task, including saved history.',
    'selected': 'Selected companions',
    'reload': 'Reload choices',
  };
  static const _pt = {
    'people': 'Pessoas',
    'directory': 'Ritmos compartilhados',
    'new': 'Nova pessoa',
    'create': 'Criar pessoa',
    'edit': 'Editar pessoa',
    'search': 'Buscar pessoas ou funções…',
    'collaborators': 'Colaboradores',
    'totalPeople': 'Total de pessoas',
    'active': 'Ativas',
    'activeShared': 'Tarefas compartilhadas ativas hoje',
    'dynamic': 'Dinâmica · Hoje',
    'solo': 'Solo',
    'shared': 'Colaborativas',
    'noToday': 'Nenhuma atividade hoje',
    'all': 'Todas',
    'frequent': 'Colaboradores frequentes',
    'work': 'Trabalho',
    'household': 'Casa',
    'creative': 'Criativo',
    'family': 'Família',
    'empty': 'Seus companheiros começam aqui. Adicione alguém para compartilhar um ritmo.',
    'noResults': 'Nenhuma pessoa corresponde à busca e ao filtro.',
    'reset': 'Mostrar todas',
    'noHistory': 'Nenhuma atividade compartilhada ainda.',
    'noLast': 'Nenhuma atividade concluída juntos ainda',
    'last': 'Última atividade com você',
    'retry': 'Tentar novamente',
    'unavailable': 'Pessoas indisponíveis. Tente novamente.',
    'name': 'Nome completo',
    'role': 'Função (opcional)',
    'categories': 'Categorias',
    'save': 'Salvar pessoa',
    'cancel': 'Cancelar',
    'close': 'Fechar',
    'invalid': 'Informe um nome (1–100 caracteres) e uma função com até 100 caracteres.',
    'stale': 'Esta pessoa foi alterada. Feche e reabra o editor para carregar a versão atual.',
    'history': 'Atividades compartilhadas',
    'newest': 'Mais recentes',
    'oldest': 'Mais antigas',
    'previous': 'Anterior',
    'next': 'Próxima',
    'discard': 'Descartar alterações?',
    'discardBody': 'Os dados não salvos desta pessoa serão perdidos.',
    'keep': 'Continuar editando',
    'discardAction': 'Descartar',
    'companions': 'Companheiros',
    'selectPeople': 'Buscar companheiros',
    'noPeople': 'Crie uma pessoa em Pessoas para compartilhar esta tarefa.',
    'taskWide': 'Os companheiros se aplicam a todas as ocorrências desta tarefa, incluindo o histórico salvo.',
    'selected': 'Companheiros selecionados',
    'reload': 'Recarregar opções',
  };
}
