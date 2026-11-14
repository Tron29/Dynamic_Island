Add-Type -Path (Join-Path $PSScriptRoot 'TouchpadSwipe.cs')
$script:islandSwipe=@{last=0.0;sum=0;triggered=$false}
function Process-IslandTouchpad([int]$delta,[double]$now){
  $state=$script:islandSwipe
  if($now-$state.last -gt .22){$state.sum=0;$state.triggered=$false}
  $state.last=$now
  if($state.triggered){return $false}
  if($state.sum -ne 0 -and [math]::Sign($state.sum) -ne [math]::Sign($delta)){$state.sum=0}
  $state.sum+=$delta
  if([math]::Abs($state.sum) -lt 40){return $false}
  $state.triggered=$true
  $target=Get-IslandSwipeTarget $script:view $state.sum
  Select-Panel $target $false
  Animate-IslandOffset $(if($state.sum -lt 0){-24}else{24})
  return $true
}
$script:touchpadClock=[Diagnostics.Stopwatch]::StartNew()
$script:touchpadTimer=New-Object Windows.Threading.DispatcherTimer;$script:touchpadTimer.Interval=[timespan]::FromMilliseconds(16)
$script:touchpadTimer.Add_Tick({
  $active=$script:expanded -and -not $script:notification -and -not $script:closing -and $window.Opacity -gt 0
  if($active -and $Pill.IsVisible){
    $origin=$Pill.PointToScreen([Windows.Point]::new(0,0));$end=$Pill.PointToScreen([Windows.Point]::new($Pill.ActualWidth,$Pill.ActualHeight))
    [IslandTouchpad]::Bounds($true,[int]$origin.X,[int]$origin.Y,[int]($end.X-$origin.X),[int]($end.Y-$origin.Y))
    while(($delta=[IslandTouchpad]::Pop()) -ne 0){[void](Process-IslandTouchpad $delta $script:touchpadClock.Elapsed.TotalSeconds)}
  }else{[IslandTouchpad]::Bounds($false,0,0,0,0);$script:islandSwipe.sum=0;$script:islandSwipe.triggered=$false}
})
$window.Add_Loaded({if([IslandTouchpad]::Start()){$script:touchpadTimer.Start()}})
$window.Add_Closed({$script:touchpadTimer.Stop();[IslandTouchpad]::Stop()})
function Get-IslandSwipeTarget([string]$current,[double]$distance){
  $panels=@('Prayer','Player','Calendar','Focus');$index=[array]::IndexOf($panels,$current);if($index -lt 0){$index=0}
  $step=if($distance -lt 0){-1}else{1};return $panels[($index+$step+4)%4]
}
function Animate-IslandPanelSwitch([string]$previous,[string]$next){
  if($previous -eq $next -or $script:notification){return}
  $panels=@('Prayer','Player','Calendar','Focus');$oldIndex=[array]::IndexOf($panels,$previous);$newIndex=[array]::IndexOf($panels,$next);if($oldIndex -lt 0 -or $newIndex -lt 0){return}
  Animate-IslandOffset $(if($newIndex -gt $oldIndex){24}else{-24})
}
function Animate-IslandOffset([double]$offset){
  if($script:contentLayer.RenderTransform -isnot [Windows.Media.TranslateTransform]){$script:contentLayer.RenderTransform=New-Object Windows.Media.TranslateTransform}
  $transform=$script:contentLayer.RenderTransform;$transform.BeginAnimation([Windows.Media.TranslateTransform]::XProperty,$null);$transform.X=$offset
  $animation=[Windows.Media.Animation.DoubleAnimation]::new(0,[timespan]::FromSeconds(.22));$animation.BeginTime=[timespan]::Zero
  $ease=New-Object Windows.Media.Animation.CubicEase;$ease.EasingMode='EaseOut';$animation.EasingFunction=$ease
  $transform.BeginAnimation([Windows.Media.TranslateTransform]::XProperty,$animation)
}
