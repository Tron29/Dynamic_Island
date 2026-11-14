param([switch]$Probe)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime, PresentationFramework, PresentationCore, WindowsBase
# Suppress hover labels for every island control, including dynamic panels.
[Windows.Controls.ToolTipService]::IsEnabledProperty.OverrideMetadata([Windows.FrameworkElement],[Windows.FrameworkPropertyMetadata]::new($false))
$script:uiPrimary=[Windows.Media.Brushes]::White;$script:uiSecondary=[Windows.Media.Brushes]::Gray
# Keep a transient UI callback failure from terminating the entire island.
[Windows.Threading.Dispatcher]::CurrentDispatcher.Add_UnhandledException({
  param($sender,$eventArgs)
  $eventArgs.Handled=$true
  try{
    $errorFile=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\Music-Island-error.log'
    ([datetime]::Now.ToString('s')+' '+$eventArgs.Exception.GetBaseException().Message) | Set-Content -LiteralPath $errorFile
  }catch{}
})
Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;
public static class IslandWindowStyle {
[DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd,System.Text.StringBuilder name,int count);
public delegate bool WindowCallback(IntPtr hwnd,IntPtr data);
[StructLayout(LayoutKind.Sequential)] public struct Rect {public int Left,Top,Right,Bottom;}
[DllImport("user32.dll")] static extern bool EnumWindows(WindowCallback callback,IntPtr data);
[DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
[DllImport("user32.dll")] static extern bool IsIconic(IntPtr hwnd);
[DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd,out Rect rect);
[DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint process);
[DllImport("user32.dll")] static extern int GetSystemMetrics(int metric);
[DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr hwnd,int attribute,out int value,int size);
[DllImport("dwmapi.dll",EntryPoint="DwmGetWindowAttribute")] static extern int GetVisibleBounds(IntPtr hwnd,int attribute,out Rect value,int size);
static string ClassName(IntPtr hwnd){var name=new System.Text.StringBuilder(256);GetClassName(hwnd,name,256);return name.ToString();}
public static bool CountsAsApp(bool visible,bool minimized,bool cloaked,bool own,bool tool,bool shell,bool onScreen){return visible&&!minimized&&!cloaked&&!own&&!tool&&!shell&&onScreen;}
public static double CompactWidth=428, CompactHeight=47;
public static bool CoversIsland(int left,int top,int right,int bottom,int screenWidth,double scale){
  double half=CompactWidth*scale/2;
  return right>screenWidth/2.0-half&&left<screenWidth/2.0+half&&bottom>0&&top<(CompactHeight-2)*scale;
}
[DllImport("user32.dll")] static extern uint GetDpiForSystem();
static bool AppWindow(IntPtr hwnd){
  uint process;GetWindowThreadProcessId(hwnd,out process);
  string cls=ClassName(hwnd);
  bool shell=cls=="Progman"||cls=="WorkerW"||cls=="Shell_TrayWnd"||cls=="Shell_SecondaryTrayWnd";
  Rect r;bool rect=GetVisibleBounds(hwnd,9,out r,16)==0; if(!rect)rect=GetWindowRect(hwnd,out r);
  bool onScreen=rect&&r.Right>0&&r.Bottom>0&&r.Left<GetSystemMetrics(0)&&r.Top<GetSystemMetrics(1)&&r.Right-r.Left>64&&r.Bottom-r.Top>64;
  int cloaked;bool hidden=DwmGetWindowAttribute(hwnd,14,out cloaked,4)==0&&cloaked!=0;
  return CoversIsland(r.Left,r.Top,r.Right,r.Bottom,GetSystemMetrics(0),GetDpiForSystem()/96.0)&&CountsAsApp(IsWindowVisible(hwnd),IsIconic(hwnd),hidden,process==(uint)System.Diagnostics.Process.GetCurrentProcess().Id,(Get(hwnd,-20).ToInt64()&0x80)!=0,shell,onScreen);
}
static int checkedAt;static bool cachedDesktop;static bool hasCachedDesktop;
public static bool DesktopForeground(){
  int now=Environment.TickCount;
  if(hasCachedDesktop&&unchecked((uint)(now-checkedAt))<80)return cachedDesktop;
  IntPtr foreground=GetForegroundWindow();string cls=ClassName(foreground);
  bool desktop=cls=="Progman"||cls=="WorkerW";
  if(!desktop){
    bool visibleApp=false;
    EnumWindows((hwnd,data)=>{if(AppWindow(hwnd)){visibleApp=true;return false;}return true;},IntPtr.Zero);
    desktop=!visibleApp;
  }
  checkedAt=now;cachedDesktop=desktop;hasCachedDesktop=true;return desktop;
}
[DllImport("user32.dll",EntryPoint="GetWindowLongPtrW")] public static extern IntPtr Get(IntPtr hwnd,int index);
[DllImport("user32.dll",EntryPoint="SetWindowLongPtrW")] public static extern IntPtr Set(IntPtr hwnd,int index,IntPtr value);
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd,IntPtr after,int x,int y,int w,int h,uint flags);
[DllImport("user32.dll")] static extern bool ShowWindowAsync(IntPtr hwnd,int command);
[DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hwnd);
[DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd,System.Text.StringBuilder text,int length);
public static bool OpenSource(string source,string song){
 string lower=source.ToLowerInvariant();string processName=null;
 foreach(string name in new[]{"spotify","chrome","msedge","firefox","brave","opera","vlc"})if(lower.Contains(name)){processName=name;break;}
 if(processName==null)return false;
 var ids=new System.Collections.Generic.HashSet<uint>();foreach(var process in System.Diagnostics.Process.GetProcessesByName(processName)){ids.Add((uint)process.Id);process.Dispose();}
 IntPtr best=IntPtr.Zero;int bestScore=-1;
 EnumWindows((hwnd,data)=>{uint pid;GetWindowThreadProcessId(hwnd,out pid);if(!ids.Contains(pid))return true;
 var text=new System.Text.StringBuilder(1024);GetWindowText(hwnd,text,1024);if(text.Length==0||(Get(hwnd,-20).ToInt64()&0x80)!=0)return true;
 int score=IsWindowVisible(hwnd)?1:0;if(!String.IsNullOrWhiteSpace(song)&&text.ToString().IndexOf(song,StringComparison.OrdinalIgnoreCase)>=0)score+=10;
 if(score>bestScore){best=hwnd;bestScore=score;}return true;},IntPtr.Zero);
 if(best==IntPtr.Zero)return false;ShowWindowAsync(best,IsIconic(best)?9:5);return SetForegroundWindow(best);
}
public static void TextEntry(IntPtr hwnd,bool enabled){
 long style=Get(hwnd,-20).ToInt64();
 style=enabled?(style&~0x08000000L):(style|0x08000000L);
 Set(hwnd,-20,new IntPtr(style));SetWindowPos(hwnd,IntPtr.Zero,0,0,0,0,0x37);
 if(enabled)SetForegroundWindow(hwnd);
}
public static void Apply(IntPtr hwnd){long style=Get(hwnd,-20).ToInt64();style=(style|0x80L|0x08000000L)&~0x40000L;Set(hwnd,-20,new IntPtr(style));SetWindowPos(hwnd,IntPtr.Zero,0,0,0,0,0x37);}
}
"@
function Set-UtilityWindow($view){
  $view.Add_SourceInitialized({param($sender,$eventArgs)
    $handle=([Windows.Interop.WindowInteropHelper]::new($sender)).Handle
    [IslandWindowStyle]::Apply($handle)
  })
}
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
    $command = '!Hide' # Legacy native display is permanently data-only.
    Start-Process -FilePath $rainmeter -ArgumentList @($command, '"SariyerWidgets\Prayer"') -WindowStyle Hidden
}
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" WindowStyle="None" AllowsTransparency="True" Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Topmost="True" ResizeMode="NoResize" Width="407" Height="160">
 <Grid><Border Name="Pill" Background="Black" CornerRadius="32" Width="407" Height="160" VerticalAlignment="Top" HorizontalAlignment="Center" ClipToBounds="True">
  <Grid>
