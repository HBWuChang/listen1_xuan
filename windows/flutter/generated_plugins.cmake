#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  audioplayers_windows
  charset_converter
  connectivity_plus
  hotkey_manager_windows
  media_kit_libs_windows_audio
  permission_handler_windows
  screen_retriever_windows
  tray_manager
  url_launcher_windows
  webview_windows
  window_manager
  windows_taskbar
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  jni
  metadata_god
  smtc_windows
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/windows plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/windows plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)
