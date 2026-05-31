import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';

class BlockedUsersController extends BaseController {
  final AppSettingsController settingsController = Get.find<AppSettingsController>();

  void unblock(String platform, String userName) {
    settingsController.unblockUser(platform, userName);
  }
}
