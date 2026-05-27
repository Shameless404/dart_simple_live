Write-Host "=== 内存监控 (每 3 秒刷新, Ctrl+C 退出) ===" -ForegroundColor Cyan
Write-Host "先记录主窗口基线..."
$baseline = $null
while ($true) {
  $procs = Get-Process -Name simple_live_app -ErrorAction SilentlyContinue
  Clear-Host
  Write-Host "=== simple_live_app 进程内存 (按启动时间排序) ===" -ForegroundColor Cyan
  Write-Host ("{0,-6} {1,-15} {2,-14} {3}" -f "PID", "WS(工作集)", "Private(私有)", "启动时间")
  Write-Host ("{0,-6} {1,-15} {2,-14} {3}" -f "----", "------------", "-------------", "----------")
  $procs = $procs | Sort-Object StartTime
  foreach ($p in $procs) {
    $ws = [math]::Round($p.WorkingSet64 / 1MB, 1)
    $priv = [math]::Round($p.PrivateMemorySize64 / 1MB, 1)
    Write-Host ("{0,-6} {1,-15} {2,-14} {3}" -f $p.Id, "$ws MB", "$priv MB", $p.StartTime.ToString("HH:mm:ss"))
  }
  Write-Host ""
  if ($procs.Count -ge 2) {
    $newProcs = $procs | Select-Object -Skip 1
    $totalNew = 0
    foreach ($np in $newProcs) {
      $totalNew += $np.PrivateMemorySize64
    }
    $avgNew = [math]::Round(($totalNew / $newProcs.Count) / 1MB, 1)
    Write-Host "子窗口数量: $($newProcs.Count) 个" -ForegroundColor Green
    Write-Host "子窗口平均私有内存: $avgNew MB" -ForegroundColor Green
  } else {
    Write-Host "暂无子窗口" -ForegroundColor Yellow
  }
  Start-Sleep -Seconds 3
}
