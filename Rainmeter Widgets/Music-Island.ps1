param([switch]$Probe)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime, PresentationFramework, PresentationCore, WindowsBase
$managerType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
$propertiesType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties,Windows.Media.Control,ContentType=WindowsRuntime]
$streamType = [Windows.Storage.Streams.IRandomAccessStreamWithContentType,Windows.Storage.Streams,ContentType=WindowsRuntime]
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 } | Select-Object -First 1
function Await($operation, $type) {
    $task = $asTask.MakeGenericMethod($type).Invoke($null, @($operation))
    if (-not $task.Wait(2000)) { throw 'Media request timed out' }
    return $task.Result
}
$manager = Await ($managerType::RequestAsync()) $managerType
if ($Probe) {
    $sessions = @($manager.GetSessions())
    foreach ($session in $sessions) {
        $properties = Await ($session.TryGetMediaPropertiesAsync()) $propertiesType
        [pscustomobject]@{App=$session.SourceAppUserModelId; HasTitle= [bool]$properties.Title; State=[string]$session.GetPlaybackInfo().PlaybackStatus}
    }
    Write-Output 'Media connection OK'
    return
}
$mutex = New-Object Threading.Mutex($false, 'Local\SariyerMusicIsland')
if (-not $mutex.WaitOne(0)) { return }
$rainmeter = Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'
function PrayerVisible([bool]$visible) {
    $command = if ($visible) {'!Show'} else {'!Hide'}
    Start-Process -FilePath $rainmeter -ArgumentList @($command, '"SariyerWidgets\Prayer"') -WindowStyle Hidden
}
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" WindowStyle="None" AllowsTransparency="True" Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Topmost="True" ResizeMode="NoResize" Width="407" Height="160">
 <Grid><Border Name="Pill" Background="Black" CornerRadius="32" Width="407" Height="160" VerticalAlignment="Top" HorizontalAlignment="Center" ClipToBounds="True">
  <Grid>
<Grid Name="PanelHeader" Margin="34,8,34,0" Height="30" VerticalAlignment="Top"><StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
<Button Name="PrayerTab" Width="34" Height="28" ToolTip="Prayer"><Viewbox Width="19" Height="19"><Path Fill="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}" Data="M 12,1 C 4,2 1,11 5,18 C 9,25 19,26 25,18 C 17,22 8,15 12,1 Z"/></Viewbox></Button>
<Button Name="PlayerTab" Width="34" Height="28" ToolTip="Player"><Viewbox Width="17" Height="19"><Path Fill="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}" Data="M 1,1 Q 0,0 0,3 L 0,23 Q 0,26 3,24 L 22,14 Q 25,12.5 22,11 Z"/></Viewbox></Button></StackPanel>
<ToggleButton Name="DefaultToggle" Width="34" Height="20" HorizontalAlignment="Right" ToolTip="Use this panel as home"><ToggleButton.Template><ControlTemplate TargetType="ToggleButton"><Grid><Border Name="Track" Background="#363638" CornerRadius="10"/><Ellipse Name="Thumb" Width="16" Height="16" Fill="White" HorizontalAlignment="Left" Margin="2"/></Grid><ControlTemplate.Triggers><Trigger Property="IsChecked" Value="True"><Setter TargetName="Track" Property="Background" Value="#54B66B"/><Setter TargetName="Thumb" Property="HorizontalAlignment" Value="Right"/></Trigger></ControlTemplate.Triggers></ControlTemplate></ToggleButton.Template></ToggleButton>
<Button Name="ClosePanel" Visibility="Collapsed"/></Grid>
<StackPanel Name="PrayerView" Margin="38,48,38,16" Visibility="Collapsed"><TextBlock Name="PrayerDate" Foreground="#999999" Margin="0,0,0,10"/><StackPanel Name="PrayerRows"/></StackPanel>
<Grid Name="Content" Width="331" HorizontalAlignment="Center" Margin="20,44,20,14" Opacity="0">
   <Grid.RowDefinitions><RowDefinition Height="62"/><RowDefinition Height="24"/><RowDefinition Height="46"/></Grid.RowDefinitions>
   <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="70"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
    <Border Background="#202020" CornerRadius="12" Width="56" Height="56" HorizontalAlignment="Left" ClipToBounds="True"><Image Name="Art" Width="56" Height="56" HorizontalAlignment="Center" VerticalAlignment="Center" Stretch="UniformToFill"><Image.Clip><RectangleGeometry Rect="0,0,56,56" RadiusX="12" RadiusY="12"/></Image.Clip></Image></Border>
    <StackPanel Grid.Column="1" Margin="0,0,51,0" VerticalAlignment="Center"><TextBlock Name="Song" Foreground="White" FontFamily="Segoe UI" FontSize="14" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/><TextBlock Name="Artist" Foreground="#999999" FontSize="13" Margin="0,3,0,0" TextTrimming="CharacterEllipsis"/></StackPanel><StackPanel Name="SoundBars" Grid.Column="1" Margin="0,0,16,0" HorizontalAlignment="Right" VerticalAlignment="Center" Orientation="Horizontal" Height="28">
