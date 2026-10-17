import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(ref.watch(firestoreProvider)),
);

final communityRosterProvider = StreamProvider.autoDispose<List<CommunityPerson>>(
  (ref) => ref.watch(communityRepositoryProvider).watchRoster(),
);

final registeredUsersProvider = StreamProvider.autoDispose<List<RegisteredUser>>(
  (ref) => ref.watch(communityRepositoryProvider).watchRegisteredUsers(),
);
