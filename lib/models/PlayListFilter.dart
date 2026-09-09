class PlayListFilter {
  final dynamic id;
  final String name;
  const PlayListFilter({required this.id, required this.name});
  factory PlayListFilter.defaultValues() {
    return PlayListFilter(id: '', name: '全部');
  }
}
