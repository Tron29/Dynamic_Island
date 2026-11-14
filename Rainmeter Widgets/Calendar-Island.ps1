# Calendar presentations share the existing island window and animation lifecycle.
[xml]$calendarMarkup=@'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Margin="38,48,38,18" Visibility="Collapsed">
<Grid.RowDefinitions><RowDefinition Height="45"/><RowDefinition Height="*"/></Grid.RowDefinitions>
<Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="30"/><ColumnDefinition Width="30"/><ColumnDefinition Width="30"/></Grid.ColumnDefinitions><StackPanel><TextBlock Name="CalendarDay" FontSize="18" Foreground="White"/><TextBlock Name="CalendarDate" FontSize="11" Foreground="#999999"/></StackPanel><Button Name="CalendarPrevious" Grid.Column="1" Content="‹"/><Button Name="CalendarToday" Grid.Column="2" Content="•"/><Button Name="CalendarNext" Grid.Column="3" Content="›"/></Grid>
<ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel Name="CalendarRows"/></ScrollViewer>
</Grid>
'@
$calendarView=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $calendarMarkup))
[void]$Pill.Child.Children.Add($calendarView)
[xml]$calendarCompactMarkup=@'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Margin="30,7" Visibility="Collapsed"><Grid.ColumnDefinitions><ColumnDefinition Width="29"/><ColumnDefinition Width="*"/><ColumnDefinition Width="65"/></Grid.ColumnDefinitions><Viewbox Width="18" Height="18" HorizontalAlignment="Left"><Path Stroke="#BBBBBB" StrokeThickness="1.8" Fill="Transparent" Data="M 3,5 L 21,5 L 21,23 L 3,23 Z M 7,2 L 7,8 M 17,2 L 17,8 M 3,11 L 21,11"/></Viewbox><TextBlock Name="CalendarHomeTitle" Grid.Column="1" FontSize="12" Foreground="White" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/><TextBlock Name="CalendarHomeTime" Grid.Column="2" FontSize="11" Foreground="#AAAAAA" VerticalAlignment="Center" TextAlignment="Right"/></Grid>
'@
$calendarHome=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $calendarCompactMarkup))
[void]$Pill.Child.Children.Add($calendarHome)
[xml]$calendarNoticeMarkup=@'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Margin="38,20" Visibility="Collapsed"><Grid.ColumnDefinitions><ColumnDefinition Width="32"/><ColumnDefinition Width="*"/><ColumnDefinition Width="58"/></Grid.ColumnDefinitions><Viewbox Width="20" Height="20" HorizontalAlignment="Left"><Path Stroke="#BBBBBB" StrokeThickness="1.8" Fill="Transparent" Data="M 3,5 L 21,5 L 21,23 L 3,23 Z M 7,2 L 7,8 M 17,2 L 17,8 M 3,11 L 21,11"/></Viewbox><StackPanel Name="CalendarNoticeEvent" Grid.Column="1" VerticalAlignment="Center"><TextBlock Name="CalendarNoticeTitle" FontSize="15" Foreground="White" TextTrimming="CharacterEllipsis"/><TextBlock Name="CalendarNoticeDetail" FontSize="12" Foreground="#999999" Margin="0,5,0,0"/></StackPanel><TextBlock Name="CalendarNoticeCountdown" Grid.Column="2" FontSize="17" Foreground="#CCCCCC" VerticalAlignment="Center" TextAlignment="Right"/></Grid>
'@
$calendarNotice=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $calendarNoticeMarkup))
[void]$Pill.Child.Children.Add($calendarNotice)
$script:calendarSelected=[datetime]::UtcNow.AddHours(3).Date
$script:calendarReminded=@{}
foreach($name in 'CalendarPrevious','CalendarToday','CalendarNext'){
  $button=$calendarView.FindName($name);$button.Template=$template;$button.Foreground=$script:uiSecondary;$button.Cursor=[Windows.Input.Cursors]::Hand;$button.FontSize=20
}
$calendarView.FindName('CalendarPrevious').Add_Click({$script:calendarSelected=$script:calendarSelected.AddDays(-1);Update-CalendarView -Force})
$calendarView.FindName('CalendarNext').Add_Click({$script:calendarSelected=$script:calendarSelected.AddDays(1);Update-CalendarView -Force})
$calendarView.FindName('CalendarToday').Add_Click({$script:calendarSelected=[datetime]::UtcNow.AddHours(3).Date;Update-CalendarView -Force})
function Open-IslandCalendarEvent($event){
  if(-not $event){return}
  $day=[DateTimeOffset]::FromUnixTimeMilliseconds([long]$event.start).UtcDateTime.AddHours(3).ToString('yyyy/MM/dd')
  $url='https://calendar.google.com/calendar/u/0/r/day/'+$day
  if($event.url){$parsed=$null;if([uri]::TryCreate([string]$event.url,[UriKind]::Absolute,[ref]$parsed) -and $parsed.Scheme -eq 'https' -and $parsed.Host -eq 'calendar.google.com'){$url=$parsed.AbsoluteUri}}
  Start-Process -FilePath $url
}
$calendarNotice.Cursor=[Windows.Input.Cursors]::Hand
$calendarNotice.Add_MouseLeftButtonUp({param($sender,$eventArgs) $eventArgs.Handled=$true;Open-IslandCalendarEvent $script:calendarNextEvent})
function Calendar-Clock($milliseconds){return [DateTimeOffset]::FromUnixTimeMilliseconds([long]$milliseconds).UtcDateTime.AddHours(3).ToString('HH:mm')}
function Update-CalendarView([switch]$Force){
  if(-not $Force -and $script:calendarNextRead -and [datetime]::Now -lt $script:calendarNextRead){return}
  $script:calendarNextRead=[datetime]::Now.AddSeconds(2)
  $file=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\calendar-snapshot.js'
  if(Test-Path -LiteralPath $file){
    try{
      $raw=[IO.File]::ReadAllText($file)
      if($raw.StartsWith('receiveCalendarData(')){
        $json=$raw.Substring(20).Trim();$json=$json.TrimEnd(';').TrimEnd(')')
        $script:calendarSnapshot=$json | ConvertFrom-Json
      }
    }catch{}
  }
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();$today=[datetime]::UtcNow.AddHours(3).Date
  $next=$null
  if($script:calendarSnapshot.dates){
    foreach($offset in 0..7){
      $property=$script:calendarSnapshot.dates.PSObject.Properties[$today.AddDays($offset).ToString('yyyy-MM-dd')]
      if($property){foreach($event in @($property.Value)){
        if(-not $event.allDay -and [long]$event.end -gt $now -and (-not $next -or [long]$event.start -lt [long]$next.start)){$next=$event}
      }}
    }
  }
  $script:calendarNextEvent=$next
  $calendarHome.FindName('CalendarHomeTitle').Text=if($next){$next.title}else{'No upcoming events'}
  $minutes=if($next){[math]::Max(0,[int][math]::Ceiling(([long]$next.start-$now)/60000.0))}else{0}
  $calendarHome.FindName('CalendarHomeTime').Text=if(-not $next){''}elseif($next.start -le $now){'Now'}elseif($minutes -lt 60){'in '+$minutes+' min'}else{Calendar-Clock $next.start}
  $calendarNotice.FindName('CalendarNoticeTitle').Text=if($next){$next.title}else{'Calendar'}
  $calendarNotice.FindName('CalendarNoticeDetail').Text=if($next){(Calendar-Clock $next.start)+'–'+(Calendar-Clock $next.end)}else{''}
  $calendarNotice.FindName('CalendarNoticeCountdown').Text=if($next){$minutes.ToString()+' min'}else{''}
  $date=$script:calendarSelected.ToString('yyyy-MM-dd')
  $viewKey=$date+'|'+[string]$script:calendarSnapshot.updated
  if($Force -or $script:calendarViewKey -ne $viewKey){
    $script:calendarViewKey=$viewKey
    $calendarView.FindName('CalendarDay').Text=if($script:calendarSelected -eq $today){'Today'}else{$script:calendarSelected.ToString('dddd')}
    $calendarView.FindName('CalendarDate').Text=$script:calendarSelected.ToString('dd MMMM yyyy')
    $rows=$calendarView.FindName('CalendarRows');$rows.Children.Clear()
    $property=if($script:calendarSnapshot.dates){$script:calendarSnapshot.dates.PSObject.Properties[$date]}else{$null}
    $events=if($property){@($property.Value)}else{@()}
    foreach($event in $events){
      $button=New-Object Windows.Controls.Button;$button.Template=$template;$button.Tag=$event;$button.Cursor=[Windows.Input.Cursors]::Hand;$button.HorizontalContentAlignment='Stretch';$button.Margin='0,0,0,5';$button.Height=49
      $grid=New-Object Windows.Controls.Grid
      $c1=New-Object Windows.Controls.ColumnDefinition;$c1.Width=[Windows.GridLength]::new(48);[void]$grid.ColumnDefinitions.Add($c1);[void]$grid.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))
      $time=New-Object Windows.Controls.TextBlock;$time.Text=if($event.allDay){'All day'}else{Calendar-Clock $event.start};$time.Foreground=$script:uiSecondary;$time.FontSize=11;$time.VerticalAlignment='Center';[void]$grid.Children.Add($time)
      $details=New-Object Windows.Controls.StackPanel;$details.VerticalAlignment='Center';[Windows.Controls.Grid]::SetColumn($details,1)
      $title=New-Object Windows.Controls.TextBlock;$title.Text=$event.title;$title.FontSize=14;$title.Foreground=$script:uiPrimary;$title.TextTrimming='CharacterEllipsis';[void]$details.Children.Add($title)
      if(-not $event.allDay){$sub=New-Object Windows.Controls.TextBlock;$sub.Text=(Calendar-Clock $event.start)+'–'+(Calendar-Clock $event.end);$sub.FontSize=11;$sub.Foreground=$script:uiSecondary;[void]$details.Children.Add($sub)}
      [void]$grid.Children.Add($details);$button.Content=$grid
      $button.Add_Click({param($sender,$eventArgs) Open-IslandCalendarEvent $sender.Tag})
      [void]$rows.Children.Add($button)
    }
    if($events.Count -eq 0){$empty=New-Object Windows.Controls.TextBlock;$empty.Text=if($script:calendarSnapshot){'No events on this date'}else{'Connect your calendar to see events'};$empty.Foreground=$script:uiSecondary;$empty.Margin='0,18,0,0';[void]$rows.Children.Add($empty)}
  }
  if($script:islandSettings.calendar -and $next -and $next.start -gt $now -and $minutes -le $script:islandSettings.calendarLead -and -not $script:expanded){
    $key=[string]$next.start+'|'+$next.title
    if(-not $script:calendarReminded.ContainsKey($key)){
      $script:calendarReminded[$key]=$true;$script:notification=$true;$script:view='Calendar';Expand;Play-IslandSound 'Calendar'
    }
  }
}
