import 'package:get/get.dart';
import 'base_args.dart';

class Ro {
  Ro._();

  static Future<T?>? toArg<T>(BaseArgs args) {
    return Get.toNamed<T>(args.path, arguments: args, id: 1);
  }

  static Future<T?>? offArg<T>(BaseArgs args) {
    return Get.offNamed<T>(args.path, arguments: args, id: 1);
  }
}
