Add-Type -Path (Join-Path $PSScriptRoot 'FocusRing.cs') -ReferencedAssemblies PresentationFramework,PresentationCore,WindowsBase,System.Xaml
# Presentation is independent of the persistent UTC countdown.
[xml]$focusMarkup=@'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Margin="38,48,38,18" Visibility="Collapsed" ClipToBounds="True">
<Grid Name="FocusMain"><Grid.RowDefinitions><RowDefinition Height="24"/><RowDefinition Height="*"/></Grid.RowDefinitions>
<Grid Name="FocusNameField" MinWidth="56" MaxWidth="200" Height="24" HorizontalAlignment="Center"><Border CornerRadius="9" Background="{DynamicResource SystemAccentBrush}" Opacity="0.12"/><TextBox Name="FocusName" Text="Focus" TextAlignment="Center" VerticalContentAlignment="Center" Padding="8,0,8,2" FontWeight="Medium"/></Grid><Button Name="FocusReset" Content="↺" HorizontalAlignment="Right" Width="28"/>
<Grid Name="FocusCountdown" Visibility="Collapsed" Grid.Row="1" Width="150" Height="150" HorizontalAlignment="Center"><Grid Name="FocusRingHost"/><Button Name="FocusStart" HorizontalContentAlignment="Center"><StackPanel><TextBlock Name="FocusTime" Text="25:00" FontSize="26" Foreground="White" HorizontalAlignment="Center"/><TextBlock Name="FocusStatus" Text="Click to start" FontSize="10" Foreground="#888888" HorizontalAlignment="Center" Margin="0,4,0,0"/></StackPanel></Button></Grid>
<Grid Name="FocusChoices" Grid.Row="1"><Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="18"/><RowDefinition Height="32"/></Grid.RowDefinitions><Border Grid.Row="0" Margin="0,10,0,12" Background="Transparent"><Grid><Grid.RowDefinitions><RowDefinition/><RowDefinition/></Grid.RowDefinitions><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions><Button Name="Focus5" FontSize="22" FontWeight="Light" Content="5"/><Button Name="Focus15" Grid.Column="1" FontSize="22" FontWeight="Light" Content="15"/><Button Name="Focus30" Grid.Row="1" FontSize="22" FontWeight="Light" Content="30"/><Button Name="Focus60" Grid.Row="1" Grid.Column="1" FontSize="22" FontWeight="Light" Content="60"/></Grid></Border>
<TextBlock Grid.Row="1" Text="Custom" FontSize="11" Foreground="#888888"/>
<Grid Grid.Row="2"><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition Width="30"/></Grid.ColumnDefinitions>
<StackPanel Orientation="Horizontal"><TextBox Name="FocusHours" Text="0" Width="34"/><TextBlock Text=" h" Foreground="#999999" VerticalAlignment="Center"/></StackPanel>
<StackPanel Grid.Column="1" Orientation="Horizontal"><TextBox Name="FocusMinutes" Text="10" Width="34"/><TextBlock Text=" min" Foreground="#999999" VerticalAlignment="Center"/></StackPanel>
<StackPanel Grid.Column="2" Orientation="Horizontal"><TextBox Name="FocusSeconds" Text="0" Width="34"/><TextBlock Text=" s" Foreground="#999999" VerticalAlignment="Center"/></StackPanel><Button Grid.Column="3" Name="FocusCustom" Content="▶"/>
</Grid></Grid></Grid></Grid>
'@
$focusView=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $focusMarkup));[void]$Pill.Child.Children.Add($focusView)
[xml]$focusSmallMarkup=@'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Margin="28,6" Visibility="Collapsed"><Grid.ColumnDefinitions><ColumnDefinition Width="44"/><ColumnDefinition/><ColumnDefinition Width="80"/></Grid.ColumnDefinitions><Grid Name="FocusSmallRingHost" Width="34" Height="34" HorizontalAlignment="Left" VerticalAlignment="Center"/><StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="0,0,8,0"><TextBlock Name="FocusSmallName" FontSize="12" Foreground="White" TextTrimming="CharacterEllipsis"/><Button Name="FocusBreak" Content="Break" FontSize="11" HorizontalAlignment="Left" Height="18" HorizontalContentAlignment="Left"/></StackPanel><TextBlock Name="FocusSmallTime" Grid.Column="2" TextAlignment="Right" Foreground="White" FontSize="13" VerticalAlignment="Center"/></Grid>
'@
$focusHome=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $focusSmallMarkup));[void]$Pill.Child.Children.Add($focusHome)
[xml]$focusNoticeMarkup=@'
<StackPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Margin="38,20" Visibility="Collapsed" VerticalAlignment="Center"><TextBlock Name="FocusDoneTitle" Text="Focus complete" Foreground="White" FontSize="18"/><TextBlock Text="Take a moment to rest." Foreground="#999999" FontSize="12" Margin="0,6,0,0"/></StackPanel>
'@
$focusNotice=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $focusNoticeMarkup));[void]$Pill.Child.Children.Add($focusNotice)
$focusTab=New-Object Windows.Controls.Button;$focusTab.Width=34;$focusTab.Height=28;$focusTab.ToolTip='Focus timer';$focusTab.Template=$template;$focusTab.Cursor=[Windows.Input.Cursors]::Hand
$icon=New-Object Windows.Shapes.Path;$icon.Stroke=$script:uiSecondary;$icon.StrokeThickness=1.7;$icon.Width=18;$icon.Height=20;$icon.Stretch='Uniform';$icon.Data=[Windows.Media.Geometry]::Parse('M 12,3 A 9,9 0 1 0 21,12 M 12,6 L 12,12 L 7,12 M 18,1 A 3,3 0 1 0 18,7 A 3,3 0 1 0 18,1');$focusTab.Content=$icon
[void]$calendarTab.Parent.Children.Add($focusTab);$focusTab.Add_Click({Select-Panel 'Focus' $false})
$script:focusRing=New-Object FocusRing;$script:focusSmallRing=New-Object FocusRing
[void]$focusView.FindName('FocusRingHost').Children.Add($script:focusRing);[void]$focusHome.FindName('FocusSmallRingHost').Children.Add($script:focusSmallRing)
$script:focusBreakRing=New-Object FocusRing;$script:focusBreakRing.Width=130;$script:focusBreakRing.Height=130;$script:focusBreakRing.Visibility='Collapsed';$script:focusBreakRing.IsHitTestVisible=$false
$script:focusSmallBreakRing=New-Object FocusRing;$script:focusSmallBreakRing.Width=23;$script:focusSmallBreakRing.Height=23;$script:focusSmallBreakRing.Visibility='Collapsed';$script:focusSmallBreakRing.IsHitTestVisible=$false
[void]$focusView.FindName('FocusRingHost').Children.Add($script:focusBreakRing);[void]$focusHome.FindName('FocusSmallRingHost').Children.Add($script:focusSmallBreakRing)
$script:focusBreakEnd=$null;$script:focusResumeRunning=$false;$script:focusBreakLength=300
$script:focusFile=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\FocusTimer.json'
$script:focusSeconds=1500.0;$script:focusRemaining=1500.0;$script:focusEnd=$null;$script:focusKind='Focus';$script:focusCustom=600;$script:focusSession=$false;$script:focusName='Focus'
try{if(Test-Path -LiteralPath $script:focusFile){$state=[IO.File]::ReadAllText($script:focusFile)|ConvertFrom-Json;if($state.seconds -ge 1 -and $state.seconds -lt 86400){$script:focusSeconds=[double]$state.seconds;$script:focusRemaining=[double]$state.remaining;$script:focusKind=[string]$state.kind;if($state.name){$script:focusName=[string]$state.name};$script:focusSession=[bool]$state.session;if($state.custom -ge 1 -and $state.custom -lt 86400){$script:focusCustom=[int]$state.custom};if($state.breakLength -ge 60){$script:focusBreakLength=[double]$state.breakLength};if($state.breakEnd){$script:focusBreakEnd=[datetime]::Parse($state.breakEnd).ToUniversalTime();$script:focusResumeRunning=[bool]$state.resumeRunning};if($state.end){$script:focusEnd=[datetime]::Parse($state.end).ToUniversalTime();$script:focusSession=$true}}}}catch{}
function Save-FocusTimer {
  @{breakLength=$script:focusBreakLength;breakEnd=if($script:focusBreakEnd){$script:focusBreakEnd.ToString('o')}else{$null};resumeRunning=$script:focusResumeRunning;name=$script:focusName;seconds=$script:focusSeconds;remaining=$script:focusRemaining;kind=$script:focusKind;session=$script:focusSession;custom=$script:focusCustom;end=if($script:focusEnd){$script:focusEnd.ToString('o')}else{$null}}|ConvertTo-Json|Set-Content -LiteralPath $script:focusFile -Encoding UTF8
}
function Get-HomePanel {if($script:focusSession){return 'Focus'};return $script:defaultPanel}
function Focus-TimeText([double]$value){$s=[int][math]::Ceiling([math]::Max(0,$value));if($s -ge 3600){return ('{0:00}:{1:00}:{2:00}' -f [int][math]::Floor($s/3600),([int][math]::Floor($s/60)%60),($s%60))};return ('{0:00}:{1:00}' -f [int][math]::Floor($s/60),($s%60))}
function Set-IslandTextEditing([bool]$enabled){
  $handle=([Windows.Interop.WindowInteropHelper]::new($window)).Handle
  if($handle -ne [IntPtr]::Zero){[IslandWindowStyle]::TextEntry($handle,$enabled)}
  if($enabled){[void]$window.Activate()}else{[Windows.Input.Keyboard]::ClearFocus()}
}
function Set-FocusDuration([double]$seconds,[string]$kind){$script:focusBreakEnd=$null;$script:focusResumeRunning=$false;$script:focusSeconds=$seconds;$script:focusRemaining=$seconds;$script:focusKind=$kind;$script:focusEnd=$null;$script:focusSession=$false;Save-FocusTimer;Update-FocusTimer}
function Finish-FocusBreak([datetime]$resumeAt){
  $script:focusBreakEnd=$null
  if($script:focusResumeRunning){$script:focusEnd=$resumeAt.AddSeconds($script:focusRemaining)}
  $script:focusResumeRunning=$false;Save-FocusTimer
}
function Start-FocusBreak {
  if($script:focusBreakEnd){Finish-FocusBreak ([datetime]::UtcNow);Update-FocusTimer;return}
  if(-not $script:focusSession){Start-FocusDuration ([math]::Max(1,[int]$script:islandSettings.breakMinutes)*60) 'Break';return}
  $script:focusResumeRunning=[bool]$script:focusEnd
  if($script:focusEnd){$script:focusRemaining=[math]::Max(0.0,($script:focusEnd-[datetime]::UtcNow).TotalSeconds)}
  $script:focusEnd=$null;foreach($ring in $script:focusBreakRing,$script:focusSmallBreakRing){$ring.BeginAnimation([FocusRing]::RatioProperty,$null);$ring.Ratio=1};$script:focusBreakLength=[math]::Max(1,[int]$script:islandSettings.breakMinutes)*60;$script:focusBreakEnd=[datetime]::UtcNow.AddSeconds($script:focusBreakLength);Save-FocusTimer;Update-FocusTimer
}
function Toggle-FocusTimer {
  if($script:focusBreakEnd){Finish-FocusBreak ([datetime]::UtcNow);Update-FocusTimer;return}
  if($script:focusEnd){$script:focusRemaining=[math]::Max(0,($script:focusEnd-[datetime]::UtcNow).TotalSeconds);$script:focusEnd=$null}
  else{if($script:focusRemaining -le 0){$script:focusRemaining=$script:focusSeconds};$script:focusEnd=[datetime]::UtcNow.AddSeconds($script:focusRemaining);$script:focusSession=$true}
  Save-FocusTimer;Update-FocusTimer
}
$script:focusPresentation=@{active=$null;epoch=0}
function Update-FocusPresentation {
  $state=$script:focusPresentation;$active=[bool]$script:focusSession
  if($null -ne $state.active -and $state.active -eq $active){return}
  $state.active=$active;$state.epoch++;$epoch=$state.epoch
  $incoming=if($active){$focusView.FindName('FocusCountdown')}else{$focusView.FindName('FocusChoices')}
  $outgoing=if($active){$focusView.FindName('FocusChoices')}else{$focusView.FindName('FocusCountdown')}
  $incoming.Visibility='Visible';$incoming.IsHitTestVisible=$true;$outgoing.IsHitTestVisible=$false
  $focusView.FindName('FocusReset').Visibility=if($active){'Visible'}else{'Collapsed'}
  if($script:expanded -and $script:view -eq 'Focus' -and $window.IsVisible){
    $incoming.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$incoming.Opacity=0
    Animate $incoming ([Windows.UIElement]::OpacityProperty) 1 .22
    $fade=[Windows.Media.Animation.DoubleAnimation]::new(0,[timespan]::FromSeconds(.18))
    $fade.Add_Completed({if($state.epoch -eq $epoch){$outgoing.Visibility='Collapsed'}}.GetNewClosure())
    $outgoing.BeginAnimation([Windows.UIElement]::OpacityProperty,$fade)
  }else{
    $incoming.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$incoming.Opacity=1;$outgoing.Visibility='Collapsed'
  }
}
function Update-FocusTimer {
  if($script:focusBreakEnd -and [datetime]::UtcNow -ge $script:focusBreakEnd){Finish-FocusBreak $script:focusBreakEnd}
  Update-FocusPresentation
  if($script:focusEnd){
    $script:focusRemaining=[math]::Max(0,($script:focusEnd-[datetime]::UtcNow).TotalSeconds)
    if($script:focusRemaining -le 0){$script:focusEnd=$null;$script:focusSession=$false;Save-FocusTimer;$focusNotice.FindName('FocusDoneTitle').Text=$script:focusName+' complete';if($script:islandSettings.focusNotice){$script:notification=$true;$script:view='Focus';Expand;Play-IslandSound 'Focus';$script:deadline=[datetime]::Now.AddSeconds(8)}}
  }
  Update-FocusPresentation
  $focusHome.FindName('FocusSmallRingHost').Visibility=if($script:focusSession){'Visible'}else{'Collapsed'}
  $text=Focus-TimeText $script:focusRemaining;$focusView.FindName('FocusTime').Text=$text;$focusHome.FindName('FocusSmallTime').Text=if($script:focusSession){$text}else{'Choose time'}
  $focusView.FindName('FocusStatus').Text=if($script:focusBreakEnd){'Break '+(Focus-TimeText (($script:focusBreakEnd-[datetime]::UtcNow).TotalSeconds))}elseif($script:focusEnd){'Click to pause'}elseif($script:focusSession){'Paused · click to resume'}else{'Click to start'}
  $ratio=if($script:focusSeconds -gt 0){[math]::Max(0.0,[math]::Min(1.0,[double]($script:focusRemaining/$script:focusSeconds)))}else{0}
  # Linear interpolation follows the UTC deadline; endpoints are exact.
  foreach($ring in $script:focusRing,$script:focusSmallRing){
    if($ratio -eq 0 -or $ratio -eq 1 -or -not $script:focusEnd){$ring.BeginAnimation([FocusRing]::RatioProperty,$null);$ring.Ratio=$ratio}
    else{$animation=[Windows.Media.Animation.DoubleAnimation]::new($ring.Ratio,$ratio,[timespan]::FromMilliseconds(100));$ring.BeginAnimation([FocusRing]::RatioProperty,$animation)}
  }
  $onBreak=[bool]$script:focusBreakEnd
  foreach($ring in $script:focusBreakRing,$script:focusSmallBreakRing){
    $ring.Visibility=if($onBreak){'Visible'}else{'Collapsed'}
    if($onBreak){
      $breakRatio=[math]::Max(0.0,[math]::Min(1.0,($script:focusBreakEnd-[datetime]::UtcNow).TotalSeconds/[double]$script:focusBreakLength))
      $ring.RingBrush=[Windows.Media.Brushes]::DarkOrange;$ring.Opacity=1
      $animation=[Windows.Media.Animation.DoubleAnimation]::new($ring.Ratio,$breakRatio,[timespan]::FromMilliseconds(100));$ring.BeginAnimation([FocusRing]::RatioProperty,$animation)
    }
  }
  $focusHome.FindName('FocusSmallName').Text=$script:focusName
  if($onBreak){$breakText=Focus-TimeText (($script:focusBreakEnd-[datetime]::UtcNow).TotalSeconds);$focusHome.FindName('FocusSmallTime').Text=$breakText;$focusView.FindName('FocusTime').Text=$breakText;$focusView.FindName('FocusStatus').Text='Break · click to resume'}
  $focusHome.FindName('FocusBreak').Foreground=[Windows.Media.Brushes]::DarkOrange
  $focusHome.FindName('FocusBreak').Content=if($onBreak){'Resume'}else{'Break'}
  $focusHome.FindName('FocusBreak').ToolTip=if($onBreak){'End break and resume focus'}else{'Pause focus for a five-minute break'}
  $nearEnd=$script:focusSession -and $ratio -le .10
  $brush=if($onBreak){[Windows.Media.Brushes]::DarkOrange}elseif($nearEnd){[Windows.Media.Brushes]::IndianRed}else{$script:uiPrimary}
  $focusView.FindName('FocusTime').Foreground=$brush;$focusHome.FindName('FocusSmallTime').Foreground=$brush
  foreach($ring in $script:focusRing,$script:focusSmallRing){$ring.RingBrush=if($nearEnd){[Windows.Media.Brushes]::IndianRed}else{$script:systemAccentBrush};if(-not $ring.RingBrush){$ring.RingBrush=[Windows.Media.Brushes]::Silver};$ring.InvalidateVisual()}
  if(-not $script:expanded -and $script:view -ne (Get-HomePanel)){Restore-Home}
}
foreach($name in 'Focus5','Focus15','Focus30','Focus60','FocusStart','FocusReset','FocusCustom'){$button=$focusView.FindName($name);$button.Template=$template;$button.Foreground=$script:uiPrimary;$button.Cursor=[Windows.Input.Cursors]::Hand}
$focusHome.FindName('FocusBreak').Template=$template;$focusHome.FindName('FocusBreak').Foreground=$script:uiSecondary;$focusHome.FindName('FocusBreak').Cursor=[Windows.Input.Cursors]::Hand
function Start-FocusDuration([double]$seconds,[string]$kind){Set-IslandTextEditing $false;Set-FocusDuration $seconds $kind;Toggle-FocusTimer}
$focusView.FindName('Focus5').Add_Click({Start-FocusDuration 300 'Focus'})
$focusView.FindName('Focus15').Add_Click({Start-FocusDuration 900 'Focus'})
$focusView.FindName('Focus30').Add_Click({Start-FocusDuration 1800 'Focus'})
$focusView.FindName('Focus60').Add_Click({Start-FocusDuration 3600 'Focus'})
$focusView.FindName('FocusReset').Add_Click({Set-FocusDuration $script:focusSeconds $script:focusKind})
$focusView.FindName('FocusStart').Add_Click({Set-IslandTextEditing $false;Toggle-FocusTimer})
$focusHome.FindName('FocusBreak').Add_Click({param($sender,$eventArgs) $eventArgs.Handled=$true;Start-FocusBreak})
$focusHome.Add_PreviewMouseLeftButtonUp({param($sender,$eventArgs) $source=$eventArgs.OriginalSource;while($source -and $source -ne $focusHome){if($source -eq $focusHome.FindName('FocusBreak')){return};$source=[Windows.Media.VisualTreeHelper]::GetParent($source)};$eventArgs.Handled=$true;$script:notification=$false;$script:view='Focus';Expand})
$focusView.FindName('FocusHours').Text=[string][math]::Floor($script:focusCustom/3600)
$focusView.FindName('FocusMinutes').Text=[string]([int][math]::Floor($script:focusCustom/60)%60)
$focusView.FindName('FocusSeconds').Text=[string]($script:focusCustom%60)
function Read-FocusCustom {
  $h=0;$m=0;$s=0
  if(-not [int]::TryParse($focusView.FindName('FocusHours').Text,[ref]$h) -or -not [int]::TryParse($focusView.FindName('FocusMinutes').Text,[ref]$m) -or -not [int]::TryParse($focusView.FindName('FocusSeconds').Text,[ref]$s)){return 0}
  if($h -lt 0 -or $h -gt 23 -or $m -lt 0 -or $m -gt 59 -or $s -lt 0 -or $s -gt 59){return 0};return $h*3600+$m*60+$s
}
foreach($name in 'FocusHours','FocusMinutes','FocusSeconds'){$box=$focusView.FindName($name);$box.Background=[Windows.Media.Brushes]::Transparent;$box.Foreground=$script:uiPrimary;$box.BorderThickness='0';$box.FontSize=14;$box.VerticalContentAlignment='Center';$box.Add_TextChanged({$value=Read-FocusCustom;if($value -gt 0){$script:focusCustom=$value;Save-FocusTimer}})}
$focusView.FindName('FocusCustom').Add_Click({$value=Read-FocusCustom;if($value -gt 0){$script:focusCustom=$value;Start-FocusDuration $value 'Focus'}})

