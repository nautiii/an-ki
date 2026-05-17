import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeViewType { list, calendar }

class HomeViewNotifier extends Notifier<HomeViewType> {
  @override
  HomeViewType build() => HomeViewType.list;

  void toggle() {
    state = state == HomeViewType.list ? HomeViewType.calendar : HomeViewType.list;
  }
}

final homeViewProvider = NotifierProvider<HomeViewNotifier, HomeViewType>(
  HomeViewNotifier.new,
);