<Rectangle Name="Bar0" Width="3" Height="10" RadiusX="1.5" RadiusY="1.5" Fill="#8CB6C1" Margin="1.5,0" VerticalAlignment="Center"/>
<Rectangle Name="Bar1" Width="3" Height="17" RadiusX="1.5" RadiusY="1.5" Fill="#8CB6C1" Margin="1.5,0" VerticalAlignment="Center"/>
<Rectangle Name="Bar2" Width="3" Height="26" RadiusX="1.5" RadiusY="1.5" Fill="#8CB6C1" Margin="1.5,0" VerticalAlignment="Center"/>
<Rectangle Name="Bar3" Width="3" Height="18" RadiusX="1.5" RadiusY="1.5" Fill="#8CB6C1" Margin="1.5,0" VerticalAlignment="Center"/>
<Rectangle Name="Bar4" Width="3" Height="11" RadiusX="1.5" RadiusY="1.5" Fill="#8CB6C1" Margin="1.5,0" VerticalAlignment="Center"/>
</StackPanel>
   </Grid>
   <Grid Grid.Row="1" VerticalAlignment="Center"><Grid.ColumnDefinitions><ColumnDefinition Width="36"/><ColumnDefinition/><ColumnDefinition Width="40"/></Grid.ColumnDefinitions><TextBlock Name="Elapsed" FontSize="10" Foreground="#999999"/><ProgressBar Name="Progress" Grid.Column="1" Height="4" Foreground="#BBBBBB" Background="#303030" BorderThickness="0" Maximum="1"/><TextBlock Name="Remaining" Grid.Column="2" Foreground="#999999" HorizontalAlignment="Right"/></Grid>
   <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
    <Button Name="Previous"><Viewbox Width="27" Height="22"><Path Fill="White" Data="M 13,1 Q 14,0 14,2 L 14,20 Q 14,22 12,21 L 0,12 Q -1,11 0,10 Z M 27,1 Q 28,0 28,2 L 28,20 Q 28,22 26,21 L 14,12 Q 13,11 14,10 Z"/></Viewbox></Button>
<Button Name="Pause"><Viewbox Width="23" Height="25"><Path Name="PlayIcon" Fill="White" Data="M 2,0 L 7,0 Q 9,0 9,2 L 9,23 Q 9,25 7,25 L 2,25 Q 0,25 0,23 L 0,2 Q 0,0 2,0 Z M 16,0 L 21,0 Q 23,0 23,2 L 23,23 Q 23,25 21,25 L 16,25 Q 14,25 14,23 L 14,2 Q 14,0 16,0 Z"/></Viewbox></Button>
<Button Name="Next"><Viewbox Width="27" Height="22"><Path Fill="White" Data="M 1,1 Q 0,0 0,2 L 0,20 Q 0,22 2,21 L 14,12 Q 15,11 14,10 Z M 15,1 Q 14,0 14,2 L 14,20 Q 14,22 16,21 L 28,12 Q 29,11 28,10 Z"/></Viewbox></Button>
   </StackPanel>
  </Grid>
 </Grid></Border></Grid>
