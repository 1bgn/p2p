//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <file_selector_windows/file_selector_windows.h>
#include <flutter_nsd/flutter_nsd_plugin.h>
#include <nsd_windows/nsd_windows_plugin_c_api.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FileSelectorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorWindows"));
  FlutterNsdPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterNsdPlugin"));
  NsdWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("NsdWindowsPluginCApi"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
}
