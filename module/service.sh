#!/system/bin/sh
# service.sh
# Applied late in boot (post boot_completed) to ensure Qualcomm init scripts do not overwrite settings.

# Wait for boot completion
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 1
done

# Wait for Qualcomm post_boot scripts to finish
sleep 5

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

# 2. Block I/O Scheduler & Read-Ahead
if [ -d "/sys/block/mmcblk0/queue" ]; then
  echo deadline > /sys/block/mmcblk0/queue/scheduler
  echo 512 > /sys/block/mmcblk0/queue/read_ahead_kb
fi

# 3. Virtual Memory & ZRAM (Expand to 1GB LZ4 compressed swap)
if [ -b "/dev/block/zram0" ]; then
  swapoff /dev/block/zram0 2>/dev/null || true
  echo 1 > /sys/block/zram0/reset 2>/dev/null || true
  echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || true
  echo 1073741824 > /sys/block/zram0/disksize 2>/dev/null || true
  mkswap /dev/block/zram0 2>/dev/null || true
  swapon /dev/block/zram0 2>/dev/null || true
fi

echo 100 > /proc/sys/vm/swappiness
echo 80 > /proc/sys/vm/vfs_cache_pressure
echo 15 > /proc/sys/vm/dirty_ratio
echo 5 > /proc/sys/vm/dirty_background_ratio

# 4. Low Memory Killer (LMK) Tuning
# Relax minfree thresholds so background apps are not killed prematurely on a 2GB RAM device
if [ -f "/sys/module/lowmemorykiller/parameters/minfree" ]; then
  echo "15360,19200,23040,26880,34560,46080" > /sys/module/lowmemorykiller/parameters/minfree
fi
