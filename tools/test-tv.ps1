param([string]$ToolchainRoot = 'D:\KazumiToolchain')

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/use-android.ps1" -ToolchainRoot $ToolchainRoot
$taskProject = Split-Path $PSScriptRoot -Parent
$taskHarness = Join-Path $taskProject '.cache/tv-tests'
# Exercise the actual UI source without ech_http's unrelated Windows C++ hook.
$taskFiles = @(
    'lib/bean/widget/tv_app_support.dart',
    'lib/bean/widget/tv_input_support.dart',
    'lib/bean/widget/tv_menu_support.dart',
    'lib/bean/widget/tv_settings_slider.dart',
    'lib/bean/widget/tv_navigation_rail.dart',
    'lib/bean/widget/tv_scroll_reader.dart',
    'lib/bean/widget/tv_history_row_navigation.dart',
    'lib/bean/widget/tv_rule_row_navigation.dart',
    'lib/bean/widget/tv_scroll_top_on_focus.dart',
    'lib/bean/card/rule_card.dart',
    'lib/pages/plugin_editor/rule_management_widgets.dart',
    'lib/pages/plugin_editor/editor_form_widgets.dart',
    'lib/bean/widget/kazumi_menu.dart',
    'lib/bean/widget/side_panel_transition.dart',
    'lib/services/platform/tv_service.dart',
    'lib/utils/dandan_credentials.dart',
    'lib/pages/player/tv_player_controls.dart',
    'lib/pages/video/video_side_panel.dart',
    'test/tv_player_controls_test.dart',
    'test/tv_side_panel_test.dart',
    'test/tv_input_support_test.dart',
    'test/tv_shortcut_focus_test.dart',
    'test/tv_menu_support_test.dart',
    'test/tv_settings_slider_test.dart',
    'test/tv_navigation_reading_test.dart',
    'test/tv_history_row_navigation_test.dart',
    'test/tv_rule_navigation_test.dart',
    'test/tv_rule_sorting_test.dart'
)
foreach ($taskFile in $taskFiles) {
    $taskDestination = Join-Path $taskHarness $taskFile
    New-Item -ItemType Directory -Force -Path (Split-Path $taskDestination -Parent) | Out-Null
    Copy-Item -LiteralPath (Join-Path $taskProject $taskFile) -Destination $taskDestination
}
Set-Content -LiteralPath (Join-Path $taskHarness 'pubspec.yaml') -Value @'
name: kazumi
environment:
  sdk: '>=3.10.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
'@
Push-Location $taskHarness
try {
    flutter pub get --offline
    if ($LASTEXITCODE -ne 0) { throw 'TV test dependencies failed.' }
    $taskTests = @($taskFiles | Where-Object { $_.StartsWith('test/') })
    flutter test --no-pub --dart-define=KAZUMI_TV=true @taskTests
    if ($LASTEXITCODE -ne 0) { throw 'TV interaction tests failed.' }
} finally {
    Pop-Location
}
