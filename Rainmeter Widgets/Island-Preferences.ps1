$extraDefaults=@{size='Normal';mode='Dark';accent='System';sound=$true;PrayerSound=$true;CalendarSound=$true;FocusSound=$true;PrayerTone='Bell';CalendarTone='Chime';FocusTone='Drop';prayerLead=10;prayerEndLead=0;breakMinutes=5;playerBars=$true;playerArt=$true}
try{$savedExtras=if(Test-Path -LiteralPath $script:islandSettingsPath){[IO.File]::ReadAllText($script:islandSettingsPath)|ConvertFrom-Json}else{$null}}catch{$savedExtras=$null}
foreach($key in $extraDefaults.Keys){$value=$extraDefaults[$key];$property=if($savedExtras){$savedExtras.PSObject.Properties[$key]}else{$null};if($property){$candidate=$property.Value;if($value -is [bool] -and $candidate -is [bool]){$value=$candidate}elseif($value -is [int] -and $candidate -ge 0 -and $candidate -le 1440){$value=[int]$candidate}elseif($value -is [string] -and $candidate -in @('Small','Normal','Big','Dark','Light','System','Gray','Blue','Purple','Rose','Amber','Bell','Chime','Drop','iOS Tri-tone')){$value=[string]$candidate}};$script:islandSettings[$key]=$value}
function Apply-IslandPreferences {
  Save-IslandSettings;Set-IslandSize;$script:nextAccentRead=$null;$script:accentKey=$null;Update-SystemAccent;$script:nextThemeApply=$null;Update-IslandTheme
}
function Add-SettingsChoice($page,[string]$label,[string]$key,$choices,[string]$detail=''){
  $picker=New-Object Windows.Controls.ComboBox;$picker.MinWidth=130;$picker.Height=28;$picker.Tag=$key
  foreach($choice in $choices){[void]$picker.Items.Add([string]$choice)};$picker.SelectedItem=[string]$script:islandSettings[$key]
  $picker.Add_SelectionChanged({param($sender,$eventArgs) if($sender.SelectedItem){$script:islandSettings[[string]$sender.Tag]=[string]$sender.SelectedItem;Apply-IslandPreferences}})
  Add-SettingsRow $page $label $detail $picker;$page.Children[$page.Children.Count-1].ColumnDefinitions[1].Width=[Windows.GridLength]::new(140)
}
function Add-SettingsMinutes($page,[string]$label,[string]$key,[bool]$allowOff=$false){
  $picker=New-Object Windows.Controls.ComboBox;$script:settingsWindow.RegisterName(('Minutes_'+$key),$picker);$picker.Width=130;$picker.Height=28;$picker.IsEditable=$true;$picker.Tag=@{key=$key;off=$allowOff}
  if($allowOff){[void]$picker.Items.Add('Off')};foreach($value in 5,10,15,30,60){[void]$picker.Items.Add([string]$value)}
  $picker.Text=if($allowOff -and $script:islandSettings[$key] -eq 0){'Off'}else{[string]$script:islandSettings[$key]}
  $picker.Add_SelectionChanged({param($sender,$eventArgs) if($sender.SelectedItem){Set-SettingsMinutes $sender ([string]$sender.SelectedItem)}})
  $picker.Add_LostKeyboardFocus({param($sender,$eventArgs) Set-SettingsMinutes $sender $sender.Text})
  $picker.Add_PreviewKeyDown({param($sender,$eventArgs) if($eventArgs.Key -eq 'Enter'){Set-SettingsMinutes $sender $sender.Text;$eventArgs.Handled=$true}})
  Add-SettingsRow $page $label '' $picker;$page.Children[$page.Children.Count-1].ColumnDefinitions[1].Width=[Windows.GridLength]::new(140)
}
function Set-SettingsMinutes($picker,[string]$text){
  $value=0;$valid=($picker.Tag.off -and $text -eq 'Off') -or ([int]::TryParse($text,[ref]$value) -and $value -ge 1 -and $value -le 1440)
  if($valid){$script:islandSettings[$picker.Tag.key]=$value;Save-IslandSettings;Update-SettingsSoundAvailability;$picker.BorderBrush=[Windows.Media.Brushes]::Gray}else{$picker.BorderBrush=[Windows.Media.Brushes]::IndianRed}
}
function Add-PanelSoundSettings($page,[string]$panel){
  Add-SettingsSwitch $page ('Settings'+$panel+'Sound') ($panel+'Sound') 'Play sound' ''
  Add-SettingsChoice $page 'Tone' ($panel+'Tone') @('Bell','Chime','Drop','iOS Tri-tone')
  $toneControl=$page.Children[$page.Children.Count-1].Children[1]
  $preview=New-Object Windows.Controls.Button;$preview.Content='Preview';$preview.HorizontalAlignment='Left';$preview.Tag=$panel;$preview.Margin='0,0,0,12';$preview.Add_Click({param($sender,$eventArgs) Play-IslandSound ([string]$sender.Tag) -Preview});[void]$page.Children.Add($preview)
  $script:settingsSoundControls[$panel]=@{sound=$script:settingsWindow.FindName('Settings'+$panel+'Sound');tone=$toneControl;preview=$preview}
}
function Add-CalendarConnection($page){
  $title=New-Object Windows.Controls.TextBlock;$title.Text='Connect Google Calendar';$title.FontSize=14;$title.Margin='0,0,0,8';[void]$page.Children.Add($title)
  $help=New-Object Windows.Controls.TextBlock;$help.Text='Google Calendar → Settings → Integrate calendar → Secret iCal address.';$help.TextWrapping='Wrap';$help.FontSize=11;$help.Foreground=[Windows.Media.Brushes]::Gray;$help.Margin='0,0,0,10';[void]$page.Children.Add($help)
  $input=New-Object Windows.Controls.TextBox;$input.Height=30;$input.Padding='8,4';$script:settingsWindow.RegisterName('CalendarLink',$input);[void]$page.Children.Add($input)
  $row=New-Object Windows.Controls.StackPanel;$row.Orientation='Horizontal';$row.Margin='0,7,0,8'
  foreach($action in 'Connect','Disconnect'){$button=New-Object Windows.Controls.Button;$button.Content=$action;$button.Tag=$action;$button.Margin='0,0,8,0';$button.Add_Click({param($sender,$eventArgs) Start-CalendarConnection ([string]$sender.Tag)});[void]$row.Children.Add($button)};[void]$page.Children.Add($row)
  $status=New-Object Windows.Controls.TextBlock;$status.Text=if(Test-Path (Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\calendar-source.json')){'Calendar connected'}else{'No calendar connected'};$status.FontSize=11;$status.Foreground=[Windows.Media.Brushes]::Gray;$status.Margin='0,0,0,18';$script:settingsWindow.RegisterName('CalendarConnectionStatus',$status);[void]$page.Children.Add($status)
}
function Start-CalendarConnection([string]$action){
  if($script:calendarConnectProcess -and -not $script:calendarConnectProcess.HasExited){return}
  $status=$script:settingsWindow.FindName('CalendarConnectionStatus')
  $address=if($action -eq 'Disconnect'){$null}else{$script:settingsWindow.FindName('CalendarLink').Text.Trim()}
  if($action -eq 'Connect' -and -not $address){$status.Text='Paste your Google Calendar iCal link first.';return}
  try{
    $info=New-Object Diagnostics.ProcessStartInfo;$info.FileName=(Get-Command node -ErrorAction Stop).Source;$info.Arguments='"'+(Join-Path $PSScriptRoot 'Calendar-Connect.js')+'"';$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardInput=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $script:calendarConnectProcess=[Diagnostics.Process]::Start($info);$script:calendarConnectProcess.StandardInput.WriteLine((@{address=$address}|ConvertTo-Json -Compress));$script:calendarConnectProcess.StandardInput.Close();$status.Text=if($action -eq 'Disconnect'){'Disconnecting…'}else{'Connecting…'};$script:calendarConnectAction=$action
  }catch{$status.Text='Could not start calendar connection.'}
}
function Update-CalendarConnection {
  if($script:calendarConnectProcess -and $script:calendarConnectProcess.HasExited){
    $ok=$script:calendarConnectProcess.ExitCode -eq 0
    if($script:settingsWindow -and $script:settingsWindow.IsVisible){$script:settingsWindow.FindName('CalendarConnectionStatus').Text=if($ok){if($script:calendarConnectAction -eq 'Disconnect'){'Calendar disconnected'}else{'Calendar connected'}}else{'Could not connect. Check the iCal link and your connection.'};if($ok){$script:settingsWindow.FindName('CalendarLink').Clear()}}
    $script:calendarConnectProcess.Dispose();$script:calendarConnectProcess=$null;$script:calendarNextRead=$null;Update-CalendarView -Force
  }
}
function Add-ExtendedSettings {
  $script:settingsSoundControls=@{}
  $settings=$script:settingsWindow
  Add-SettingsChoice $settings.FindName('GeneralPage') 'Mode' 'mode' @('Dark','Light')
  Add-SettingsChoice $settings.FindName('GeneralPage') 'Island size' 'size' @('Small','Normal','Big')
  Add-SettingsChoice $settings.FindName('GeneralPage') 'Secondary color' 'accent' @('System','Gray','Blue','Purple','Rose','Amber')
  Add-SettingsSwitch $settings.FindName('GeneralPage') 'SettingsSound' 'sound' 'Notification sounds' 'Sound can also be turned off for each panel.'
  $general=$settings.FindName('GeneralPage');$appearanceRows=@($general.Children | Select-Object -Last 4);$index=0;foreach($row in $appearanceRows){$general.Children.Remove($row);$general.Children.Insert($index,$row);$index++}
  Add-SettingsMinutes $settings.FindName('PrayerPage') 'Before the next prayer' 'prayerLead' $true
  Add-SettingsMinutes $settings.FindName('PrayerPage') 'Before the current prayer ends' 'prayerEndLead' $true
  Add-PanelSoundSettings $settings.FindName('PrayerPage') 'Prayer'
  Add-SettingsSwitch $settings.FindName('PlayerPage') 'SettingsPlayerBars' 'playerBars' 'Audio animation' 'React to the sound currently playing.'
  Add-SettingsSwitch $settings.FindName('PlayerPage') 'SettingsPlayerArt' 'playerArt' 'Album artwork' 'Show centered artwork in the player.'
  Add-SettingsMinutes $settings.FindName('CalendarPage') 'Remind me before' 'calendarLead'
  $calendarPage=$settings.FindName('CalendarPage');$connectionStart=$calendarPage.Children.Count;Add-CalendarConnection $calendarPage;$connectionRows=@($calendarPage.Children | Select-Object -Skip $connectionStart);$index=0;foreach($row in $connectionRows){$calendarPage.Children.Remove($row);$calendarPage.Children.Insert($index,$row);$index++};Add-PanelSoundSettings $settings.FindName('CalendarPage') 'Calendar'
  Add-SettingsMinutes $settings.FindName('FocusPage') 'Break duration' 'breakMinutes'
  Add-PanelSoundSettings $settings.FindName('FocusPage') 'Focus'
  Update-SettingsSoundAvailability
}
function New-IslandPin([bool]$pinned){
  $fill=if($pinned){'#EEEEEE'}else{'Transparent'};$stroke=if($pinned){'#EEEEEE'}else{'#888888'};$glint=if($pinned){'Black'}else{'#888888'}
  [xml]$markup="<Viewbox xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Width='17' Height='22'><Canvas Width='24' Height='28'><Line X1='12' Y1='15' X2='12' Y2='26' Stroke='$stroke' StrokeThickness='1.8' StrokeEndLineCap='Round'/><Ellipse Canvas.Left='5' Canvas.Top='1' Width='14' Height='14' Stroke='$stroke' Fill='$fill' StrokeThickness='1.8'/><Path Stroke='$glint' StrokeThickness='1.8' StrokeStartLineCap='Round' Data='M 9,6 Q 9,4 11,4'/></Canvas></Viewbox>"
  return [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $markup))
}

function Get-IslandScale {switch($script:islandSettings.size){'Small'{return .88};'Big'{return 1.15};default{return 1.0}}}
function Set-IslandSize {
  $scale=Get-IslandScale
  if($script:appliedIslandScale -ne $scale){$window.Content.LayoutTransform=[Windows.Media.ScaleTransform]::new($scale,$scale);$script:appliedIslandScale=$scale}
  $window.Width=480*$scale;$window.Height=330*$scale;$window.Left=([Windows.SystemParameters]::PrimaryScreenWidth-$window.Width)/2
}

function Update-SettingsSoundAvailability {
  if(-not $script:settingsSoundControls){return}
  foreach($panel in $script:settingsSoundControls.Keys){
    $notifications= switch($panel){'Prayer'{($script:islandSettings.prayerLead -gt 0 -or $script:islandSettings.prayerEndLead -gt 0)};'Calendar'{[bool]$script:islandSettings.calendar};'Focus'{[bool]$script:islandSettings.focusNotice}}
    $controls=$script:settingsSoundControls[$panel]
    $controls.sound.IsEnabled=$notifications -and $script:islandSettings.sound
    $choicesEnabled=$notifications -and $script:islandSettings.sound -and $script:islandSettings[$panel+'Sound']
    foreach($control in $controls.tone,$controls.preview){$control.IsEnabled=$choicesEnabled;$control.Opacity=if($choicesEnabled){1}else{.35}}
    $controls.sound.Opacity=if($controls.sound.IsEnabled){1}else{.35}
  }
}
