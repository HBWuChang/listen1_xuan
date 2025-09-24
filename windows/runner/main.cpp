#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
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

// Global variables for theme monitoring
static FlutterWindow* g_flutter_window = nullptr;
static HWND g_app_hwnd = NULL;
static WNDPROC g_original_wndproc = NULL;

// Custom window procedure for theme monitoring
LRESULT CALLBACK ThemeWindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
  // Monitor for DWM color changes or system setting changes
  if (uMsg == WM_DWMCOLORIZATIONCOLORCHANGED || uMsg == WM_SETTINGCHANGE) {
    OutputDebugStringA("Detected system color/setting change");
    
    // Send theme update message to Dart through platform channel
    if (g_flutter_window) {
      auto* channel = g_flutter_window->GetThemeChannel();
      if (channel) {
        try {
          channel->InvokeMethod("themeChanged", 
            std::make_unique<flutter::EncodableValue>("system_theme_changed"));
          OutputDebugStringA("Sent theme update message to Dart");
        } catch (...) {
          OutputDebugStringA("Failed to send theme update message");
        }
      }
    }
  }
  
  // Call original window procedure
  if (g_original_wndproc) {
    return CallWindowProc(g_original_wndproc, hWnd, uMsg, wParam, lParam);
  }
  return DefWindowProc(hWnd, uMsg, wParam, lParam);
}

// Setup theme monitoring for the application window
void SetupThemeMonitoring(HWND hwnd, FlutterWindow* flutter_window) {
  if (hwnd == NULL) return;
  
  g_app_hwnd = hwnd;
  g_flutter_window = flutter_window;
  
  // Subclass the window to monitor theme changes
  g_original_wndproc = (WNDPROC)SetWindowLongPtr(hwnd, GWLP_WNDPROC, (LONG_PTR)ThemeWindowProc);
  
  if (g_original_wndproc) {
    OutputDebugStringA("Successfully setup Windows theme monitoring");
  } else {
    OutputDebugStringA("Failed to setup Windows theme monitoring");
  }
}

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

  // Setup theme monitoring after window creation
  HWND app_hwnd = window.GetHandle();
  if (app_hwnd) {
    // Setup the theme monitoring with both window handle and flutter window pointer
    SetupThemeMonitoring(app_hwnd, &window);
    OutputDebugStringA("Theme monitoring initialized");
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0))
  {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // Cleanup
  if (g_app_hwnd && g_original_wndproc) {
    SetWindowLongPtr(g_app_hwnd, GWLP_WNDPROC, (LONG_PTR)g_original_wndproc);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
