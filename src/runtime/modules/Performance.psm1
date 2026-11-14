Set-StrictMode -Version 2
Import-Module (Join-Path $PSScriptRoot 'IO.psm1')

function Get-SyrinPerformanceSample {
  if(-not ('Syrin.PerformanceCounters' -as [type])){
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
namespace Syrin {
  public static class PerformanceCounters {
    [StructLayout(LayoutKind.Sequential)] struct Memory {
      public uint Length, Load;
      public ulong TotalPhysical, AvailablePhysical, TotalPage, AvailablePage, TotalVirtual, AvailableVirtual, Extended;
    }
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool GlobalMemoryStatusEx(ref Memory memory);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetSystemTimes(out long idle, out long kernel, out long user);
    [DllImport("kernel32.dll")] static extern ulong GetTickCount64();
    public static ulong[] Read() {
      var memory=new Memory { Length=(uint)Marshal.SizeOf(typeof(Memory)) };
      long idle, kernel, user;
      if(!GlobalMemoryStatusEx(ref memory) || !GetSystemTimes(out idle,out kernel,out user)) throw new Win32Exception(Marshal.GetLastWin32Error());
      return new [] { (ulong)idle, (ulong)(kernel+user), memory.AvailablePhysical, GetTickCount64() };
    }
  }
}
'@
  }
  $counters=[Syrin.PerformanceCounters]::Read()
  $timestamp=[Diagnostics.Stopwatch]::GetTimestamp()
  $processes=New-Object 'System.Collections.Generic.List[object]';$unavailable=0
  foreach($process in [Diagnostics.Process]::GetProcesses()){
    try {
      if($process.Id -eq 0){continue}
      $processes.Add([PSCustomObject]@{id=$process.Id;startedUtc=$process.StartTime.ToUniversalTime().ToString('o');name=$process.ProcessName;cpuSeconds=$process.TotalProcessorTime.TotalSeconds;privateBytes=$process.PrivateMemorySize64})
    } catch {$unavailable++} finally {$process.Dispose()}
  }
  return [PSCustomObject]@{sampledUtc=[DateTime]::UtcNow.ToString('o');timestamp=$timestamp;idleTicks=$counters[0];totalTicks=$counters[1];availableBytes=$counters[2];uptimeMs=$counters[3];logicalProcessors=[Environment]::ProcessorCount;processes=$processes.ToArray();unavailableProcesses=$unavailable}
}

function ConvertTo-SyrinPerformanceInterval($Before,$After) {
  $seconds=($After.timestamp-$Before.timestamp)/[double][Diagnostics.Stopwatch]::Frequency
  if($seconds -le 0 -or $Before.logicalProcessors -ne $After.logicalProcessors){throw 'Performance samples are not comparable.'}
  $total=$After.totalTicks-$Before.totalTicks;$idle=$After.idleTicks-$Before.idleTicks
  $cpu=$null
  if($total -gt 0 -and $idle -ge 0 -and $idle -le $total){$cpu=[math]::Round(100*(1-$idle/[double]$total),2)}
  $previous=@{};foreach($process in $Before.processes){$previous[([string]$process.id+':'+$process.startedUtc)]=$process}
  $rows=@(foreach($process in $After.processes){
    $key=[string]$process.id+':'+$process.startedUtc
    if(-not $previous.ContainsKey($key)){continue}
    $delta=$process.cpuSeconds-$previous[$key].cpuSeconds
    if($delta -lt 0){continue}
    [PSCustomObject]@{id=$process.id;startedUtc=$process.startedUtc;name=$process.name;cpuPercent=[math]::Round([math]::Min(100,100*$delta/$seconds/$After.logicalProcessors),2);privateBytes=$process.privateBytes}
  })
  return [PSCustomObject]@{sampledUtc=$After.sampledUtc;durationSeconds=[math]::Round($seconds,3);cpuPercent=$cpu;availableBytes=$After.availableBytes;uptimeMs=$After.uptimeMs;unavailableProcesses=$After.unavailableProcesses;processes=@($rows | Sort-Object cpuPercent -Descending | Select-Object -First 10)}
}

function Invoke-SyrinPerformance {
  param([ValidateRange(2,60)][int]$Seconds=30,[ValidateRange(1,5)][int]$IntervalSeconds=2,[string]$ContextLabel='')
  $before=Get-SyrinPerformanceSample;$timer=[Diagnostics.Stopwatch]::StartNew()
  $samples=New-Object 'System.Collections.Generic.List[object]'
  while($timer.Elapsed.TotalSeconds -lt $Seconds){
    $wait=[math]::Min($IntervalSeconds*1000,($Seconds-$timer.Elapsed.TotalSeconds)*1000)
    if($wait -lt 100){break}
    Start-Sleep -Milliseconds ([int]$wait)
    $after=Get-SyrinPerformanceSample
    $samples.Add((ConvertTo-SyrinPerformanceInterval $before $after));$before=$after
  }
  $valid=@($samples | Where-Object {$null -ne $_.cpuPercent})
  $weight=0.0;$weightedCpu=0.0
  foreach($sample in $valid){$weight+=$sample.durationSeconds;$weightedCpu+=$sample.cpuPercent*$sample.durationSeconds}
  $mean=if($weight -gt 0){[math]::Round($weightedCpu/$weight,2)}else{$null}
  return [PSCustomObject]@{method='windows-cpu-delta-v1';requestedSeconds=$Seconds;intervalSeconds=$IntervalSeconds;contextLabel=$ContextLabel;sampleCount=$samples.Count;meanCpuPercent=$mean;peakCpuPercent=$(if($valid.Count){($valid|Measure-Object cpuPercent -Maximum).Maximum}else{$null});minimumAvailableBytes=$(if($samples.Count){($samples|Measure-Object availableBytes -Minimum).Minimum}else{$null});logicalProcessors=$before.logicalProcessors;samples=$samples.ToArray()}
}

Export-ModuleMember -Function Invoke-SyrinPerformance,ConvertTo-SyrinPerformanceInterval
