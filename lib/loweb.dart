import 'bl.dart';
class Provider {
  final String name;
  final dynamic instance;
  final bool searchable;
  final bool supportLogin;
  final String id;
  final bool? hidden;

  Provider({
    required this.name,
    required this.instance,
    required this.searchable,
    required this.supportLogin,
    required this.id,
    this.hidden,
  });
}

final List<Provider> providers = [
  Provider(
    name: 'netease',
    // instance: netease,
    instance: null,
    searchable: true,
    supportLogin: true,
    id: 'ne',
  ),
  Provider(
    name: 'xiami',
    // instance: xiami,
    instance: null,
    searchable: false,
    supportLogin: false,
    id: 'xm',
    hidden: true,
  ),
  Provider(
    name: 'qq',
    // instance: qq,
    instance: null,
    searchable: true,
    supportLogin: true,
    id: 'qq',
  ),
  Provider(
    name: 'kugou',
    // instance: kugou,
    instance: null,
    searchable: true,
    supportLogin: false,
    id: 'kg',
  ),
  Provider(
    name: 'kuwo',
    // instance: kuwo,
    instance: null,
    searchable: true,
    supportLogin: false,
    id: 'kw',
  ),
  Provider(
    name: 'bilibili',
    instance: bilibili,
    searchable: true,
    supportLogin: false,
    id: 'bi',
  ),
  Provider(
    name: 'migu',
    // instance: migu,
    instance: null,
    searchable: true,
    supportLogin: true,
    id: 'mg',
  ),
  Provider(
    name: 'taihe',
    // instance: taihe,
    instance: null,
    searchable: true,
    supportLogin: false,
    id: 'th',
  ),
  Provider(
    name: 'localmusic',
    // instance: localmusic,
    instance: null,
    searchable: false,
    supportLogin: false,
    id: 'lm',
    hidden: true,
  ),
  Provider(
    name: 'myplaylist',
    // instance: myplaylist,
    instance: null,
    searchable: false,
    supportLogin: false,
    id: 'my',
    hidden: true,
  ),
];

Provider? getProviderByName(String sourceName) {
  return providers.firstWhere((i) => i.name == sourceName, orElse: () => Provider(name: '', instance: null, searchable: false, supportLogin: false, id: '')).instance;
}

List<dynamic> getAllProviders() {
  return providers.where((i) => i.hidden != true).map((i) => i.instance).toList();
}

List<dynamic> getAllSearchProviders() {
  return providers.where((i) => i.searchable).map((i) => i.instance).toList();
}

String? getProviderNameByItemId(String itemId) {
  String prefix = itemId.substring(0, 2);
  return providers.firstWhere((i) => i.id == prefix, orElse: () => Provider(name: '', instance: null, searchable: false, supportLogin: false, id: '')).name;
}

dynamic getProviderByItemId(String itemId) {
  String prefix = itemId.substring(0, 2);
  return providers.firstWhere((i) => i.id == prefix, orElse: () => Provider(name: '', instance: null, searchable: false, supportLogin: false, id: '')).instance;
}