# The island normally never takes focus. Only a deliberate click in an editor
# enables keyboard input, while WS_EX_TOOLWINDOW still keeps it out of Alt-Tab.
foreach($name in 'FocusHours','FocusMinutes','FocusSeconds','FocusName'){
  $box=$focusView.FindName($name)
  $box.Add_PreviewMouseLeftButtonDown({
    param($sender,$eventArgs)
    if(-not $sender.IsKeyboardFocusWithin){
      Set-IslandTextEditing $true
      [void]$sender.Focus();[void][Windows.Input.Keyboard]::Focus($sender)
      $sender.SelectAll();$eventArgs.Handled=$true
    }
  })
  $box.Add_PreviewKeyDown({
    param($sender,$eventArgs)
    if($eventArgs.Key -eq 'Enter' -and $sender.Name -eq 'FocusName'){Set-IslandTextEditing $false;$eventArgs.Handled=$true}
    elseif($eventArgs.Key -eq 'Enter'){$focusView.FindName('FocusCustom').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));$eventArgs.Handled=$true}
    elseif($eventArgs.Key -eq 'Escape'){Set-IslandTextEditing $false;$eventArgs.Handled=$true}
  })
}

$nameBox=$focusView.FindName('FocusName');$nameBox.Text=$script:focusName;$nameBox.Background=[Windows.Media.Brushes]::Transparent;$nameBox.Foreground=$script:uiPrimary;$nameBox.BorderThickness='0';$nameBox.FontSize=14
function Get-FocusNameWidth([string]$text){
  $box=$focusView.FindName('FocusName')
  $face=[Windows.Media.Typeface]::new($box.FontFamily,$box.FontStyle,$box.FontWeight,$box.FontStretch)
  $formatted=[Windows.Media.FormattedText]::new($text,[Globalization.CultureInfo]::CurrentUICulture,[Windows.FlowDirection]::LeftToRight,$face,$box.FontSize,$script:uiPrimary)
  return $formatted.WidthIncludingTrailingWhitespace+24
}
function Test-FocusName([string]$text){return $text.Length -le 40 -and $text -notmatch '[\r\n]' -and (Get-FocusNameWidth $text) -le 200}
function Shake-FocusName {
  if($script:focusNameShakeAt -and ([datetime]::UtcNow-$script:focusNameShakeAt).TotalMilliseconds -lt 260){return}
  $script:focusNameShakeAt=[datetime]::UtcNow
  $field=$focusView.FindName('FocusNameField')
  if($field.RenderTransform -isnot [Windows.Media.TranslateTransform]){$field.RenderTransform=New-Object Windows.Media.TranslateTransform}
  $shake=New-Object Windows.Media.Animation.DoubleAnimationUsingKeyFrames
  $points=@(0,-4,4,-4,4,-2,2,0)
  for($i=0;$i -lt $points.Count;$i++){
    $key=[Windows.Media.Animation.LinearDoubleKeyFrame]::new($points[$i],[Windows.Media.Animation.KeyTime]::FromTimeSpan([timespan]::FromMilliseconds($i*32)))
    [void]$shake.KeyFrames.Add($key)
  }
  $field.RenderTransform.BeginAnimation([Windows.Media.TranslateTransform]::XProperty,$shake)
}
function Get-FocusNameCandidate([string]$inputText){
  $box=$focusView.FindName('FocusName')
  return $box.Text.Remove($box.SelectionStart,$box.SelectionLength).Insert($box.SelectionStart,$inputText)
}
# Clamp historical names once, then reject oversized edits without moving the caret.
while(-not (Test-FocusName $nameBox.Text) -and $nameBox.Text.Length -gt 0){$nameBox.Text=$nameBox.Text.Substring(0,$nameBox.Text.Length-1)}
$script:focusAcceptedName=$nameBox.Text
$focusView.FindName('FocusNameField').Width=[math]::Max(56.0,(Get-FocusNameWidth $nameBox.Text))
$nameBox.Add_PreviewTextInput({param($sender,$eventArgs)
  if(-not (Test-FocusName (Get-FocusNameCandidate $eventArgs.Text))){$eventArgs.Handled=$true;Shake-FocusName}
})
[Windows.DataObject]::AddPastingHandler($nameBox,[Windows.DataObjectPastingEventHandler]{param($sender,$eventArgs)
  if(-not $eventArgs.DataObject.GetDataPresent([Windows.DataFormats]::UnicodeText)){$eventArgs.CancelCommand();return}
  $text=[string]$eventArgs.DataObject.GetData([Windows.DataFormats]::UnicodeText)
  if(-not (Test-FocusName (Get-FocusNameCandidate $text))){$eventArgs.CancelCommand();Shake-FocusName}
})
$nameBox.Add_TextChanged({
  if($script:focusNameRestoring){return}
  $box=$focusView.FindName('FocusName')
  if(-not (Test-FocusName $box.Text)){
    $caret=$box.CaretIndex;$script:focusNameRestoring=$true
    try{$box.Text=$script:focusAcceptedName;$box.CaretIndex=[math]::Min($caret,$box.Text.Length)}finally{$script:focusNameRestoring=$false}
    Shake-FocusName;return
  }
  $script:focusAcceptedName=$box.Text
  $focusView.FindName('FocusNameField').Width=[math]::Max(56.0,(Get-FocusNameWidth $box.Text))
  $value=$box.Text.Trim();if($value){$script:focusName=$value;Save-FocusTimer}
})