<Grid Name="PanelHeader" Margin="34,8,34,0" Height="30" VerticalAlignment="Top"><StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
<Button Name="PrayerTab" Width="34" Height="28"><Viewbox Width="20" Height="20"><Path Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}" StrokeThickness="1.8" StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round" Fill="Transparent" Data="M 20.8,13 A 9,9 0 1 1 11,3.2 A 7,7 0 0 0 20.8,13 M 18,1 L 19.2,4.8 L 23,6 L 19.2,7.2 L 18,11 L 16.8,7.2 L 13,6 L 16.8,4.8 Z"/></Viewbox></Button>
<Button Name="PlayerTab" Width="34" Height="28"><Viewbox Width="20" Height="20"><Path Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}" StrokeThickness="1.8" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Data="M 2,10 L 2,14 M 6,6 L 6,18 M 10,3 L 10,21 M 14,8 L 14,16 M 18,5 L 18,19 M 22,10 L 22,14"/></Viewbox></Button><Button Name="CalendarTab" Width="34" Height="28"><Viewbox Width="20" Height="20"><Path Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}" StrokeThickness="1.8" StrokeLineJoin="Round" Fill="Transparent" Data="M 4,5 L 20,5 Q 22,5 22,7 L 22,21 Q 22,23 20,23 L 4,23 Q 2,23 2,21 L 2,7 Q 2,5 4,5 Z M 7,2 L 7,8 M 17,2 L 17,8 M 2,11 L 22,11 M 7,15 L 9,15 M 15,15 L 17,15 M 7,19 L 9,19"/></Viewbox></Button></StackPanel>
<StackPanel Orientation="Horizontal" HorizontalAlignment="Right"><ToggleButton Name="DefaultToggle" Width="28" Height="28"><ToggleButton.Template><ControlTemplate TargetType="ToggleButton"><Border Background="Transparent" CornerRadius="8"><Viewbox Width="17" Height="22"><Canvas Width="24" Height="28"><Line Name="PinStem" X1="12" Y1="15" X2="12" Y2="26" Stroke="#888888" StrokeThickness="1.8" StrokeEndLineCap="Round"/><Ellipse Name="Pin" Canvas.Left="5" Canvas.Top="1" Width="14" Height="14" Stroke="#888888" Fill="Transparent" StrokeThickness="1.8"/><Path Name="PinGlint" Stroke="#888888" StrokeThickness="1.8" StrokeStartLineCap="Round" Data="M 9,6 Q 9,4 11,4"/></Canvas></Viewbox></Border><ControlTemplate.Triggers><Trigger Property="IsChecked" Value="True"><Setter TargetName="Pin" Property="Stroke" Value="White"/><Setter TargetName="Pin" Property="Fill" Value="White"/><Setter TargetName="PinStem" Property="Stroke" Value="White"/><Setter TargetName="PinGlint" Property="Stroke" Value="Black"/></Trigger></ControlTemplate.Triggers></ControlTemplate></ToggleButton.Template></ToggleButton><Button Name="SettingsButton" Width="28" Height="28" Foreground="#AAAAAA"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE713;" FontSize="16"/></Button></StackPanel>
<Button Name="ClosePanel" Visibility="Collapsed"/></Grid>
<StackPanel Name="PrayerView" Margin="38,48,38,16" Visibility="Collapsed"><TextBlock Name="PrayerDate" Foreground="#999999" Margin="0,0,0,10"/><StackPanel Name="PrayerRows"/></StackPanel>
<Grid Name="Content" Width="331" Height="132" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="20,44,20,14" Opacity="0">
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
   <Grid Grid.Row="1" VerticalAlignment="Center"><Grid.ColumnDefinitions><ColumnDefinition Width="36"/><ColumnDefinition/><ColumnDefinition Width="40"/></Grid.ColumnDefinitions><TextBlock Name="Elapsed" ClipToBounds="True" TextTrimming="CharacterEllipsis" FontSize="10" Foreground="#999999"/><Grid Name="SeekArea" Grid.Column="1" Height="22" Background="Transparent" Cursor="Hand"><ProgressBar Name="Progress" Height="4" VerticalAlignment="Center" Foreground="#BBBBBB" Background="#303030" BorderThickness="0" Maximum="1" IsHitTestVisible="False"/></Grid><TextBlock Name="Remaining" ClipToBounds="True" TextTrimming="CharacterEllipsis" Grid.Column="2" Foreground="#999999" HorizontalAlignment="Right"/></Grid>
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
Set-UtilityWindow $window
foreach ($name in 'Pill','Content','Art','Song','Artist','Elapsed','Remaining','Progress','Previous','Pause','Next','PlayIcon') { Set-Variable -Name $name -Value $window.FindName($name) }
foreach ($button in $Previous,$Pause,$Next) {
    $button.Width=72; $button.Height=44; $button.Foreground=$script:uiPrimary; $button.Background=[Windows.Media.Brushes]::Black; $button.BorderThickness=0; $button.Cursor=[Windows.Input.Cursors]::Hand
}
# Custom template avoids Windows button chrome and keeps vector icons crisp.
[xml]$buttonTemplate='<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Name="Surface" Background="Transparent" CornerRadius="12"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Opacity" Value="0.72"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="Surface" Property="Opacity" Value="0.55"/></Trigger></ControlTemplate.Triggers></ControlTemplate>'
$template=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $buttonTemplate))
foreach($button in $Previous,$Pause,$Next){$button.Template=$template}
# One full-sized card translates through the screen edge; no capsule state.
$Pill.Width=407; $Pill.Height=160
$Pill.CornerRadius=[Windows.CornerRadius]::new(0)
$Pill.Clip=[Windows.Media.Geometry]::Parse('M 0,0 L 407,0 Q 389,0 389,18 L 389,132 Q 389,160 361,160 L 46,160 Q 18,160 18,132 L 18,18 Q 18,0 0,0 Z')
# Update clip and content from the same animated bounds each frame.
$Pill.Add_SizeChanged({
  $w=$Pill.ActualWidth;$h=$Pill.ActualHeight
  if($w -lt 92 -or $h -lt 20){return}
  # Incoming player layout is set once at its destination width, not per frame.
  $radius=[math]::Min(28.0,$h/2)
  $shoulder=[math]::Min(18.0,$h/2)
  $shape=[string]::Format([Globalization.CultureInfo]::InvariantCulture,'M 0,0 L {0},0 Q {1},0 {1},{5} L {1},{2} Q {1},{3} {4},{3} L {6},{3} Q 18,{3} 18,{2} L 18,{5} Q 18,0 0,0 Z',$w,($w-18),($h-$radius),$h,($w-18-$radius),$shoulder,(18+$radius))
  $Pill.Clip=[Windows.Media.Geometry]::Parse($shape)
  if($script:surfaceRoot){
    $script:surfaceRoot.Width=$w;$script:surfaceRoot.Height=$h
    $script:surfaceRoot.Clip=$Pill.Clip.CloneCurrentValue()
  }
})
$Content.Opacity=1
$slide=New-Object Windows.Media.TranslateTransform
$Pill.RenderTransform=$slide
$script:defaultPanelPath=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\IslandHome.txt'
$script:defaultPanel='Prayer'
if(Test-Path -LiteralPath $script:defaultPanelPath){$saved=[IO.File]::ReadAllText($script:defaultPanelPath).Trim();if($saved -in @('Prayer','Player','Calendar','Focus')){$script:defaultPanel=$saved}}
$script:view='Player'
$prayerView=$window.FindName('PrayerView');$prayerRows=$window.FindName('PrayerRows');$prayerDate=$window.FindName('PrayerDate')
$prayerTab=$window.FindName('PrayerTab');$playerTab=$window.FindName('PlayerTab');$calendarTab=$window.FindName('CalendarTab')
# Windows DWM stores AccentColor as ABGR. Keep the accent legible on black.
function Update-SystemAccent {
  if($script:nextAccentRead -and [datetime]::Now -lt $script:nextAccentRead){return}
  $script:nextAccentRead=[datetime]::Now.AddSeconds(2)
  $r=180;$g=180;$b=180
  try{
    $raw=[uint32](Get-ItemPropertyValue -LiteralPath 'HKCU:\Software\Microsoft\Windows\DWM' -Name AccentColor)
    $r=[int]($raw -band 255);$g=[int](($raw -shr 8) -band 255);$b=[int](($raw -shr 16) -band 255)
  }catch{}
  if($script:islandSettings -and $script:islandSettings.accent -ne 'System'){
    $colors=@{Gray='#AAAAAA';Blue='#8DAAC9';Purple='#AF9EC4';Rose='#C59CA6';Amber='#C5AD85'}
    if($colors.ContainsKey([string]$script:islandSettings.accent)){$color=[Windows.Media.ColorConverter]::ConvertFromString($colors[$script:islandSettings.accent]);$r=[int]$color.R;$g=[int]$color.G;$b=[int]$color.B}
  }
  if($script:islandSettings.mode -eq 'Light'){$r=[int]($r*.55);$g=[int]($g*.55);$b=[int]($b*.55)}
  # Preserve hue while lifting very dark system colors for this black surface.
  $bright=[math]::Max($r,[math]::Max($g,$b))
  if($bright -lt 155 -and $script:islandSettings.mode -ne 'Light'){$lift=155-$bright;$r+=$lift;$g+=$lift;$b+=$lift}
  $key="$r,$g,$b"
  if($script:accentKey -eq $key){return}
  $script:accentKey=$key
  $script:systemAccentBrush=[Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromRgb($r,$g,$b));$script:systemAccentBrush.Freeze()
  $window.Resources['SystemAccentBrush']=$script:systemAccentBrush
  $prayerTab.Foreground=if($script:view -eq 'Prayer'){$script:systemAccentBrush}else{$script:uiSecondary}
  $playerTab.Foreground=if($script:view -eq 'Player'){$script:systemAccentBrush}else{$script:uiSecondary}
  $file=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\Rainmeter\Skins\SariyerWidgets\@Resources\SystemAccent.txt'
  try{[IO.File]::WriteAllText($file,$key)}catch [System.IO.IOException]{$script:accentKey=$null}
}
Update-SystemAccent

