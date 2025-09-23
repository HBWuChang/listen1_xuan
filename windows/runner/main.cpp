#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <psapi.h>
#include "app_links/app_links_plugin_c_api.h"
#include "flutter_window.h"
#include "utils.h"

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <psapi.h>
#include "app_links/app_links_plugin_c_api.h"
#include "flutter_window.h"
#include "utils.h"

struct FindWindowData
{
  const wchar_t *targetExeName;
  HWND foundHwnd;
};

BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam)
{
  FindWindowData *data = (FindWindowData *)lParam;

  // 移除可见性检查，允许查找所有窗口（包括后台窗口和无最小化图标的窗口）
  // 但排除子窗口，只处理顶级窗口
  if (GetParent(hwnd) != NULL)
  {
    return TRUE; // 跳过子窗口，继续枚举
  }

  DWORD processId;
  GetWindowThreadProcessId(hwnd, &processId);

  HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, processId);
  if (hProcess == NULL)
  {
    return TRUE;
  }

  wchar_t exePath[MAX_PATH];
  if (GetModuleFileNameEx(hProcess, NULL, exePath, MAX_PATH))
  {
    wchar_t *fileName = wcsrchr(exePath, L'\\');
    if (fileName != NULL)
    {
      fileName++; 
    }
    else
    {
      fileName = exePath; 
    }

    if (_wcsicmp(fileName, data->targetExeName) == 0)
    {
      wchar_t className[256];
      if (GetClassName(hwnd, className, 256) > 0 &&
          wcscmp(className, L"FLUTTER_RUNNER_WIN32_WINDOW") == 0)
      {
        data->foundHwnd = hwnd;
        CloseHandle(hProcess);
        return FALSE;
      }
    }
  }

  CloseHandle(hProcess);
  return TRUE;
}

HWND xFindWindow(const wchar_t *exeName)
{
  FindWindowData data;
  data.targetExeName = exeName;
  data.foundHwnd = NULL;

  EnumWindows(EnumWindowsProc, (LPARAM)&data);

  return data.foundHwnd;
}

bool SendAppLinkToInstance()
{
  HWND hwnd = xFindWindow(L"listen1_xuan.exe");

  if (hwnd)
  {
    // Dispatch new link to current window
    SendAppLink(hwnd);
    return true;
  }

  return false;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command)
{
  if (SendAppLinkToInstance())
  {
    return EXIT_SUCCESS;
  }
  HWND hwnd = xFindWindow(L"listen1_xuan.exe");
  if (hwnd != NULL)
  {
    ::ShowWindow(hwnd, SW_NORMAL);
    ::SetForegroundWindow(hwnd);
    return EXIT_FAILURE;
  }
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent())
  {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);

  if (!window.Create(L"listen1_xuan", origin, size))
  {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0))
  {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
