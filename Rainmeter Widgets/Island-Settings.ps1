$script:islandSettingsPath=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\IslandSettings.json'
$script:islandSettings=@{hover=$true;songs=$true;calendar=$true;duration=6;prayerHighlight=$true;prayerNight=$true;calendarLead=10;focusNotice=$true}
try{if(Test-Path -LiteralPath $script:islandSettingsPath){$saved=[IO.File]::ReadAllText($script:islandSettingsPath)|ConvertFrom-Json;foreach($key in 'hover','songs','calendar','prayerHighlight','prayerNight','focusNotice'){if($null -ne $saved.$key){$script:islandSettings[$key]=[bool]$saved.$key}};foreach($key in 'duration','calendarLead'){$min=if($key -eq 'duration'){3}else{1};$max=if($key -eq 'duration'){12}else{30};if($saved.$key -ge $min -and $saved.$key -le $max){$script:islandSettings[$key]=[int]$saved.$key}}}}catch{}
function Save-IslandSettings {$script:islandSettings|ConvertTo-Json|Set-Content -LiteralPath $script:islandSettingsPath -Encoding UTF8}
function Add-SettingsRow($page,[string]$label,[string]$detail,$control){
  [Windows.Automation.AutomationProperties]::SetName($control,$label)
  $row=New-Object Windows.Controls.Grid;$row.Margin='0,0,0,20';[void]$row.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition));$column=New-Object Windows.Controls.ColumnDefinition;$column.Width=[Windows.GridLength]::new(80);[void]$row.ColumnDefinitions.Add($column)
  $text=New-Object Windows.Controls.StackPanel;$text.Margin='0,0,14,0';$title=New-Object Windows.Controls.TextBlock;$title.Text=$label;$title.FontSize=14;$title.Foreground=[Windows.Media.Brushes]::White;[void]$text.Children.Add($title)
  if($detail -like 'Sound can also*'){$sub=New-Object Windows.Controls.TextBlock;$sub.Text=$detail;$sub.FontSize=11;$sub.TextWrapping='Wrap';$sub.Foreground=[Windows.Media.Brushes]::Gray;$sub.Margin='0,6,0,0';[void]$text.Children.Add($sub)}
  [void]$row.Children.Add($text);$control.HorizontalAlignment='Right';$control.VerticalAlignment='Center';[Windows.Controls.Grid]::SetColumn($control,1);[void]$row.Children.Add($control);[void]$page.Children.Add($row)
}
function Add-SettingsSwitch($page,[string]$name,[string]$key,[string]$label,[string]$detail){
  $control=New-Object Windows.Controls.CheckBox;$control.IsChecked=$script:islandSettings[$key];$control.Tag=$key;$script:settingsWindow.RegisterName($name,$control)
  $control.Add_Click({param($sender,$eventArgs) $script:islandSettings[[string]$sender.Tag]=[bool]$sender.IsChecked;Save-IslandSettings;Update-SettingsSoundAvailability
    if($sender.Tag -in @('prayerHighlight','prayerNight')){Update-PrayerHighlight;if($script:expanded -and $script:view -eq 'Prayer'){$script:presentationKey='';Select-Panel 'Prayer' $false}}
  });Add-SettingsRow $page $label $detail $control
}
function Add-SettingsRange($page,[string]$name,[string]$key,[string]$label,[int]$min,[int]$max,[string]$unit){
  $wrap=New-Object Windows.Controls.StackPanel;$wrap.Margin='0,0,0,26';$line=New-Object Windows.Controls.DockPanel
  $value=New-Object Windows.Controls.TextBlock;$value.Text=[string]$script:islandSettings[$key]+' '+$unit;$value.Foreground=[Windows.Media.Brushes]::Gray;[Windows.Controls.DockPanel]::SetDock($value,'Right');[void]$line.Children.Add($value)
  $title=New-Object Windows.Controls.TextBlock;$title.Text=$label;$title.FontSize=14;[void]$line.Children.Add($title);[void]$wrap.Children.Add($line)
  $slider=New-Object Windows.Controls.Slider;$slider.Minimum=$min;$slider.Maximum=$max;$slider.TickFrequency=1;$slider.IsSnapToTickEnabled=$true;$slider.Value=$script:islandSettings[$key];$slider.Margin='0,15,0,0';$slider.Tag=@{key=$key;label=$value;unit=$unit};$script:settingsWindow.RegisterName($name,$slider)
  $slider.Add_ValueChanged({param($sender,$eventArgs) $script:islandSettings[$sender.Tag.key]=[int]$sender.Value;$sender.Tag.label.Text=[string][int]$sender.Value+' '+$sender.Tag.unit;Save-IslandSettings});[void]$wrap.Children.Add($slider);[void]$page.Children.Add($wrap)
}
. (Join-Path $PSScriptRoot 'Island-Preferences.ps1')
. (Join-Path $PSScriptRoot 'Island-Reminders.ps1')
function Show-IslandSettings {
  if($script:settingsWindow -and $script:settingsWindow.IsVisible){[void]$script:settingsWindow.Activate();return}
  [xml]$markup=@"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="Island Settings" Width="780" Height="780" WindowStartupLocation="CenterScreen" WindowStyle="None" AllowsTransparency="True" Background="Transparent" ResizeMode="NoResize" ShowInTaskbar="False" Topmost="True" Foreground="#EEEEEE" FontFamily="Segoe UI" FontSize="13">
<Window.Resources>
<Style TargetType="Button"><Setter Property="Background" Value="#18181A"/><Setter Property="Foreground" Value="#BBBBBB"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border Background="{TemplateBinding Background}" CornerRadius="10" Padding="12,10"><ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"/></Border></ControlTemplate></Setter.Value></Setter></Style>
<Style TargetType="CheckBox"><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="CheckBox"><Grid Width="34" Height="20"><Border Name="Track" Background="#303033" CornerRadius="10"/><Ellipse Name="Thumb" Width="16" Height="16" Fill="#DDDDDD" HorizontalAlignment="Left" Margin="2"/></Grid><ControlTemplate.Triggers><Trigger Property="IsChecked" Value="True"><Setter TargetName="Thumb" Property="HorizontalAlignment" Value="Right"/><Setter TargetName="Track" Property="Background" Value="{DynamicResource SystemAccentBrush}"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
<Style TargetType="Slider"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Slider"><Grid Height="22"><Border Height="3" Background="#282828" CornerRadius="2" VerticalAlignment="Center"/><Track Name="PART_Track"><Track.DecreaseRepeatButton><RepeatButton Command="Slider.DecreaseLarge" Opacity="0"/></Track.DecreaseRepeatButton><Track.Thumb><Thumb Width="12" Height="12"><Thumb.Template><ControlTemplate TargetType="Thumb"><Ellipse Fill="#CCCCCC"/></ControlTemplate></Thumb.Template></Thumb></Track.Thumb><Track.IncreaseRepeatButton><RepeatButton Command="Slider.IncreaseLarge" Opacity="0"/></Track.IncreaseRepeatButton></Track></Grid></ControlTemplate></Setter.Value></Setter></Style>
<Style TargetType="TextBox"><Setter Property="Foreground" Value="#DDDDDD"/><Setter Property="Background" Value="#18181A"/><Setter Property="BorderThickness" Value="0"/><Setter Property="CaretBrush" Value="#BBBBBB"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="TextBox"><Border Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}"><ScrollViewer Name="PART_ContentHost"/></Border></ControlTemplate></Setter.Value></Setter></Style>
<Style TargetType="ComboBox"><Setter Property="Foreground" Value="#DDDDDD"/><Setter Property="Background" Value="#18181A"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ComboBox"><Grid><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="24"/></Grid.ColumnDefinitions><Border Grid.ColumnSpan="2" Background="{TemplateBinding Background}" CornerRadius="8"/><ToggleButton Name="DropToggle" Grid.ColumnSpan="2" Focusable="False" IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}"><ToggleButton.Template><ControlTemplate TargetType="ToggleButton"><Border Background="Transparent"><Path HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,9,0" Stroke="#999999" StrokeThickness="1.4" Data="M 0,0 L 4,4 L 8,0"/></Border></ControlTemplate></ToggleButton.Template></ToggleButton><ContentPresenter Name="Selection" Margin="9,0,0,0" VerticalAlignment="Center" IsHitTestVisible="False" Content="{TemplateBinding SelectionBoxItem}"/><TextBox Name="PART_EditableTextBox" Margin="9,3,0,3" Foreground="{TemplateBinding Foreground}" Background="Transparent" Visibility="Collapsed" VerticalContentAlignment="Center"/><Popup Name="PART_Popup" Grid.ColumnSpan="2" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True"><Border Background="#19191C" CornerRadius="9" Padding="5" MinWidth="130"><ScrollViewer MaxHeight="210"><StackPanel IsItemsHost="True"/></ScrollViewer></Border></Popup></Grid><ControlTemplate.Triggers><Trigger Property="IsEditable" Value="True"><Setter TargetName="Selection" Property="Visibility" Value="Collapsed"/><Setter TargetName="PART_EditableTextBox" Property="Visibility" Value="Visible"/><Setter TargetName="DropToggle" Property="Grid.Column" Value="1"/><Setter TargetName="DropToggle" Property="Grid.ColumnSpan" Value="1"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
<Style TargetType="ComboBoxItem"><Setter Property="Foreground" Value="#DDDDDD"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ComboBoxItem"><Border Name="Choice" Background="Transparent" CornerRadius="6" Padding="9,6"><ContentPresenter/></Border><ControlTemplate.Triggers><Trigger Property="IsHighlighted" Value="True"><Setter TargetName="Choice" Property="Background" Value="#333336"/></Trigger><Trigger Property="IsSelected" Value="True"><Setter TargetName="Choice" Property="Background" Value="#29292D"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
<Style TargetType="ScrollBar"><Setter Property="Width" Value="6"/><Setter Property="Background" Value="Transparent"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollBar"><Track Name="PART_Track" IsDirectionReversed="True" Minimum="{TemplateBinding Minimum}" Maximum="{TemplateBinding Maximum}" ViewportSize="{TemplateBinding ViewportSize}" Value="{Binding Value, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}"><Track.Thumb><Thumb><Thumb.Template><ControlTemplate TargetType="Thumb"><Border Background="#444448" CornerRadius="3" Margin="1,0"/></ControlTemplate></Thumb.Template></Thumb></Track.Thumb></Track></ControlTemplate></Setter.Value></Setter></Style>
</Window.Resources>
<Border Background="Black" CornerRadius="26"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="178"/><ColumnDefinition/></Grid.ColumnDefinitions>
<StackPanel Margin="18,22,10,20"><TextBlock Text="Island" FontSize="18" FontWeight="Medium" Foreground="White" Margin="12,5,0,26"/><Button Name="GeneralTab" Content="General" Background="Transparent" HorizontalContentAlignment="Left" Margin="0,0,0,6"/><Button Name="PrayerTab" Content="Prayer" Background="Transparent" HorizontalContentAlignment="Left" Margin="0,0,0,6"/><Button Name="PlayerTab" Content="Player" Background="Transparent" HorizontalContentAlignment="Left" Margin="0,0,0,6"/><Button Name="CalendarTab" Content="Calendar" Background="Transparent" HorizontalContentAlignment="Left" Margin="0,0,0,6"/><Button Name="FocusTab" Content="Focus" Background="Transparent" HorizontalContentAlignment="Left"/></StackPanel>
<Grid Grid.Column="1" Margin="30,24,28,22"><Grid.RowDefinitions><RowDefinition Height="48"/><RowDefinition/><RowDefinition Height="24"/></Grid.RowDefinitions><TextBlock Name="SettingsTitle" Text="General" FontSize="18" FontWeight="Medium" VerticalAlignment="Top"/><Button Name="SettingsClose" HorizontalAlignment="Right" VerticalAlignment="Top" Width="36" Height="34" Background="Transparent"><Viewbox Width="12" Height="12"><Path Stroke="#888888" StrokeThickness="1.6" StrokeStartLineCap="Round" Data="M 2,2 L 14,14 M 14,2 L 2,14"/></Viewbox></Button>
<ScrollViewer Name="SettingsScroll" Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><Grid Name="SettingsBody"><StackPanel Name="GeneralPage"/><StackPanel Name="PrayerPage" Visibility="Collapsed"/><StackPanel Name="PlayerPage" Visibility="Collapsed"/><StackPanel Name="CalendarPage" Visibility="Collapsed"/><StackPanel Name="FocusPage" Visibility="Collapsed"/></Grid></ScrollViewer>
</Grid></Grid></Border></Window>
"@
  $script:settingsWindow=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $markup));$settings=$script:settingsWindow;$settings.Width=[math]::Min(780.0,[Windows.SystemParameters]::WorkArea.Width-40);$settings.Height=[math]::Min(780.0,[Windows.SystemParameters]::WorkArea.Height-24);$settings.Resources['SystemAccentBrush']=$script:systemAccentBrush
  $settings.FindName('SettingsClose').Add_Click({$script:settingsWindow.Close()})
  $settings.Add_MouseLeftButtonDown({param($sender,$eventArgs) if($eventArgs.OriginalSource -is [Windows.Controls.Border]){$sender.DragMove()}})
  foreach($name in 'General','Prayer','Player','Calendar','Focus'){$button=$settings.FindName($name+'Tab');$button.Tag=$name;$button.Add_Click({param($sender,$eventArgs) Select-IslandSettingsPage ([string]$sender.Tag)})}
  $sourceTabs=@{Prayer=$prayerTab;Player=$playerTab;Calendar=$calendarTab;Focus=$focusTab}
  foreach($name in 'General','Prayer','Player','Calendar','Focus'){
    $row=New-Object Windows.Controls.StackPanel;$row.Orientation='Horizontal'
    if($name -eq 'General'){$icon=New-Object Windows.Controls.TextBlock;$icon.FontFamily='Segoe MDL2 Assets';$icon.Text=[string][char]0xE713;$icon.FontSize=16;$icon.Width=18}
    else{$icon=[Windows.Markup.XamlReader]::Parse([Windows.Markup.XamlWriter]::Save($sourceTabs[$name].Content));$icon.Width=18;$icon.Height=18}
    $icon.VerticalAlignment='Center';$icon.Opacity=.85;[void]$row.Children.Add($icon)
    $label=New-Object Windows.Controls.TextBlock;$label.Text=$name;$label.Margin='10,0,0,0';$label.VerticalAlignment='Center';[void]$row.Children.Add($label)
    $settings.FindName($name+'Tab').Content=$row
  }
  Add-SettingsSwitch $settings.FindName('GeneralPage') 'SettingsHover' 'hover' 'Reveal on hover' 'Hold the pointer at the top center for one second.'
  foreach($name in 'Prayer','Player','Calendar','Focus'){
    $page=$settings.FindName($name+'Page');$pin=New-Object Windows.Controls.Button;$pin.Content=New-IslandPin ($script:defaultPanel -eq $name);$pin.Tag=$name;$pin.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#18181A');$settings.RegisterName($name+'Home',$pin)
    $pin.Add_Click({param($sender,$eventArgs) $script:defaultPanel=[string]$sender.Tag;[IO.File]::WriteAllText($script:defaultPanelPath,$script:defaultPanel);$window.FindName('DefaultToggle').IsChecked=($script:defaultPanel -eq $script:view);foreach($panel in 'Prayer','Player','Calendar','Focus'){$script:settingsWindow.FindName($panel+'Home').Content=New-IslandPin ($script:defaultPanel -eq $panel)};if(-not $script:expanded){Restore-Home}})
    Add-SettingsRow $page 'Home panel' 'Show this panel when no focus timer is active.' $pin
  }
  Add-SettingsSwitch $settings.FindName('PrayerPage') 'SettingsPrayerHighlight' 'prayerHighlight' 'Highlight current prayer' 'Use your system color for the active period.'
  Add-SettingsSwitch $settings.FindName('PrayerPage') 'SettingsPrayerNight' 'prayerNight' 'Night times' 'Show Islamic midnight and the last third of the night.'
  Add-SettingsSwitch $settings.FindName('PlayerPage') 'SettingsSongs' 'songs' 'Song notifications' 'Show a notification when the track changes.'
  Add-SettingsRange $settings.FindName('PlayerPage') 'SettingsDuration' 'duration' 'Notification duration' 3 12 's'
  Add-SettingsSwitch $settings.FindName('CalendarPage') 'SettingsCalendar' 'calendar' 'Event reminders' 'Show a notification before the next event.'

  Add-SettingsSwitch $settings.FindName('FocusPage') 'SettingsFocusNotice' 'focusNotice' 'Completion notification' 'Let me know when the focus timer finishes.'
  $hint=New-Object Windows.Controls.TextBlock;$hint.Text='';$hint.TextWrapping='Wrap';$hint.Foreground=[Windows.Media.Brushes]::Gray;$hint.FontSize=11;[void]$settings.FindName('FocusPage').Children.Add($hint)
  $summary=New-Object Windows.Controls.TextBlock;$summary.Text='';$summary.TextWrapping='Wrap';$summary.Foreground=[Windows.Media.Brushes]::Gray;$summary.FontSize=12;[void]$settings.FindName('GeneralPage').Children.Add($summary)
  Add-ExtendedSettings
  $script:settingsPage=$null;Select-IslandSettingsPage 'General';$settings.Show();[void]$settings.Activate()
}
function Select-IslandSettingsPage([string]$page){
  if($script:settingsPage -eq $page -and $script:settingsWindow.FindName($page+'Page').Visibility -eq 'Visible'){return}
  $script:settingsWindow.FindName('SettingsScroll').ScrollToTop()
  $script:settingsPage=$page
  foreach($name in 'General','Prayer','Player','Calendar','Focus'){
    $selected=$name -eq $page;$script:settingsWindow.FindName($name+'Page').Visibility=if($selected){'Visible'}else{'Collapsed'}
    $tab=$script:settingsWindow.FindName($name+'Tab');$tab.Background=if($selected){[Windows.Media.BrushConverter]::new().ConvertFromString('#202023')}else{[Windows.Media.Brushes]::Transparent};$tab.Foreground=if($selected){[Windows.Media.Brushes]::White}else{[Windows.Media.Brushes]::Gray}
    if($name -ne 'General'){$script:settingsWindow.FindName($name+'Home').Content=New-IslandPin ($script:defaultPanel -eq $name)}
  }
  $script:settingsWindow.FindName('SettingsTitle').Text=$page
  $incoming=$script:settingsWindow.FindName($page+'Page');$incoming.Opacity=0;Animate $incoming ([Windows.UIElement]::OpacityProperty) 1 .20
}