# All presentations are children of this single visible window and black surface.
[xml]$homeXaml='<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Margin="28,5" Visibility="Collapsed"><Image Name="CompactArt" Width="20" Height="20" HorizontalAlignment="Left" Stretch="UniformToFill"><Image.Clip><EllipseGeometry Center="10,10" RadiusX="10" RadiusY="10"/></Image.Clip></Image><StackPanel Name="CompactSoundBars" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center" Height="22"><Rectangle Name="SmallBar0" Width="2" Height="4" RadiusX="1" RadiusY="1" Margin="1,0" Fill="Gray"/><Rectangle Name="SmallBar1" Width="2" Height="4" RadiusX="1" RadiusY="1" Margin="1,0" Fill="Gray"/><Rectangle Name="SmallBar2" Width="2" Height="4" RadiusX="1" RadiusY="1" Margin="1,0" Fill="Gray"/><Rectangle Name="SmallBar3" Width="2" Height="4" RadiusX="1" RadiusY="1" Margin="1,0" Fill="Gray"/><Rectangle Name="SmallBar4" Width="2" Height="4" RadiusX="1" RadiusY="1" Margin="1,0" Fill="Gray"/></StackPanel></Grid>'
$compactHome=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $homeXaml))
foreach($name in @('CompactArt','SmallBar0','SmallBar1','SmallBar2','SmallBar3','SmallBar4')){$window.RegisterName($name,$compactHome.FindName($name))}
[void]$Pill.Child.Children.Add($compactHome)
[xml]$prayerHomeXaml='<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Margin="34,8" Visibility="Collapsed"><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="54"/><ColumnDefinition Width="*"/><ColumnDefinition Width="54"/></Grid.ColumnDefinitions><TextBlock Name="HomePrayerName" FontWeight="SemiBold" FontSize="13" Foreground="#BBBBBB" VerticalAlignment="Center" Margin="0,0,15,0"/><TextBlock Name="HomePrayerStart" Grid.Column="1" FontSize="13" Foreground="White" VerticalAlignment="Center"/><ProgressBar Name="HomePrayerProgress" Grid.Column="2" Minimum="0" Maximum="1" Height="4" Background="#303030" BorderThickness="0" Margin="6,0,15,0" VerticalAlignment="Center"><ProgressBar.Foreground><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#4DE54D" Offset="0"/><GradientStop Color="#E5E54D" Offset=".5"/><GradientStop Color="#E54D4D" Offset="1"/></LinearGradientBrush></ProgressBar.Foreground></ProgressBar><TextBlock Name="HomePrayerEnd" Grid.Column="3" FontSize="13" Foreground="White" VerticalAlignment="Center" TextAlignment="Right"/></Grid>'
$prayerHome=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $prayerHomeXaml))
[void]$Pill.Child.Children.Add($prayerHome)
$compact=$window
. (Join-Path $PSScriptRoot 'Calendar-Island.ps1')
. (Join-Path $PSScriptRoot 'Focus-Island.ps1')
. (Join-Path $PSScriptRoot 'Island-Settings.ps1')
$window.FindName('SettingsButton').Template=$template
$window.FindName('SettingsButton').Cursor=[Windows.Input.Cursors]::Hand
$window.FindName('SettingsButton').Add_Click({Show-IslandSettings})
[xml]$tabMarkup='<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" CornerRadius="9"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border></ControlTemplate>'
$script:panelTabTemplate=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $tabMarkup))
# One content layer plus a temporary bitmap of the outgoing contents.
# The black surface remains the same panel throughout the transition.
$script:contentLayer=$Pill.Child
$Pill.Child=$null
$script:surfaceRoot=New-Object Windows.Controls.Grid
$script:surfaceRoot.ClipToBounds=$true
$script:surfaceRoot.HorizontalAlignment='Left';$script:surfaceRoot.VerticalAlignment='Top'
$script:contentLayer.ClipToBounds=$true
$Content.ClipToBounds=$true
$Pill.Child=$script:surfaceRoot
$script:surfaceRoot.Width=$Pill.Width;$script:surfaceRoot.Height=$Pill.Height
[void]$script:surfaceRoot.Children.Add($script:contentLayer)
$script:contentTransition=[pscustomobject]@{Epoch=0;Snapshot=$null}
function Begin-ContentTransition {
  $state=$script:contentTransition;$state.Epoch++
  $holder=$script:surfaceRoot;$layer=$script:contentLayer
  $image=$null
  if($window.IsVisible -and $window.Opacity -gt 0 -and $holder.ActualWidth -gt 1 -and $holder.ActualHeight -gt 1){
    try{
      $dpi=[Windows.Media.VisualTreeHelper]::GetDpi($window)
      $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int][math]::Ceiling($holder.ActualWidth),[int][math]::Ceiling($holder.ActualHeight),96,96,[Windows.Media.PixelFormats]::Pbgra32)
      $bitmap.Render($holder);$bitmap.Freeze()
      $image=New-Object Windows.Controls.Image
      $image.Source=$bitmap;$image.Width=$holder.ActualWidth;$image.Height=$holder.ActualHeight
      $image.HorizontalAlignment='Center';$image.VerticalAlignment='Center';$image.IsHitTestVisible=$false
      $image.ClipToBounds=$true
      $image.Clip=[Windows.Media.RectangleGeometry]::new([Windows.Rect]::new(0,0,$holder.ActualWidth,$holder.ActualHeight))
    }catch{}
  }
  if($state.Snapshot){[void]$holder.Children.Remove($state.Snapshot)}
  $state.Snapshot=$image
  if($image){[void]$holder.Children.Add($image)}
  $layer.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$layer.Opacity=1;$layer.Effect=$null
}
function Start-ContentTransition {
  $state=$script:contentTransition;$layer=$script:contentLayer;$holder=$script:surfaceRoot
  if(-not $state.Snapshot){return}
  $snapshot=$state.Snapshot;$epoch=$state.Epoch
  $outBlur=New-Object Windows.Media.Effects.BlurEffect;$snapshot.Effect=$outBlur
  Animate $outBlur ([Windows.Media.Effects.BlurEffect]::RadiusProperty) 6 .18
  Animate $snapshot ([Windows.UIElement]::OpacityProperty) 0 .24
  $inBlur=New-Object Windows.Media.Effects.BlurEffect;$inBlur.Radius=6;$layer.Effect=$inBlur;$layer.Opacity=0
  $sharp=New-Object Windows.Media.Animation.DoubleAnimation
  $sharp.From=6;$sharp.To=0;$sharp.BeginTime=[timespan]::FromSeconds(.04);$sharp.Duration=[Windows.Duration]::new([timespan]::FromSeconds(.25))
  $ease=New-Object Windows.Media.Animation.CubicEase;$ease.EasingMode='EaseOut';$sharp.EasingFunction=$ease
  $sharp.Add_Completed(({
    if($state.Epoch -ne $epoch){return}
    $layer.Effect=$null
    [void]$holder.Children.Remove($snapshot);$state.Snapshot=$null
  }).GetNewClosure())
  $inBlur.BeginAnimation([Windows.Media.Effects.BlurEffect]::RadiusProperty,$sharp)
  $reveal=New-Object Windows.Media.Animation.DoubleAnimation
  $reveal.From=0;$reveal.To=1;$reveal.BeginTime=[timespan]::FromSeconds(.04);$reveal.Duration=[Windows.Duration]::new([timespan]::FromSeconds(.25));$reveal.EasingFunction=$ease
  $layer.BeginAnimation([Windows.UIElement]::OpacityProperty,$reveal)
}

