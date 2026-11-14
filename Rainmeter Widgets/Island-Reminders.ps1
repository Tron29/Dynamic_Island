function Play-IslandSound([string]$panel,[switch]$Preview){
  if($panel -eq 'Player'){return}
  if(-not $Preview -and (-not $script:islandSettings.sound -or -not $script:islandSettings[$panel+'Sound'])){return}
  $tone=[string]$script:islandSettings[$panel+'Tone'];if($tone -notin @('Bell','Chime','Drop','iOS Tri-tone')){return}
  try{$script:reminderSound=[Media.SoundPlayer]::new((Join-Path $PSScriptRoot ('Sounds\'+$tone+'.wav')));$script:reminderSound.Play()}catch{}
}
$script:themeHistory=New-Object 'System.Runtime.CompilerServices.ConditionalWeakTable[System.Windows.DependencyObject,System.Collections.Hashtable]'
function Set-IslandThemeBrush($node,[string]$property,[bool]$light){
  # Preserve template bindings and inherited colors so selection can update.
  $dependencyProperty=$null
  if($property -eq 'Background'){
    if($node -is [Windows.Controls.Border]){$dependencyProperty=[Windows.Controls.Border]::BackgroundProperty}
    elseif($node -is [Windows.Controls.Panel]){$dependencyProperty=[Windows.Controls.Panel]::BackgroundProperty}
    elseif($node -is [Windows.Controls.Control]){$dependencyProperty=[Windows.Controls.Control]::BackgroundProperty}
  }elseif($property -eq 'Foreground'){
    if($node -is [Windows.Controls.TextBlock]){$dependencyProperty=[Windows.Controls.TextBlock]::ForegroundProperty}
    elseif($node -is [Windows.Controls.Control]){$dependencyProperty=[Windows.Controls.Control]::ForegroundProperty}
  }elseif($node -is [Windows.Shapes.Shape]){$dependencyProperty=if($property -eq 'Fill'){[Windows.Shapes.Shape]::FillProperty}else{[Windows.Shapes.Shape]::StrokeProperty}}
  if($dependencyProperty){$source=[Windows.DependencyPropertyHelper]::GetValueSource($node,$dependencyProperty);if($source.IsExpression -or $source.BaseValueSource -eq [Windows.BaseValueSource]::Inherited){return}}
  if($node -is [Windows.FrameworkElement] -and $node.TemplatedParent -and $property -in @('Background','Foreground')){return}
  $brush=$node.$property
  if($brush -isnot [Windows.Media.SolidColorBrush] -or $brush.Color.A -eq 0){return}
  if([object]::ReferenceEquals($brush,$script:uiPrimary) -or [object]::ReferenceEquals($brush,$script:uiSecondary)){return}
  $record=$script:themeHistory.GetOrCreateValue($node)
  if(-not $record.ContainsKey($property) -or -not [object]::ReferenceEquals($brush,$record[$property].applied)){$record[$property]=@{original=$brush;applied=$null}}
  if([object]::ReferenceEquals($brush,$record[$property].applied) -and $record[$property].light -eq $light){return}
  $original=$record[$property].original;$color=$original.Color;$replacement=$original
  if($light -and [math]::Abs([int]$color.R-[int]$color.G) -lt 10 -and [math]::Abs([int]$color.G-[int]$color.B) -lt 10 -and -not [object]::ReferenceEquals($original,$script:systemAccentBrush)){
    $v=[int]$color.R
    if($property -eq 'Background'){$v=if($v -lt 15){248}elseif($v -lt 90){226}else{205}}
    else{$v=if($v -ge 200){30}elseif($v -ge 90){95}else{150}}
    $replacement=[Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromArgb($color.A,[byte]$v,[byte]$v,[byte]$v));$replacement.Opacity=$original.Opacity
  }
  $node.$property=$replacement;$record[$property].applied=$replacement;$record[$property].light=$light
}
function Walk-IslandTheme($node,[bool]$light){
  if($node -is [Windows.Controls.Image]){return}
  if($node -is [Windows.Controls.Primitives.Popup] -and $node.Child){Walk-IslandTheme $node.Child $light}
  foreach($property in 'Foreground','Background','Stroke','Fill'){if($node.PSObject.Properties[$property]){Set-IslandThemeBrush $node $property $light}}
  for($i=0;$i -lt [Windows.Media.VisualTreeHelper]::GetChildrenCount($node);$i++){Walk-IslandTheme ([Windows.Media.VisualTreeHelper]::GetChild($node,$i)) $light}
}
function Update-IslandTheme {
  if($script:nextThemeApply -and [datetime]::UtcNow -lt $script:nextThemeApply){return};$script:nextThemeApply=[datetime]::UtcNow.AddMilliseconds(500)
  $light=$script:islandSettings.mode -eq 'Light'
  $script:uiPrimary=if($light){[Windows.Media.BrushConverter]::new().ConvertFromString('#202024')}else{[Windows.Media.Brushes]::White}
  $script:uiSecondary=if($light){[Windows.Media.BrushConverter]::new().ConvertFromString('#66666A')}else{[Windows.Media.Brushes]::Gray}
  if(-not $light -and $script:lastAppliedTheme -ne 'Light'){$script:lastAppliedTheme='Dark';return}
  $script:lastAppliedTheme=if($light){'Light'}else{'Dark'}
  Walk-IslandTheme $window $light
  if($script:settingsWindow -and $script:settingsWindow.IsVisible){Walk-IslandTheme $script:settingsWindow $light;$script:settingsWindow.Resources['SystemAccentBrush']=$script:systemAccentBrush}
}
$script:prayerAlertSeen=@{}
$script:prayerAlertFile=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\PrayerReminderHistory.json'
try{if(Test-Path $script:prayerAlertFile){$history=[IO.File]::ReadAllText($script:prayerAlertFile)|ConvertFrom-Json;foreach($property in $history.PSObject.Properties){$script:prayerAlertSeen[$property.Name]=$property.Value}}}catch{}
[xml]$prayerNoticeMarkup=@"
<StackPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Margin="38,20" Visibility="Collapsed" VerticalAlignment="Center"><TextBlock Name="PrayerNoticeTitle" Foreground="White" FontSize="16"/><TextBlock Name="PrayerNoticeDetail" Foreground="#999999" FontSize="12" Margin="0,6,0,0"/></StackPanel>
"@
$script:prayerNotice=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $prayerNoticeMarkup));[void]$Pill.Child.Children.Add($script:prayerNotice)
$script:prayerReminderSourcePath=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\Rainmeter\Skins\SariyerWidgets\@Resources\PrayerReminder.txt'
function Update-PrayerReminder {
  if($script:expanded){return}
  $file=$script:prayerReminderSourcePath
  try{$lines=[IO.File]::ReadAllLines($file)}catch{return}
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  foreach($line in $lines){
    $parts=$line.Split('|');if($parts.Count -ne 3){continue};$at=0L;if(-not [long]::TryParse($parts[2],[ref]$at)){continue}
    $lead=if($parts[0] -eq 'next'){$script:islandSettings.prayerLead}else{$script:islandSettings.prayerEndLead}
    $key=$parts[0]+'|'+$at
    if($lead -le 0 -or $now -lt $at-60*$lead -or $now -ge $at -or $script:prayerAlertSeen.ContainsKey($key)){continue}
    $script:prayerAlertSeen[$key]=$at
    $clean=@{};foreach($entry in $script:prayerAlertSeen.Keys){if([long]$script:prayerAlertSeen[$entry] -gt $now-86400){$clean[$entry]=$script:prayerAlertSeen[$entry]}};$script:prayerAlertSeen=$clean
    $clean|ConvertTo-Json|Set-Content -LiteralPath $script:prayerAlertFile -Encoding UTF8
    $minutes=[int][math]::Ceiling(($at-$now)/60.0)
    $script:prayerNotice.FindName('PrayerNoticeTitle').Text=if($parts[0] -eq 'next'){$parts[1]+' in '+$minutes+' min'}else{$parts[1]+' ends in '+$minutes+' min'}
    $script:prayerNotice.FindName('PrayerNoticeDetail').Text='Prayer reminder'
    $script:notification=$true;$script:view='Prayer';Expand;$script:deadline=[datetime]::Now.AddSeconds(8);Play-IslandSound 'Prayer';break
  }
}
