#!/system/bin/sh
# service.sh
# Applied late in boot (post boot_completed) to ensure Qualcomm and Android init scripts do not overwrite settings.

# Wait for boot completion
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 1
done

# Wait for ActivityManager and init.bullhead.rc on property:sys.boot_completed=1 triggers to settle
sleep 15

# 1. Interactive CPU Governor Optimization (tuned for 4x Cortex-A53 cores)
CPU0_INTERACTIVE="/sys/devices/system/cpu/cpu0/cpufreq/interactive"
if [ -d "$CPU0_INTERACTIVE" ]; then
  echo 85 > "$CPU0_INTERACTIVE/go_hispeed_load"
  echo 1248000 > "$CPU0_INTERACTIVE/hispeed_freq"
  echo "20000 1248000:40000" > "$CPU0_INTERACTIVE/above_hispeed_delay"
  echo "70 600000:80 960000:85 1248000:90" > "$CPU0_INTERACTIVE/target_loads"
  echo 40000 > "$CPU0_INTERACTIVE/min_sample_time"
  echo 20000 > "$CPU0_INTERACTIVE/timer_rate"
  echo 1 > "$CPU0_INTERACTIVE/io_is_busy"
fi

# Restrict Qualcomm msm_performance framework strictly to stable cores 0-3
if [ -f "/sys/module/msm_performance/parameters/managed_cpus" ]; then
  echo "0-3" > /sys/module/msm_performance/parameters/managed_cpus 2>/dev/null || true
fi

# 2. Block I/O Subsystem Tuning (Storage & Device Mapper Encrypted Data)
for blk in /sys/block/mmcblk0 /sys/block/dm-*; do
  if [ -d "$blk/queue" ]; then
    echo deadline > "$blk/queue/scheduler" 2>/dev/null || true
    echo 512 > "$blk/queue/read_ahead_kb" 2>/dev/null || true
    echo 2 > "$blk/queue/rq_affinity" 2>/dev/null || true
    echo 0 > "$blk/queue/iostats" 2>/dev/null || true
  fi
done

# 3. Virtual Memory & ZRAM (1GB LZ4 compressed swap)
if [ -b "/dev/block/zram0" ]; then
  CUR_SIZE=$(cat /sys/block/zram0/disksize 2>/dev/null || echo 0)
  if [ "$CUR_SIZE" -lt 1000000000 ]; then
    swapoff /dev/block/zram0 2>/dev/null || true
    echo 1 > /sys/block/zram0/reset 2>/dev/null || true
    echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || true
    echo 1073741824 > /sys/block/zram0/disksize 2>/dev/null || true
    mkswap /dev/block/zram0 2>/dev/null || true
    swapon /dev/block/zram0 2>/dev/null || true
  fi
fi

echo 100 > /proc/sys/vm/swappiness
echo 80 > /proc/sys/vm/vfs_cache_pressure
echo 15 > /proc/sys/vm/dirty_ratio
echo 5 > /proc/sys/vm/dirty_background_ratio

# 4. Low Memory Killer (LMK) Tuning
# Relax minfree thresholds and protect with read-only permissions against ActivityManager resets
LMK_MINFREE="/sys/module/lowmemorykiller/parameters/minfree"
if [ -f "$LMK_MINFREE" ]; then
  chmod 664 "$LMK_MINFREE" 2>/dev/null || true
  echo "15360,19200,23040,26880,34560,46080" > "$LMK_MINFREE"
  chmod 444 "$LMK_MINFREE" 2>/dev/null || true
fi