function Update-PrayerHome {
  $file=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\Rainmeter\Skins\SariyerWidgets\@Resources\PrayerHome.txt'
  if(Test-Path -LiteralPath $file){
    try{$values=[IO.File]::ReadAllLines($file)}catch [System.IO.IOException]{return}
    $progressValue=0.0
    if($values.Count -ge 4 -and [double]::TryParse($values[3],[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$progressValue)){
      $script:currentPrayerName=$values[0]
      Update-PrayerHighlight
      $prayerHome.FindName('HomePrayerName').Text=$values[0]
      $prayerHome.FindName('HomePrayerStart').Text=$values[1]
      $prayerHome.FindName('HomePrayerEnd').Text=$values[2]
      $prayerHome.FindName('HomePrayerProgress').Value=$progressValue
      $prayerHome.FindName('HomePrayerName').Foreground=$script:systemAccentBrush
    }
  }
}
function Update-PrayerHighlight {
  $current=$script:currentPrayerName
  if($current -eq 'Last third'){$current='Last third begins'}
  foreach($row in $prayerRows.Children){
    $active=$script:islandSettings.prayerHighlight -and ([string]$row.Tag -eq $current)
    foreach($text in $row.Children){
      $text.Foreground=if($active){$script:systemAccentBrush}elseif($text.Tag -eq 'time'){$script:uiPrimary}else{$script:uiPrimary}
      $text.FontWeight=if($active){[Windows.FontWeights]::SemiBold}else{[Windows.FontWeights]::Normal}
    }
  }
}
function Resize-Island([double]$width,[double]$height) {
  Set-IslandSize
  if($window.IsVisible -and $script:targetWidth -eq $width -and $script:targetHeight -eq $height){return}
  $script:targetWidth=$width;$script:targetHeight=$height
  if($script:slideNotification -or -not $window.IsVisible){
    $Pill.BeginAnimation([Windows.FrameworkElement]::WidthProperty,$null);$Pill.BeginAnimation([Windows.FrameworkElement]::HeightProperty,$null)
    $Pill.Width=$width;$Pill.Height=$height;return
  }
  Animate $Pill ([Windows.FrameworkElement]::WidthProperty) $width .40
  Animate $Pill ([Windows.FrameworkElement]::HeightProperty) $height .40
}
function Update-DesktopVisibility {
  [IslandWindowStyle]::CompactWidth=if((Get-HomePanel) -eq 'Player'){296}elseif((Get-HomePanel) -eq 'Focus'){336}elseif((Get-HomePanel) -eq 'Calendar'){336}else{428}
  [IslandWindowStyle]::CompactWidth*=Get-IslandScale
  [IslandWindowStyle]::CompactHeight=if((Get-HomePanel) -eq 'Player'){32}elseif((Get-HomePanel) -eq 'Focus'){48}elseif((Get-HomePanel) -eq 'Calendar'){38}else{47}
  [IslandWindowStyle]::CompactHeight*=Get-IslandScale
  $desktop=[IslandWindowStyle]::DesktopForeground()
  $show=$script:expanded -or $script:hoverPeek -or $script:hoverExiting -or $desktop
  if($desktop -and $show -and -not $script:expanded -and $window.Opacity -eq 0){
    # Prepare compact content before the hidden-to-desktop entrance.
    $Pill.BeginAnimation([Windows.FrameworkElement]::WidthProperty,$null)
    $Pill.BeginAnimation([Windows.FrameworkElement]::HeightProperty,$null)
    $Pill.Width=if((Get-HomePanel) -eq 'Player'){296.0}elseif((Get-HomePanel) -eq 'Focus'){336}elseif((Get-HomePanel) -eq 'Calendar'){336.0}else{428.0}
    $Pill.Height=if((Get-HomePanel) -eq 'Player'){32.0}elseif((Get-HomePanel) -eq 'Focus'){48}elseif((Get-HomePanel) -eq 'Calendar'){38.0}else{47.0}
    $Pill.Child.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$Pill.Child.Opacity=1
    $window.UpdateLayout()
    $slide.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$null)
    $slide.Y=-($Pill.Height+2)
    Animate $slide ([Windows.Media.TranslateTransform]::YProperty) 0 .45
  }
  $window.Opacity=if($show){1}else{0}
  $window.IsHitTestVisible=$show
  if(-not $script:expanded){$window.Topmost=([bool]$script:hoverPeek -or [bool]$script:hoverExiting)}
}
function Get-CloseMotion([bool]$expanded,[bool]$openedOverApp,[bool]$desktop) {
  if($expanded -and ($openedOverApp -or -not $desktop)){return 'Slide'}
  return 'Resize'
}
function Restore-Home([double]$fromWidth=0) {
  Set-IslandSize
  Set-IslandTextEditing $false
  if((Get-CloseMotion ([bool]$script:expanded) ([bool]$script:openedOverApp) ([IslandWindowStyle]::DesktopForeground())) -eq 'Slide'){
    if($script:closing){return}
    $script:closing=$true
    $exit=New-Object Windows.Media.Animation.DoubleAnimation
    $exit.To=-($Pill.ActualHeight+2);$exit.Duration=[Windows.Duration]::new([timespan]::FromSeconds(.40))
    $ease=New-Object Windows.Media.Animation.CubicEase;$ease.EasingMode='EaseInOut';$exit.EasingFunction=$ease
    $exit.Add_Completed({
      if($script:closing){
        $window.Opacity=0;$script:expanded=$false;$script:closing=$false;$script:slideNotification=$false
        Restore-Home
      }
    })
    $slide.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$exit)
    return
  }
  Begin-ContentTransition
  $script:outsideDismissPending=$false
  $script:presentationKey='compact'
  $script:slideNotification=$false;$script:openedOverApp=$false
  $script:expanded=$false;$script:closing=$false;$script:notification=$false
  $script:view=Get-HomePanel
  $window.FindName('PanelHeader').Visibility='Collapsed'
  $Content.Visibility='Collapsed';$prayerView.Visibility='Collapsed';$calendarView.Visibility='Collapsed';$calendarNotice.Visibility='Collapsed';$focusView.Visibility='Collapsed';$focusNotice.Visibility='Collapsed';$script:prayerNotice.Visibility='Collapsed'
  $compactHome.Visibility=if((Get-HomePanel) -eq 'Player'){'Visible'}else{'Collapsed'}
  $prayerHome.Visibility=if((Get-HomePanel) -eq 'Prayer'){'Visible'}else{'Collapsed'}
  $calendarHome.Visibility=if((Get-HomePanel) -eq 'Calendar'){'Visible'}else{'Collapsed'}
  $focusHome.Visibility=if((Get-HomePanel) -eq 'Focus'){'Visible'}else{'Collapsed'}
  Update-PrayerHome
  $width=if((Get-HomePanel) -eq 'Player'){296.0}elseif((Get-HomePanel) -eq 'Focus'){336}elseif((Get-HomePanel) -eq 'Calendar'){336.0}else{428.0}
  $height=if((Get-HomePanel) -eq 'Player'){32.0}elseif((Get-HomePanel) -eq 'Focus'){48}elseif((Get-HomePanel) -eq 'Calendar'){38.0}else{47.0}
  $window.Width=480*(Get-IslandScale);$window.Height=330*(Get-IslandScale);$window.Top=0
  $window.Left=([Windows.SystemParameters]::PrimaryScreenWidth-$window.Width)/2
  $slide.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$null);$slide.Y=0
  if($window.Opacity -eq 0){
    $Pill.BeginAnimation([Windows.FrameworkElement]::WidthProperty,$null)
    $Pill.BeginAnimation([Windows.FrameworkElement]::HeightProperty,$null)
    $Pill.Width=$width;$Pill.Height=$height
    $script:targetWidth=$width;$script:targetHeight=$height
    $Pill.Child.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$Pill.Child.Opacity=1
  }else{Resize-Island $width $height}
  Update-DesktopVisibility
  if(-not $window.IsVisible){$window.Topmost=$false;$window.Show()}
  Start-ContentTransition
  PrayerVisible $false
}
function Select-Panel($view,[bool]$save){
  Set-IslandTextEditing $false
  $key='expanded|'+$view+'|'+[string][bool]$script:notification
  if($script:expanded -and -not $script:closing -and $script:presentationKey -eq $key){return}
  $previousPanel=$script:view
  $script:presentationKey=$key
  if($script:closing -and $script:expanded){
    $script:closing=$false
    Animate $slide ([Windows.Media.TranslateTransform]::YProperty) 0 .30
  }
  Begin-ContentTransition
  $script:view=$view
  $compactHome.Visibility='Collapsed';$prayerHome.Visibility='Collapsed';$calendarHome.Visibility='Collapsed';$focusHome.Visibility='Collapsed'
  if($save){$script:defaultPanel=$view;[IO.File]::WriteAllText($script:defaultPanelPath,$view)}
  foreach($tab in $prayerTab,$playerTab,$calendarTab,$focusTab){$tab.Template=$template;$tab.Foreground=$script:uiPrimary;$tab.Cursor=[Windows.Input.Cursors]::Hand}
  $Content.Visibility=if($view -eq 'Player'){'Visible'}else{'Collapsed'}
  $prayerView.Visibility=if($view -eq 'Prayer' -and -not $script:notification){'Visible'}else{'Collapsed'}
  $calendarView.Visibility=if($view -eq 'Calendar' -and -not $script:notification){'Visible'}else{'Collapsed'}
  $script:prayerNotice.Visibility=if($view -eq 'Prayer' -and $script:notification){'Visible'}else{'Collapsed'}
  $calendarNotice.Visibility=if($view -eq 'Calendar' -and $script:notification){'Visible'}else{'Collapsed'}
  $focusView.Visibility=if($view -eq 'Focus' -and -not $script:notification){'Visible'}else{'Collapsed'}
  $focusNotice.Visibility=if($view -eq 'Focus' -and $script:notification){'Visible'}else{'Collapsed'}
  $focusTab.Content.Stroke=if($view -eq 'Focus'){$script:systemAccentBrush}else{$script:uiSecondary}
  if($view -eq 'Calendar'){Update-CalendarView -Force}
  $prayerTab.Foreground=if($view -eq 'Prayer'){$script:systemAccentBrush}else{$script:uiSecondary}
  $playerTab.Foreground=if($view -eq 'Player'){$script:systemAccentBrush}else{$script:uiSecondary}
  $calendarTab.Foreground=if($view -eq 'Calendar'){$script:systemAccentBrush}else{$script:uiSecondary}
  $panelNames=@('Prayer','Player','Calendar','Focus');$panelTabs=@($prayerTab,$playerTab,$calendarTab,$focusTab)
  for($i=0;$i -lt 4;$i++){$selected=$panelNames[$i] -eq $view;$panelTabs[$i].Template=$script:panelTabTemplate;$panelTabs[$i].Background=if($selected){[Windows.Media.BrushConverter]::new().ConvertFromString('#29292C')}else{[Windows.Media.Brushes]::Transparent};$panelTabs[$i].Foreground=if($selected){$script:uiPrimary}else{$script:uiSecondary}}
  $focusTab.Content.Stroke=if($view -eq 'Focus'){$script:uiPrimary}else{$script:uiSecondary}
  $window.FindName('PanelHeader').Visibility=if($script:notification){'Collapsed'}else{'Visible'}
  $window.FindName('DefaultToggle').IsChecked=($script:defaultPanel -eq $view)
  $Content.Margin=if($script:notification){[Windows.Thickness]::new(20,14,20,14)}else{[Windows.Thickness]::new(20,44,20,14)}
  # A stationary transparent canvas keeps the center fixed while the card resizes.
  $bodyWidth=if($view -eq 'Prayer'){330.0}elseif($view -eq 'Focus'){300.0}elseif($view -eq 'Calendar'){340.0}else{371.0}
  $outerWidth=$bodyWidth+36
  $height=if($script:notification -and $view -in @('Calendar','Focus','Prayer')){100}elseif($script:notification){160}elseif($view -eq 'Prayer'){310}elseif($view -eq 'Focus'){260}elseif($view -eq 'Calendar'){280}else{190}
  $window.Width=480;$window.Height=330
  $window.Left=([Windows.SystemParameters]::PrimaryScreenWidth-$window.Width)/2
  $Content.Width=$outerWidth-76
  Resize-Island $outerWidth $height
  Start-ContentTransition
  Animate-IslandPanelSwitch $previousPanel $view
  if($view -eq 'Prayer'){
    $data=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\Rainmeter\Skins\SariyerWidgets\@Resources\PrayerTimes.txt'
    $prayerRows.Children.Clear()
    if(Test-Path -LiteralPath $data){
      try{$lines=[IO.File]::ReadAllLines($data)}catch [System.IO.IOException]{$lines=@()};if($lines.Count -eq 0){return};$prayerDate.Text='Sarıyer · '+$lines[0]
      foreach($line in ($lines | Select-Object -Skip 1)){
        $parts=$line.Split('|');if($parts.Count -ne 2){continue};if(-not $script:islandSettings.prayerNight -and $parts[0] -in @('Islamic midnight','Last third begins')){continue}
        $row=New-Object Windows.Controls.DockPanel;$row.Tag=$parts[0];$row.Margin='0,0,0,9'
        $time=New-Object Windows.Controls.TextBlock;$time.Tag='time';$time.Text=$parts[1];$time.Foreground=$script:uiPrimary;$time.FontSize=14
        [Windows.Controls.DockPanel]::SetDock($time,'Right');[void]$row.Children.Add($time)
        $label=New-Object Windows.Controls.TextBlock;$label.Text=$parts[0];$label.Foreground=$script:uiPrimary;$label.FontSize=14;[void]$row.Children.Add($label)
        [void]$prayerRows.Children.Add($row)
      }
    }else{$prayerDate.Text='Prayer times unavailable'}
    Update-PrayerHome
    Update-PrayerHighlight
  }
  $script:deadline=[datetime]::Now.AddSeconds(10)
}
$prayerTab.Add_Click({Select-Panel 'Prayer' $false})
$playerTab.Add_Click({Select-Panel 'Player' $false})
$calendarTab.Add_Click({Select-Panel 'Calendar' $false})
$window.FindName('ClosePanel').Add_Click({$script:forceClose=$true;$script:deadline=[datetime]::MinValue})
$window.FindName('DefaultToggle').Add_Click({
  if($script:notification){return}
  if(-not $window.FindName('DefaultToggle').IsChecked){$window.FindName('DefaultToggle').IsChecked=($script:defaultPanel -eq $script:view);return}
  $chosen=$script:view
  $script:defaultPanel=$chosen;[IO.File]::WriteAllText($script:defaultPanelPath,$chosen)
})
$Pill.Add_MouseLeftButtonUp({if(-not $script:expanded){$script:notification=$false;$script:view=Get-HomePanel;Expand}})
Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;
public static class IslandPointer{
[StructLayout(LayoutKind.Sequential)] public struct Point{public int X,Y;}
[DllImport("user32.dll")]public static extern short GetAsyncKeyState(int key);
[DllImport("user32.dll")]public static extern bool GetCursorPos(out Point point);
}
"@
function Get-OutsideDismissDelay {
  if($script:observedTrackDelay){return [math]::Min(1.5,[math]::Max(.60,[double]$script:observedTrackDelay+.20))}
  return .60
}
function Request-OutsideFold {
  if(-not $script:expanded -or $script:closing){return}
  if(-not $script:notification){Restore-Home;return}
  # One outside click schedules dismissal; further clicks cannot postpone it.
  if(-not $script:forceClose){
    $script:outsideClickedAt=[datetime]::Now
    $script:outsideDismissPending=$true
    $outsideDeadline=$script:outsideClickedAt.AddSeconds((Get-OutsideDismissDelay))
    if($outsideDeadline -lt $script:deadline){$script:deadline=$outsideDeadline}
    $script:forceClose=$true
  }
}
function Update-HoverIntent([double]$now,[bool]$zone,[bool]$over,[bool]$desktop) {
  if(-not $script:islandSettings.hover -or $desktop -or $script:expanded){$script:hoverStart=$null;$script:hoverPeek=$false;$script:hoverLeave=$null;return}
  if($script:hoverPeek){
    if($zone -or $over){$script:hoverLeave=$null}
    elseif($null -eq $script:hoverLeave){$script:hoverLeave=$now}
    elseif($now-$script:hoverLeave -ge .6){$script:hoverPeek=$false;$script:hoverStart=$null}
  }elseif($zone){
    if($null -eq $script:hoverStart){$script:hoverStart=$now}
    elseif($now-$script:hoverStart -ge 1.0){$script:hoverPeek=$true;$script:hoverLeave=$null}
  }else{$script:hoverStart=$null}
}
$hoverClock=[Diagnostics.Stopwatch]::StartNew()
$navigationTimer=New-Object Windows.Threading.DispatcherTimer;$navigationTimer.Interval=[timespan]::FromMilliseconds(100)
$navigationTimer.Add_Tick({
  $hoverPoint=New-Object IslandPointer+Point;[void][IslandPointer]::GetCursorPos([ref]$hoverPoint)
  $position=$window.PointFromScreen([Windows.Point]::new($hoverPoint.X,$hoverPoint.Y))
  $onPanel=$Pill.PointFromScreen([Windows.Point]::new($hoverPoint.X,$hoverPoint.Y))
  $zone=($position.X -ge 160 -and $position.X -le 320 -and $position.Y -ge 0 -and $position.Y -le 10)
  $over=($onPanel.X -ge 0 -and $onPanel.X -le $Pill.ActualWidth -and $onPanel.Y -ge 0 -and $onPanel.Y -le $Pill.ActualHeight)
  $wasPeek=[bool]$script:hoverPeek
  Update-HoverIntent $hoverClock.Elapsed.TotalSeconds $zone $over ([IslandWindowStyle]::DesktopForeground())
  if($script:hoverPeek -and -not $wasPeek){
    $slide.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$null);$slide.Y=-($Pill.ActualHeight+2)
    Animate $slide ([Windows.Media.TranslateTransform]::YProperty) 0 .30
  }

  $desktopNow=[IslandWindowStyle]::DesktopForeground()
  if($script:hoverExiting -and ($desktopNow -or $script:expanded)){
    $script:hoverExiting=$false
    $slide.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$null);$slide.Y=0
  }elseif($script:hoverExiting -and ($zone -or $over)){
    $script:hoverExiting=$false;$script:hoverPeek=$true;$script:hoverLeave=$null
    Animate $slide ([Windows.Media.TranslateTransform]::YProperty) 0 .30
  }
  if($wasPeek -and -not $script:hoverPeek -and -not $script:expanded -and -not $desktopNow -and -not $script:hoverExiting){
    $script:hoverExiting=$true
    $outro=New-Object Windows.Media.Animation.DoubleAnimation
    $outro.To=-($Pill.ActualHeight+2);$outro.Duration=[Windows.Duration]::new([timespan]::FromSeconds(.30))
    $ease=New-Object Windows.Media.Animation.CubicEase;$ease.EasingMode='EaseInOut';$outro.EasingFunction=$ease
    $outro.Add_Completed({
      if($script:hoverExiting -and -not $script:hoverPeek -and -not $script:expanded){
        $script:hoverExiting=$false
        Update-DesktopVisibility
        $slide.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$null);$slide.Y=0
      }
    })
    $slide.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$outro)
  }
  Update-DesktopVisibility
  Update-SystemAccent
  Update-PrayerHome
  Update-CalendarView
  Update-FocusTimer
  Update-CalendarConnection
  Update-PrayerReminder
  Update-IslandTheme
  $window.FindName('SoundBars').Visibility=if($script:islandSettings.playerBars){'Visible'}else{'Collapsed'}
  $compactHome.FindName('CompactSoundBars').Visibility=if($script:islandSettings.playerBars){'Visible'}else{'Collapsed'}
  $Art.Visibility=if($script:islandSettings.playerArt){'Visible'}else{'Hidden'}
  $window.FindName('CompactArt').Visibility=if($script:islandSettings.playerArt){'Visible'}else{'Hidden'}
  $down=(([IslandPointer]::GetAsyncKeyState(1) -band 0x8000) -ne 0) -or (([IslandPointer]::GetAsyncKeyState(2) -band 0x8000) -ne 0)
  if($script:expanded -and $down -and -not $script:pointerWasDown){
    $point=New-Object IslandPointer+Point;[void][IslandPointer]::GetCursorPos([ref]$point)
    $local=$Pill.PointFromScreen([Windows.Point]::new($point.X,$point.Y))
    if($local.X -lt 0 -or $local.X -gt $Pill.ActualWidth -or $local.Y -lt 0 -or $local.Y -gt $Pill.ActualHeight){
      Request-OutsideFold
    }
  }
  $script:pointerWasDown=$down
  if($script:expanded -and -not $script:closing -and [datetime]::Now -gt $script:deadline){Restore-Home}
  $request=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\Rainmeter\Skins\SariyerWidgets\@Resources\PanelRequest.txt'
  if(Test-Path -LiteralPath $request){$requested=[IO.File]::ReadAllText($request).Trim();Remove-Item -LiteralPath $request;$script:notification=$false;$script:view=if($requested -in @('Prayer','Player','Calendar','Focus')){$requested}else{'Prayer'};Expand}
})
$navigationTimer.Start()
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
    $script:outsideDismissPending=$false;$script:hoverExiting=$false;$script:hoverPeek=$false;$script:forceClose=$false;$script:closing=$false;$script:expanded=$true
    $script:openedOverApp=-not [IslandWindowStyle]::DesktopForeground()
    $script:slideNotification=$script:notification -and $script:openedOverApp
    $slide.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$null)
    $slide.Y=if($script:slideNotification){-162}else{0}
    $window.Opacity=1;$window.IsHitTestVisible=$true;$window.Topmost=$true
    Select-Panel $script:view $false
    if($script:slideNotification){
      $window.UpdateLayout()
      $slide.Y=-($Pill.ActualHeight+2)
      Animate $slide ([Windows.Media.TranslateTransform]::YProperty) 0 .40
    }
    $script:deadline=[datetime]::Now.AddSeconds($script:islandSettings.duration)
}
function Update-TrackPresentation {
    if($script:outsideDismissPending -and $script:outsideClickedAt){
      $delay=([datetime]::Now-$script:outsideClickedAt).TotalSeconds
      if($delay -ge 0 -and $delay -le 2){$script:observedTrackDelay=[math]::Max([double]$script:observedTrackDelay,$delay)}
      $script:outsideDismissPending=$false
    }
    if($script:expanded){
        # Metadata replacement is not a presentation transition.
        # Keep existing music controls/art visible while new artwork loads.
        if($script:view -eq 'Player'){
            $script:deadline=[datetime]::Now.AddSeconds($script:islandSettings.duration)
            if($script:notification){
                $script:forceClose=$false
                if($script:closing){$script:closing=$false;Animate $slide ([Windows.Media.TranslateTransform]::YProperty) 0 .30}
            }
        }
        return
    }
    if(-not $script:islandSettings.songs){return}
    $script:notification=$true
    $script:view='Player'
    Expand
}
function Resolve-PlaybackState([bool]$actual) {
    if($script:playPending){
        $task=$script:playCommandTask
        $failed=$task -and ($task.IsFaulted -or $task.IsCanceled -or ($task.Status -eq 'RanToCompletion' -and -not $task.Result))
        if($failed -or [datetime]::Now -gt $script:playPendingUntil){$script:playPending=$false}
        elseif($actual -eq $script:desiredPlaying -and $task -and $task.Status -eq 'RanToCompletion'){$script:playPending=$false}
        else{return [bool]$script:desiredPlaying}
    }
    return $actual
}
function Send-Control($command){
    if(-not $script:active){return}
    $script:deadline=[datetime]::Now.AddSeconds($script:islandSettings.duration)
    if($command -eq 'Toggle'){
      if($script:playPending){return}
      $script:desiredPlaying=-not $script:displayedPlaying
      $script:playPending=$true;$script:playPendingUntil=[datetime]::Now.AddSeconds(3)
      $script:displayedPlaying=$script:desiredPlaying
      $PlayIcon.Data=if($script:desiredPlaying){$pauseGeometry}else{$playGeometry}
      try{
        $operation=if($script:desiredPlaying){$script:active.TryPlayAsync()}else{$script:active.TryPauseAsync()}
        $script:playCommandTask=$asTask.MakeGenericMethod([bool]).Invoke($null,@($operation))
      }catch{$script:playPending=$false}
    }else{
      $operation=if($command -eq 'Next'){$script:active.TrySkipNextAsync()}else{$script:active.TrySkipPreviousAsync()}
      $script:commandTask=$asTask.MakeGenericMethod([bool]).Invoke($null,@($operation))
    }
}
function Open-MediaSource {
  if(-not $script:active){return}
  $source=[string]$script:active.SourceAppUserModelId
  if(-not [IslandWindowStyle]::OpenSource($source,$Song.Text) -and $source.Contains('!')){
    Start-Process -FilePath explorer.exe -ArgumentList ('shell:AppsFolder\'+$source) -WindowStyle Hidden
  }
}
$Art.Cursor=[Windows.Input.Cursors]::Hand
$Art.ToolTip='Open playing app'
$Art.Add_MouseLeftButtonUp({param($sender,$eventArgs) $eventArgs.Handled=$true;Open-MediaSource})
$window.FindName('CompactArt').Cursor=[Windows.Input.Cursors]::Hand
$window.FindName('CompactArt').Add_MouseLeftButtonUp({param($sender,$eventArgs) $eventArgs.Handled=$true;Open-MediaSource})
function Set-SeekPreview([double]$fraction,[bool]$commit){
  if(-not $script:active){return}
  try{
    $timeline=$script:active.GetTimelineProperties()
    $start=[double]$timeline.StartTime.Ticks;$end=[double]$timeline.EndTime.Ticks
    if($end -le $start){return}
    $fraction=[math]::Max(0.0,[math]::Min(1.0,$fraction))
    $ticks=[long][math]::Round($start+($end-$start)*$fraction)
    $Progress.Value=$fraction
    $Elapsed.Text=TimeText (($ticks-$start)/10000000.0)
    $Remaining.Text='-'+(TimeText (($end-$ticks)/10000000.0))
    $script:seekUntil=[datetime]::Now.AddMilliseconds(900)
    if($commit){
      $info=$script:active.GetPlaybackInfo()
      if(-not $info.Controls.IsPlaybackPositionEnabled){return}
      $script:seekTask=$asTask.MakeGenericMethod([bool]).Invoke($null,@($script:active.TryChangePlaybackPositionAsync($ticks)))
      $script:deadline=[datetime]::Now.AddSeconds($script:islandSettings.duration)
    }
  }catch{}
}
$seekArea=$window.FindName('SeekArea')
$seekArea.Add_PreviewMouseLeftButtonDown({param($sender,$eventArgs)
  $eventArgs.Handled=$true;$script:seeking=$true;[void]$sender.CaptureMouse()
  Set-SeekPreview ($eventArgs.GetPosition($sender).X/$sender.ActualWidth) $false
})
$seekArea.Add_PreviewMouseMove({param($sender,$eventArgs)
  if($script:seeking){Set-SeekPreview ($eventArgs.GetPosition($sender).X/$sender.ActualWidth) $false}
})
$seekArea.Add_PreviewMouseLeftButtonUp({param($sender,$eventArgs)
  if($script:seeking){$eventArgs.Handled=$true;$script:seeking=$false;Set-SeekPreview ($eventArgs.GetPosition($sender).X/$sender.ActualWidth) $true;$sender.ReleaseMouseCapture()}
})
$seekArea.Add_LostMouseCapture({$script:seeking=$false})

# One routed event per physical press; keyboard activation uses the same handler.
foreach($button in $Previous,$Pause,$Next){$button.ClickMode='Press'}
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
 if($script:active){try{$isPlaying=[string]$script:active.GetPlaybackInfo().PlaybackStatus -eq 'Playing'}catch{$script:active=$null}}
 $isPlaying=Resolve-PlaybackState $isPlaying
 $script:displayedPlaying=$isPlaying
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
function Test-CurrentArtwork([string]$requestKey){return $requestKey -eq $script:currentArtworkKey}
function Test-PreviousArtwork([string]$signature,[string]$album,[string]$requestKey){
  $sharedAlbum=$album -and $album -eq $script:displayedArtworkAlbum
  return $signature -eq $script:displayedArtworkHash -and $requestKey -ne $script:displayedArtworkKey -and -not $sharedAlbum -and ([datetime]::UtcNow-$script:artChangedAt).TotalSeconds -lt 2
}
function TimeText($seconds) { $seconds=[math]::Max(0,[int][math]::Floor($seconds)); return ('{0}:{1:00}' -f [math]::Floor($seconds/60),($seconds%60)) }
$timer=New-Object Windows.Threading.DispatcherTimer
$timer.Interval=[timespan]::FromMilliseconds(100)
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
      $key=$properties.Title+'|'+$properties.Artist+'|'+$properties.AlbumTitle
      $mediaIdentity=$id+'|'+$key
      $playing=[string]$candidate.GetPlaybackInfo().PlaybackStatus -eq 'Playing'
      # Social pages often publish a tab title and browser icon as media metadata.
      # They must not generate song-change notifications or replace the music card.
      $browserSession=$id -match '(?i)chrome|msedge|firefox|brave|opera|browser'
      $socialTitle=$properties.Title -match '(?i)^\s*(\(\d+\)\s*)?(Instagram|Facebook|TikTok|X|Twitter)(\s*[-–|·].*)?\s*$'
      $genericTitle=$properties.Title -match '(?i)^\s*(Google Chrome|Chrome|Microsoft Edge|Mozilla Firefox|New Tab)\s*$'
      $eligible=-not ($browserSession -and ($socialTitle -or $genericTitle))
      if($eligible -and $properties.Title){$script:active=$candidate}
      if($properties.Title -and ($playing -or ($script:expanded -and $script:view -eq 'Player')) -and $eligible -and ($script:seen[$id] -ne $key -or $script:displayedMetadataIdentity -ne $mediaIdentity)) {
        $script:seen[$id]=$key;$script:displayedMetadataIdentity=$mediaIdentity; $script:active=$candidate
        $animateTrack=$script:expanded -and $script:view -eq 'Player'
        if($animateTrack){Begin-ContentTransition}
        $Song.Text=$properties.Title; $Artist.Text=$properties.Artist
        Update-TrackPresentation
        if($animateTrack){Start-ContentTransition}
      }
      if($eligible -and $properties.Title){
        if($script:currentArtworkKey -ne $mediaIdentity){
          $script:currentArtworkKey=$mediaIdentity;$script:artChangedAt=[datetime]::UtcNow
          $script:nextArtworkRead=[datetime]::UtcNow.AddMilliseconds(250)
          $Art.Source=$null;$compact.FindName('CompactArt').Source=$null
        }
        if(-not $script:artTask -and $properties.Thumbnail -and [datetime]::UtcNow -ge $script:nextArtworkRead){
          try{
            $script:artRequestKey=$mediaIdentity;$script:artRequestAlbum=[string]$properties.AlbumTitle
            $script:artTask=$asTask.MakeGenericMethod($streamType).Invoke($null,@($properties.Thumbnail.OpenReadAsync()))
          }catch{$script:artTask=$null}
          $interval=if(([datetime]::UtcNow-$script:artChangedAt).TotalSeconds -lt 8){.6}else{10}
          $script:nextArtworkRead=[datetime]::UtcNow.AddSeconds($interval)
        }
      }
    }
    if($script:artTask -and $script:artTask.IsCompleted){
      $reader=$null
      try{
        $stream=$script:artTask.GetAwaiter().GetResult()
        if(-not (Test-CurrentArtwork $script:artRequestKey)){return}
                        # WinRT returns a COM interface here; invoke its declared interface
            # explicitly so PowerShell can resolve the stream adapter.
            $inputType=[Windows.Storage.Streams.IInputStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
            $randomType=[Windows.Storage.Streams.IRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
            $input=$randomType.GetMethod('GetInputStreamAt').Invoke($stream,@([uint64]0))
            $adapter=[System.IO.WindowsRuntimeStreamExtensions].GetMethod('AsStreamForRead',[type[]]@($inputType))
            $reader=$adapter.Invoke($null,@($input))
            $memory=New-Object IO.MemoryStream; $reader.CopyTo($memory); $reader.Dispose(); $reader=$memory; $memory.Position=0
            $hashAlgorithm=[Security.Cryptography.SHA256]::Create()
            try{$signature=[Convert]::ToBase64String($hashAlgorithm.ComputeHash($memory.ToArray()))}finally{$hashAlgorithm.Dispose()}
            if(Test-PreviousArtwork $signature $script:artRequestAlbum $script:artRequestKey){$script:nextArtworkRead=[datetime]::UtcNow.AddMilliseconds(200);return}
            $image=New-Object Windows.Media.Imaging.BitmapImage
            $image.BeginInit(); $image.CacheOption='OnLoad'; $image.StreamSource=$reader; $image.EndInit(); $image.Freeze(); $side=[math]::Min($image.PixelWidth,$image.PixelHeight)
            $crop=[Windows.Int32Rect]::new([int][math]::Floor(($image.PixelWidth-$side)/2),[int][math]::Floor(($image.PixelHeight-$side)/2),$side,$side)
            $centered=[Windows.Media.Imaging.CroppedBitmap]::new($image,$crop);$centered.Freeze()
            if(-not (Test-CurrentArtwork $script:artRequestKey)){return}
            $Art.Source=$centered; $compact.FindName('CompactArt').Source=$centered
            $script:displayedArtworkKey=$script:artRequestKey;$script:displayedArtworkHash=$signature;$script:displayedArtworkAlbum=$script:artRequestAlbum
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
      }catch{}finally{if($reader){$reader.Dispose()};if($stream){try{$stream.Dispose()}catch{}};$script:artTask=$null}
    }
    if($script:expanded) {
      if($window.IsMouseOver -and -not $script:forceClose){$script:deadline=[datetime]::Now.AddSeconds($script:islandSettings.duration)}
      if($script:active) {
        $timeline=$script:active.GetTimelineProperties(); $duration=($timeline.EndTime-$timeline.StartTime).TotalSeconds
        $position=($timeline.Position-$timeline.StartTime).TotalSeconds
        # Position is a timestamped snapshot, not necessarily the current instant.
        if([string]$script:active.GetPlaybackInfo().PlaybackStatus -eq 'Playing'){
          $age=([DateTimeOffset]::UtcNow-[DateTimeOffset]$timeline.LastUpdatedTime).TotalSeconds
          if($age -ge 0 -and $age -le $duration){$position+=$age}
        }
        $position=[math]::Max(0.0,[math]::Min([double]$duration,[double]$position))
        # Icon state is written only by the visual clock and direct user action.
        if(-not $script:seeking -and (-not $script:seekUntil -or [datetime]::Now -gt $script:seekUntil)){
          $Elapsed.Text=TimeText $position; $Remaining.Text='-'+(TimeText ($duration-$position))
          $Progress.Value=if($duration -gt 0){[math]::Max(0.0,[math]::Min(1.0,$position/$duration))}else{0}
        }
      }
      if([datetime]::Now -gt $script:deadline -and -not $script:closing) {
        Restore-Home
      }
    }
 } catch {
    if($script:expanded){Restore-Home}
    $_.Exception.Message | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'Music-Island-error.log')
 }
})
. (Join-Path $PSScriptRoot 'Island-Swipe.ps1')
Restore-Home
try { $timer.Start(); [Windows.Threading.Dispatcher]::Run() }
finally { $navigationTimer.Stop(); $visualTimer.Stop(); $timer.Stop(); PrayerVisible $false; $mutex.ReleaseMutex(); $mutex.Dispose() }
