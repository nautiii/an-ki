import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/ideas/data/idea_repository.dart';
import 'package:an_ki/features/ideas/domain/idea.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Idées de l'utilisateur courant, en temps réel ; liste vide hors session.
///
/// Dérivé de [currentUidProvider] : changement de compte ou déconnexion
/// relancent ou coupent l'abonnement sans code d'initialisation.
final ideasProvider = StreamProvider<List<Idea>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(ideaRepositoryProvider).watchIdeas(uid);
});

/// Idées d'une personne (null : idées non rattachées), dérivées de
/// [ideasProvider] par une règle du domaine.
final personIdeasProvider = Provider.autoDispose
    .family<AsyncValue<List<Idea>>, String?>(
      (ref, personId) => ref
          .watch(ideasProvider)
          .whenData((ideas) => ideas.forPerson(personId)),
    );