</Window>
'@
$window = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xaml))
foreach ($name in 'Pill','Content','Art','Song','Artist','Elapsed','Remaining','Progress','Previous','Pause','Next','PlayIcon') { Set-Variable -Name $name -Value $window.FindName($name) }
foreach ($button in $Previous,$Pause,$Next) {
    $button.Width=72; $button.Height=44; $button.Foreground=[Windows.Media.Brushes]::White; $button.Background=[Windows.Media.Brushes]::Black; $button.BorderThickness=0; $button.Cursor=[Windows.Input.Cursors]::Hand
}
# Custom template avoids Windows button chrome and keeps vector icons crisp.
[xml]$buttonTemplate='<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Name="Surface" Background="Transparent" CornerRadius="12"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Opacity" Value="0.72"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="Surface" Property="Opacity" Value="0.55"/></Trigger></ControlTemplate.Triggers></ControlTemplate>'
$template=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $buttonTemplate))
foreach($button in $Previous,$Pause,$Next){$button.Template=$template}
# One full-sized card translates through the screen edge; no capsule state.
$Pill.Width=407; $Pill.Height=160
$Pill.CornerRadius=[Windows.CornerRadius]::new(0)
$Pill.Clip=[Windows.Media.Geometry]::Parse('M 0,0 L 407,0 Q 389,0 389,18 L 389,132 Q 389,160 361,160 L 46,160 Q 18,160 18,132 L 18,18 Q 18,0 0,0 Z')
$Content.Opacity=1
$slide=New-Object Windows.Media.TranslateTransform
$Pill.RenderTransform=$slide
$script:defaultPanelPath=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\IslandHome.txt'
$script:defaultPanel='Prayer'
if(Test-Path -LiteralPath $script:defaultPanelPath){$saved=[IO.File]::ReadAllText($script:defaultPanelPath).Trim();if($saved -in @('Prayer','Player')){$script:defaultPanel=$saved}}
$script:view='Player'
$prayerView=$window.FindName('PrayerView');$prayerRows=$window.FindName('PrayerRows');$prayerDate=$window.FindName('PrayerDate')
$prayerTab=$window.FindName('PrayerTab');$playerTab=$window.FindName('PlayerTab')
[xml]$compactXaml='<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" WindowStyle="None" AllowsTransparency="True" Background="Transparent" ShowInTaskbar="False" ShowActivated="False" ResizeMode="NoResize" Width="296" Height="32"><Grid><Path Fill="Black" Data="M 0,0 L 296,0 Q 278,0 278,14 L 278,20 Q 278,32 266,32 L 30,32 Q 18,32 18,20 L 18,14 Q 18,0 0,0 Z"/><Grid Margin="27,5,27,5"><Image Name="CompactArt" Width="20" Height="20" HorizontalAlignment="Left" Stretch="UniformToFill"><Image.Clip><EllipseGeometry Center="10,10" RadiusX="10" RadiusY="10"/></Image.Clip></Image><StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center" Height="22"><Rectangle Name="SmallBar0" Fill="#8CB6C1" Width="2" Height="4" RadiusX="1" RadiusY="1" Margin="1,0" VerticalAlignment="Center"/><Rectangle Name="SmallBar1" Fill="#8CB6C1" Width="2" Height="4" RadiusX="1" RadiusY="1" Margin="1,0" VerticalAlignment="Center"/><Rectangle Name="SmallBar2" Fill="#8CB6C1" Width="2" Height="4" RadiusX="1" RadiusY="1" Margin="1,0" VerticalAlignment="Center"/><Rectangle Name="SmallBar3" Fill="#8CB6C1" Width="2" Height="4" RadiusX="1" RadiusY="1" Margin="1,0" VerticalAlignment="Center"/><Rectangle Name="SmallBar4" Fill="#8CB6C1" Width="2" Height="4" RadiusX="1" RadiusY="1" Margin="1,0" VerticalAlignment="Center"/></StackPanel></Grid></Grid></Window>'
$compact=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $compactXaml))
function Restore-Home {
  if($script:defaultPanel -eq 'Player'){
    PrayerVisible $false
    $compact.Left=([Windows.SystemParameters]::PrimaryScreenWidth-296)/2;$compact.Top=0
    $compact.FindName('CompactArt').Source=$Art.Source
    $compact.Show()
  }else{$compact.Hide();PrayerVisible $true}
}
function Select-Panel($view,[bool]$save){
  $script:view=$view
  if($save){$script:defaultPanel=$view;[IO.File]::WriteAllText($script:defaultPanelPath,$view)}
  foreach($tab in $prayerTab,$playerTab){$tab.Template=$template;$tab.Foreground=[Windows.Media.Brushes]::White;$tab.Cursor=[Windows.Input.Cursors]::Hand}
  $Content.Visibility=if($view -eq 'Player'){'Visible'}else{'Collapsed'}
  $prayerView.Visibility=if($view -eq 'Prayer'){'Visible'}else{'Collapsed'}
  $prayerTab.Foreground=if($view -eq 'Prayer'){[Windows.Media.Brushes]::PaleGreen}else{[Windows.Media.Brushes]::Gray}
  $playerTab.Foreground=if($view -eq 'Player'){[Windows.Media.Brushes]::PaleGreen}else{[Windows.Media.Brushes]::Gray}
  $window.FindName('PanelHeader').Visibility=if($script:notification){'Collapsed'}else{'Visible'}
  $window.FindName('DefaultToggle').IsChecked=($script:defaultPanel -eq $view)
  $Content.Margin=if($script:notification){[Windows.Thickness]::new(20,14,20,14)}else{[Windows.Thickness]::new(20,44,20,14)}
  $bodyWidth=260.0
  if($script:defaultPanel -eq 'Prayer'){
    $geometryFile=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\Rainmeter\Skins\SariyerWidgets\@Resources\IslandGeometry.txt'
    if(Test-Path -LiteralPath $geometryFile){$values=[IO.File]::ReadAllLines($geometryFile);$bodyWidth=[double]::Parse($values[0],[Globalization.CultureInfo]::InvariantCulture)/[Windows.Media.VisualTreeHelper]::GetDpi($window).DpiScaleX}
  }
  if($script:notification){$bodyWidth=371.0}
  $outerWidth=$bodyWidth+36
  $window.Width=$outerWidth;$Pill.Width=$outerWidth;$Content.Width=$bodyWidth-40
  $window.Left=([Windows.SystemParameters]::PrimaryScreenWidth-$outerWidth)/2
  $height=if($script:notification){160}elseif($view -eq 'Prayer'){260}else{190}
  $window.Height=$height;$Pill.Height=$height
  $shape=[string]::Format([Globalization.CultureInfo]::InvariantCulture,'M 0,0 L {0},0 Q {1},0 {1},18 L {1},{2} Q {1},{3} {4},{3} L 46,{3} Q 18,{3} 18,{2} L 18,18 Q 18,0 0,0 Z',$outerWidth,($outerWidth-18),($height-28),$height,($outerWidth-46))
  $Pill.Clip=[Windows.Media.Geometry]::Parse($shape)
  if($view -eq 'Prayer'){
    $data=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\Rainmeter\Skins\SariyerWidgets\@Resources\PrayerTimes.txt'
    $prayerRows.Children.Clear()
    if(Test-Path -LiteralPath $data){
      $lines=[IO.File]::ReadAllLines($data);$prayerDate.Text='Sarıyer · '+$lines[0]
      foreach($line in ($lines | Select-Object -Skip 1)){
        $parts=$line.Split('|');if($parts.Count -ne 2){continue}
        $row=New-Object Windows.Controls.DockPanel;$row.Margin='0,0,0,9'
        $time=New-Object Windows.Controls.TextBlock;$time.Text=$parts[1];$time.Foreground=[Windows.Media.Brushes]::White;$time.FontSize=14
        [Windows.Controls.DockPanel]::SetDock($time,'Right');[void]$row.Children.Add($time)
        $label=New-Object Windows.Controls.TextBlock;$label.Text=$parts[0];$label.Foreground=[Windows.Media.Brushes]::LightGray;$label.FontSize=14;[void]$row.Children.Add($label)
        [void]$prayerRows.Children.Add($row)
      }
    }else{$prayerDate.Text='Prayer times unavailable'}
  }
  $script:deadline=[datetime]::Now.AddSeconds(10)
}
$prayerTab.Add_Click({Select-Panel 'Prayer' $false})
$playerTab.Add_Click({Select-Panel 'Player' $false})
$window.FindName('ClosePanel').Add_Click({$script:forceClose=$true;$script:deadline=[datetime]::MinValue})
$window.FindName('DefaultToggle').Add_Click({
  if($script:notification){return}
  $chosen=if($window.FindName('DefaultToggle').IsChecked){$script:view}elseif($script:view -eq 'Prayer'){'Player'}else{'Prayer'}
  $script:defaultPanel=$chosen;[IO.File]::WriteAllText($script:defaultPanelPath,$chosen)
})
$compact.Add_MouseLeftButtonUp({$script:notification=$false;Select-Panel 'Player' $false;Expand})
Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;
public static class IslandPointer{
[StructLayout(LayoutKind.Sequential)] public struct Point{public int X,Y;}
[DllImport("user32.dll")]public static extern short GetAsyncKeyState(int key);
[DllImport("user32.dll")]public static extern bool GetCursorPos(out Point point);
}
"@
$navigationTimer=New-Object Windows.Threading.DispatcherTimer;$navigationTimer.Interval=[timespan]::FromMilliseconds(100)
$navigationTimer.Add_Tick({
  $down=(([IslandPointer]::GetAsyncKeyState(1) -band 0x8000) -ne 0) -or (([IslandPointer]::GetAsyncKeyState(2) -band 0x8000) -ne 0)
  if($script:expanded -and $down -and -not $script:pointerWasDown){
    $point=New-Object IslandPointer+Point;[void][IslandPointer]::GetCursorPos([ref]$point)
    $local=$window.PointFromScreen([Windows.Point]::new($point.X,$point.Y))
    if($local.X -lt 0 -or $local.X -gt $window.ActualWidth -or $local.Y -lt 0 -or $local.Y -gt $window.ActualHeight){
      $script:forceClose=$true;$script:deadline=[datetime]::MinValue
    }
  }
  $script:pointerWasDown=$down
  $request=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\Rainmeter\Skins\SariyerWidgets\@Resources\PanelRequest.txt'
  if(Test-Path -LiteralPath $request){Remove-Item -LiteralPath $request;$script:notification=$false;Select-Panel 'Prayer' $false;Expand}
})
$navigationTimer.Start()
Restore-Home
$pauseGeometry=$PlayIcon.Data
$playGeometry=[Windows.Media.Geometry]::Parse('M 2,0 Q 0,-1 0,2 L 0,23 Q 0,26 3,24 L 22,14 Q 25,12.5 22,11 Z')
$script:collapsedWidth=340; $script:collapsedHeight=48; $script:active=$null; $script:expanded=$false; $script:closing=$false; $script:deadline=[datetime]::MinValue; $script:seen=@{}
function Animate($target,$property,$value,$seconds) {
    $animation=New-Object Windows.Media.Animation.DoubleAnimation
    $animation.To=$value; $animation.Duration=[Windows.Duration]::new([timespan]::FromSeconds($seconds))
    $ease=New-Object Windows.Media.Animation.CubicEase; $ease.EasingMode='EaseInOut'; $animation.EasingFunction=$ease
    $target.BeginAnimation($property,$animation)
}
function Expand {
    $script:forceClose=$false; $wasOpen=$script:expanded; $compact.Hide(); Select-Panel $script:view $false
    $script:closing=$false; $script:expanded=$true; $script:deadline=[datetime]::Now.AddSeconds(6)
    $window.Top=0
    if(-not $wasOpen){$slide.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$null); $slide.Y=-($window.Height+2)}
    PrayerVisible $false
    $window.Show()
    Animate $slide ([Windows.Media.TranslateTransform]::YProperty) 0 .45
}
function Send-Control($command){
    if(-not $script:active){return}
    $script:deadline=[datetime]::Now.AddSeconds(6)
    if($command -eq 'Toggle'){
      $script:optimisticPlaying=($PlayIcon.Data -ne $pauseGeometry)
      $PlayIcon.Data=if($script:optimisticPlaying){$pauseGeometry}else{$playGeometry}
      $operation=if($script:optimisticPlaying){$script:active.TryPlayAsync()}else{$script:active.TryPauseAsync()}
      $script:controlUntil=[datetime]::Now.AddMilliseconds(350)
    }elseif($command -eq 'Next'){$operation=$script:active.TrySkipNextAsync()}
    else{$operation=$script:active.TrySkipPreviousAsync()}
    $script:commandTask=$asTask.MakeGenericMethod([bool]).Invoke($null,@($operation))
}
# Dispatch on press instead of waiting for mouse release.
$Previous.Add_PreviewMouseLeftButtonDown({param($sender,$eventArgs) $eventArgs.Handled=$true; Send-Control 'Previous'})
$Next.Add_PreviewMouseLeftButtonDown({param($sender,$eventArgs) $eventArgs.Handled=$true; Send-Control 'Next'})
$Pause.Add_PreviewMouseLeftButtonDown({param($sender,$eventArgs) $eventArgs.Handled=$true; Send-Control 'Toggle'})
$Previous.Add_Click({Send-Control 'Previous'})
$Next.Add_Click({Send-Control 'Next'})
$Pause.Add_Click({Send-Control 'Toggle'})
# Lightweight visual clock is independent of metadata requests.
Add-Type -Path (Join-Path $PSScriptRoot 'AudioMeter.cs')
$audioMeter=New-Object IslandAudioMeter
$audioHistory=New-Object 'double[]' 5
$audioClock=[Diagnostics.Stopwatch]::StartNew()
$script:lastAudioFrame=0.0
# Visual meter tuning: fixed absolute scale preserves quiet/loud differences.
$meterFloorDb=-48.0
$meterAttack=.035
$meterRelease=.120
$visualTimer=New-Object Windows.Threading.DispatcherTimer
$visualTimer.Interval=[timespan]::FromMilliseconds(33)
$smallBars=0..4 | ForEach-Object {$compact.FindName('SmallBar'+$_)}
$bars=0..4 | ForEach-Object {$window.FindName('Bar'+$_)}
$visualTimer.Add_Tick({
 if(-not $script:expanded -and -not $compact.IsVisible){return}
 $isPlaying=$false
 if($script:active){$isPlaying=[string]$script:active.GetPlaybackInfo().PlaybackStatus -eq 'Playing'}
 if($script:controlUntil -and [datetime]::Now -lt $script:controlUntil){$isPlaying=$script:optimisticPlaying}
 $PlayIcon.Data=if($isPlaying){$pauseGeometry}else{$playGeometry}
 $peak=if($isPlaying){[double]$audioMeter.Read()}else{0}
 for($j=4;$j -gt 0;$j--){$audioHistory[$j]=$audioHistory[$j-1]}
 $now=$audioClock.Elapsed.TotalSeconds
 $dt=[math]::Min(.1,[math]::Max(.001,$now-$script:lastAudioFrame)); $script:lastAudioFrame=$now
 $db=20*[math]::Log10([math]::Max(.000001,$peak))
 $level=[math]::Max(0.0,[math]::Min(1.0,($db-$meterFloorDb)/(-$meterFloorDb)))
 $audioHistory[0]=[math]::Pow($level,1.65)
 for($i=0;$i -lt 5;$i++){
      $target=4+(22-[math]::Abs(2-$i)*3)*$audioHistory[$i]
      $tau=if($target -gt $bars[$i].Height){$meterAttack}else{$meterRelease}
   $blend=1-[math]::Exp(-$dt/$tau)
   $bars[$i].Height=$bars[$i].Height+($target-$bars[$i].Height)*$blend
   $smallBars[$i].Height=[math]::Max(3.0,$bars[$i].Height*.72);$smallBars[$i].Fill=$bars[$i].Fill
 }
})
$visualTimer.Start()
function TimeText($seconds) { $seconds=[math]::Max(0,[int][math]::Floor($seconds)); return ('{0}:{1:00}' -f [math]::Floor($seconds/60),($seconds%60)) }
$timer=New-Object Windows.Threading.DispatcherTimer
$timer.Interval=[timespan]::FromMilliseconds(150)
$timer.Add_Tick({
 try {
    $sessions=@($manager.GetSessions())
    $candidate=$manager.GetCurrentSession()
    foreach($s in $sessions) { if([string]$s.GetPlaybackInfo().PlaybackStatus -eq 'Playing') { $candidate=$s; break } }
    if($candidate) {
            # Poll the WinRT task without blocking the input/render dispatcher.
      $candidateId=[string]$candidate.SourceAppUserModelId
      if(-not $script:metadataTask -or $script:metadataId -ne $candidateId){
        $script:metadataId=$candidateId
        $script:metadataTask=$asTask.MakeGenericMethod($propertiesType).Invoke($null,@($candidate.TryGetMediaPropertiesAsync()))
        return
      }
      if(-not $script:metadataTask.IsCompleted){return}
      $properties=$script:metadataTask.GetAwaiter().GetResult()
      $script:metadataTask=$null
      $id=[string]$candidate.SourceAppUserModelId
      $key=$properties.Title+'|'+$properties.Artist
      $playing=[string]$candidate.GetPlaybackInfo().PlaybackStatus -eq 'Playing'
      # Social pages often publish a tab title and browser icon as media metadata.
      # They must not generate song-change notifications or replace the music card.
      $browserSession=$id -match '(?i)chrome|msedge|firefox|brave|opera|browser'
      $socialTitle=$properties.Title -match '(?i)^\s*(\(\d+\)\s*)?(Instagram|Facebook|TikTok|X|Twitter)(\s*[-–|·].*)?\s*$'
      $genericTitle=$properties.Title -match '(?i)^\s*(Google Chrome|Chrome|Microsoft Edge|Mozilla Firefox|New Tab)\s*$'
      $eligible=-not ($browserSession -and ($socialTitle -or $genericTitle))
      if($properties.Title -and $playing -and $eligible -and $script:seen[$id] -ne $key) {
        $script:seen[$id]=$key; $script:active=$candidate
        $Song.Text=$properties.Title; $Artist.Text=$properties.Artist; $Art.Source=$null
        if($properties.Thumbnail) {
          $stream=$null; $reader=$null
          try {
            $script:artTask=$asTask.MakeGenericMethod($streamType).Invoke($null,@($properties.Thumbnail.OpenReadAsync()))
            $script:artKey=$key
          } catch {} finally {if($reader){$reader.Dispose()}}
        }
        if(-not $script:expanded -or $script:notification){$script:notification=$true;Select-Panel 'Player' $false;Expand}
      }
    }
    if($script:artTask -and $script:artTask.IsCompleted){
      $reader=$null
      try{
        $stream=$script:artTask.GetAwaiter().GetResult()
                        # WinRT returns a COM interface here; invoke its declared interface
            # explicitly so PowerShell can resolve the stream adapter.
            $inputType=[Windows.Storage.Streams.IInputStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
            $randomType=[Windows.Storage.Streams.IRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
            $input=$randomType.GetMethod('GetInputStreamAt').Invoke($stream,@([uint64]0))
            $adapter=[System.IO.WindowsRuntimeStreamExtensions].GetMethod('AsStreamForRead',[type[]]@($inputType))
            $reader=$adapter.Invoke($null,@($input))
            $memory=New-Object IO.MemoryStream; $reader.CopyTo($memory); $reader.Dispose(); $reader=$memory; $memory.Position=0; $image=New-Object Windows.Media.Imaging.BitmapImage
            $image.BeginInit(); $image.CacheOption='OnLoad'; $image.StreamSource=$reader; $image.EndInit(); $image.Freeze(); $side=[math]::Min($image.PixelWidth,$image.PixelHeight)
            $crop=[Windows.Int32Rect]::new([int][math]::Floor(($image.PixelWidth-$side)/2),[int][math]::Floor(($image.PixelHeight-$side)/2),$side,$side)
            $centered=[Windows.Media.Imaging.CroppedBitmap]::new($image,$crop);$centered.Freeze()
            $Art.Source=$centered; $compact.FindName('CompactArt').Source=$centered
            # Quantize a small image and pick its strongest colorful cluster.
            $sample=New-Object Windows.Media.Imaging.TransformedBitmap($image,[Windows.Media.ScaleTransform]::new(32.0/$image.PixelWidth,32.0/$image.PixelHeight))
            $rgba=New-Object Windows.Media.Imaging.FormatConvertedBitmap($sample,[Windows.Media.PixelFormats]::Bgra32,$null,0)
            $pixels=New-Object byte[] (32*32*4); $rgba.CopyPixels($pixels,128,0)
            $palette=@{}
            for($k=0;$k -lt $pixels.Length;$k+=4){
              $r=[int]$pixels[$k+2];$g=[int]$pixels[$k+1];$b=[int]$pixels[$k]
              $max=[math]::Max($r,[math]::Max($g,$b));$min=[math]::Min($r,[math]::Min($g,$b))
              if($max -lt 35 -or $min -gt 235){continue}
              $key=('{0},{1},{2}' -f ($r -shr 5),($g -shr 5),($b -shr 5))
              if(-not $palette.ContainsKey($key)){$palette[$key]=@{score=0;r=0;g=0;b=0;n=0}}
              $bucket=$palette[$key];$bucket.score+=1+2*($max-$min)/255.0;$bucket.r+=$r;$bucket.g+=$g;$bucket.b+=$b;$bucket.n++
            }
            $best=$palette.Values | Sort-Object score -Descending | Select-Object -First 1
            if($best){
              $r=$best.r/$best.n;$g=$best.g/$best.n;$b=$best.b/$best.n
              $lift=[math]::Max(0,150-[math]::Max($r,[math]::Max($g,$b)))
              $color=[Windows.Media.Color]::FromRgb([byte]($r+$lift),[byte]($g+$lift),[byte]($b+$lift))
              $brush=[Windows.Media.SolidColorBrush]::new($color); $brush.Freeze()
              foreach($bar in $bars){$bar.Fill=$brush}
            }
      }catch{}finally{if($reader){$reader.Dispose()};$script:artTask=$null}
    }
    if($script:expanded) {
      if($window.IsMouseOver -and -not $script:forceClose){$script:deadline=[datetime]::Now.AddSeconds(6)}
      if($script:active) {
        $timeline=$script:active.GetTimelineProperties(); $duration=($timeline.EndTime-$timeline.StartTime).TotalSeconds
        $position=($timeline.Position-$timeline.StartTime).TotalSeconds
        # Position is a timestamped snapshot, not necessarily the current instant.
        if([string]$script:active.GetPlaybackInfo().PlaybackStatus -eq 'Playing'){
          $age=([DateTimeOffset]::UtcNow-[DateTimeOffset]$timeline.LastUpdatedTime).TotalSeconds
          if($age -ge 0 -and $age -le $duration){$position+=$age}
        }
        $position=[math]::Max(0.0,[math]::Min([double]$duration,[double]$position))
        if(-not $script:controlUntil -or [datetime]::Now -gt $script:controlUntil){$PlayIcon.Data=if([string]$script:active.GetPlaybackInfo().PlaybackStatus -eq 'Playing'){$pauseGeometry}else{$playGeometry}}
        $Elapsed.Text=TimeText $position; $Remaining.Text='-'+(TimeText ($duration-$position))
        $Progress.Value=if($duration -gt 0){[math]::Max(0.0,[math]::Min(1.0,$position/$duration))}else{0}
      }
      if([datetime]::Now -gt $script:deadline -and -not $script:closing) {
        $script:closing=$true
        $exit=New-Object Windows.Media.Animation.DoubleAnimation
        $exit.To=-($window.Height+2); $exit.Duration=[Windows.Duration]::new([timespan]::FromSeconds(.40))
        $ease=New-Object Windows.Media.Animation.CubicEase; $ease.EasingMode='EaseInOut'; $exit.EasingFunction=$ease
        $exit.Add_Completed({
          if($script:closing){$window.Hide(); Restore-Home; $script:expanded=$false; $script:closing=$false}
        })
        $slide.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$exit)
      }
    }
 } catch {
    if($script:expanded){$window.Hide(); PrayerVisible $true; $script:expanded=$false}
    $_.Exception.Message | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'Music-Island-error.log')
 }
})
try { $timer.Start(); [Windows.Threading.Dispatcher]::Run() }
finally { $navigationTimer.Stop(); $compact.Close(); $visualTimer.Stop(); $timer.Stop(); PrayerVisible $true; $mutex.ReleaseMutex(); $mutex.Dispose() }
