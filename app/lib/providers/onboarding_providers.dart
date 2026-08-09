import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';

final onboardedProvider =
    NotifierProvider<OnboardedController, bool>(OnboardedController.new);

class OnboardedController extends Notifier<bool> {
  @override
  bool build() => ref.watch(profileRepositoryProvider).onboarded;

  Future<void> complete() async {
    await ref.read(profileRepositoryProvider).setOnboarded();
    state = true;
  }
}
