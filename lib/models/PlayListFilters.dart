import 'PlayListFilter.dart';

class PlayListFilters {
  final List<PlayListFilter> recommended;
  final List<PlayListCategoryFilters> filters;
  const PlayListFilters({required this.filters, required this.recommended});
  List<PlayListCategoryFilters> get allFilters {
    return [
      PlayListCategoryFilters(name: '推荐', filters: recommended),
      ...filters,
    ];
  }
}

class PlayListCategoryFilters {
  final String name;
  final List<PlayListFilter> filters;
  const PlayListCategoryFilters({required this.name, required this.filters});
}
