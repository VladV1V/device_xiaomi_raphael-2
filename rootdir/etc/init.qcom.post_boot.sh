#! /vendor/bin/sh

# Copyright (c) 2012-2013, 2016-2018, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of The Linux Foundation nor
#       the names of its contributors may be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

target=`getprop ro.board.platform`

function configure_read_ahead_kb_values() {
    echo 512 > /sys/block/sda/bdi/read_ahead_kb
}

function configure_memory_parameters() {
    # Set Memory parameters.
    #
    # Set per_process_reclaim tuning parameters
    # All targets will use vmpressure range 50-70,
    # All targets will use 512 pages swap size.
    #
    # Set Low memory killer minfree parameters
    # 64 bit will use Google default LMK series.
    #
    # Set ALMK parameters (usually above the highest minfree values)
    # vmpressure_file_min threshold is always set slightly higher
    # than LMK minfree's last bin value for all targets. It is calculated as
    # vmpressure_file_min = (last bin - second last bin ) + last bin
    #
    # Set allocstall_threshold to 0 for all targets.
    #

    # Set Zram disk size=1GB for >=2GB Non-Go targets.
    echo 1073741824 > /sys/block/zram0/disksize
    echo lz4 > /sys/block/zram0/comp_algorithm
    mkswap /dev/block/zram0
    swapon -d -p 32758 /dev/block/zram0

    # Set allocstall_threshold to 0 for all targets.
    # Set swappiness to 100 for all targets
    echo 0 > /sys/module/vmpressure/parameters/allocstall_threshold
    echo 100 > /proc/sys/vm/swappiness

    # Setup Writeback
    echo 10 > /proc/sys/vm/dirty_background_ratio
    echo 3000 > /proc/sys/vm/dirty_expire_centisecs
    echo 32768 > /proc/sys/vm/min_free_kbytes

    configure_read_ahead_kb_values
}

case "$target" in
    "msmnile")
    # Enable EAS
    echo ENERGY_AWARE > /sys/kernel/debug/sched_features

    # cpuset parameters
    echo 0-7 /dev/cpuset/top-app/cpus
    echo 0-3,5-6 /dev/cpuset/foreground/cpus
    echo 0-1 /dev/cpuset/background/cpus
    echo 0-3 /dev/cpuset/system-background/cpus
    echo 0-3 /dev/cpuset/restricted/cpus

    # Setup final blkio
    # value for group_idle is us
    echo 1000 > /dev/blkio/blkio.weight
    echo 100 > /dev/blkio/background/blkio.weight
    echo 2000 > /dev/blkio/blkio.group_idle
    echo 0 > /dev/blkio/background/blkio.group_idle

    # Enable UFS powersaving
    echo 1 > /sys/devices/platform/soc/1d84000.ufshc/clkscale_enable 1
    echo 1 > /sys/devices/platform/soc/1d84000.ufshc/clkgate_enable 1
    echo 1 > /sys/devices/platform/soc/1d84000.ufshc/hibern8_on_idle_enable 1
    echo N > /sys/module/lpm_levels/parameters/sleep_disabled N

    # Block layer tuning: discard chunk size up to 128MB
    # Otherwise, contiguous discards can be merged
    echo 134217728 > /sys/block/sda/queue/discard_max_bytes 134217728

    # Configure governor settings for silver cluster
    echo "schedutil" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    echo 0 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us
    echo 0 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us
    echo 1 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/iowait_boost_enable

    # Configure governor settings for gold cluster
    echo "schedutil" > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
    echo 0 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/up_rate_limit_us
    echo 0 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/down_rate_limit_us
    echo 1 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/iowait_boost_enable

    # Configure governor settings for gold+ cluster
    echo "schedutil" > /sys/devices/system/cpu/cpu7/cpufreq/scaling_governor
    echo 0 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/up_rate_limit_us
    echo 0 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/down_rate_limit_us
    echo 1 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/iowait_boost_enable

    # Disable wsf, beacause we are using efk.
    # wsf Range : 1..1000 So set to bare minimum value 1.
    echo 1 > /proc/sys/vm/watermark_scale_factor

    # Enable bus-dcvs
    for device in /sys/devices/platform/soc
    do
        for cpubw in $device/*cpu-cpu-llcc-bw/devfreq/*cpu-cpu-llcc-bw
        do
        echo "bw_hwmon" > $cpubw/governor
        echo 40 > $cpubw/polling_interval
        echo "2288 4577 7110 9155 12298 14236 15258" > $cpubw/bw_hwmon/mbps_zones
        echo 4 > $cpubw/bw_hwmon/sample_ms
        echo 50 > $cpubw/bw_hwmon/io_percent
        echo 20 > $cpubw/bw_hwmon/hist_memory
        echo 10 > $cpubw/bw_hwmon/hyst_length
        echo 30 > $cpubw/bw_hwmon/down_thres
        echo 0 > $cpubw/bw_hwmon/guard_band_mbps
        echo 250 > $cpubw/bw_hwmon/up_scale
        echo 1600 > $cpubw/bw_hwmon/idle_mbps
        echo 14236 > $cpubw/max_freq
        done

        for llccbw in $device/*cpu-llcc-ddr-bw/devfreq/*cpu-llcc-ddr-bw
        do
        echo "bw_hwmon" > $llccbw/governor
        echo 40 > $llccbw/polling_interval
        echo "1720 2929 3879 5931 6881 7980" > $llccbw/bw_hwmon/mbps_zones
        echo 4 > $llccbw/bw_hwmon/sample_ms
        echo 80 > $llccbw/bw_hwmon/io_percent
        echo 20 > $llccbw/bw_hwmon/hist_memory
        echo 10 > $llccbw/bw_hwmon/hyst_length
        echo 30 > $llccbw/bw_hwmon/down_thres
        echo 0 > $llccbw/bw_hwmon/guard_band_mbps
        echo 250 > $llccbw/bw_hwmon/up_scale
        echo 1600 > $llccbw/bw_hwmon/idle_mbps
        echo 6881 > $llccbw/max_freq
        done

        for npubw in $device/*npu-npu-ddr-bw/devfreq/*npu-npu-ddr-bw
        do
        echo 1 > /sys/devices/virtual/npu/msm_npu/pwr
        echo "bw_hwmon" > $npubw/governor
        echo 40 > $npubw/polling_interval
        echo "1720 2929 3879 5931 6881 7980" > $npubw/bw_hwmon/mbps_zones
        echo 4 > $npubw/bw_hwmon/sample_ms
        echo 80 > $npubw/bw_hwmon/io_percent
        echo 20 > $npubw/bw_hwmon/hist_memory
        echo 6  > $npubw/bw_hwmon/hyst_length
        echo 30 > $npubw/bw_hwmon/down_thres
        echo 0 > $npubw/bw_hwmon/guard_band_mbps
        echo 250 > $npubw/bw_hwmon/up_scale
        echo 0 > $npubw/bw_hwmon/idle_mbps
        echo 0 > /sys/devices/virtual/npu/msm_npu/pwr
        done

        # Enable mem_latency governor for L3, LLCC, and DDR scaling
        for memlat in $device/*cpu*-lat/devfreq/*cpu*-lat
        do
        echo "mem_latency" > $memlat/governor
        echo 10 > $memlat/polling_interval
        echo 400 > $memlat/mem_latency/ratio_ceil
        done

        # Enable userspace governor for L3 cdsp nodes
        for l3cdsp in $device/*cdsp-cdsp-l3-lat/devfreq/*cdsp-cdsp-l3-lat
        do
        echo "cdspl3" > $l3cdsp/governor
        done

        # Enable compute governor for gold latfloor
        for latfloor in $device/*cpu-ddr-latfloor*/devfreq/*cpu-ddr-latfloor*
        do
        echo "compute" > $latfloor/governor
        echo 10 > $latfloor/polling_interval
        done

        # Gold L3 ratio ceil
        for l3gold in $device/*cpu4-cpu-l3-lat/devfreq/*cpu4-cpu-l3-lat
        do
        echo 4000 > $l3gold/mem_latency/ratio_ceil
        done

        # Prime L3 ratio ceil
        for l3prime in $device/*cpu7-cpu-l3-lat/devfreq/*cpu7-cpu-l3-lat
        do
        echo 20000 > $l3prime/mem_latency/ratio_ceil
        done
    done

    # Setup readahead
    find /sys/devices -name read_ahead_kb | while read node; do echo 128 > $node; done

    configure_memory_parameters
    ;;
esac

case "$target" in
    "msm8994" | "msm8992" | "msm8996" | "msm8998" | "sdm660" | "apq8098_latv" | "sdm845" | "sdm710" | "msmnile" | "qcs605" | "sm6150")
        setprop vendor.post_boot.parsed 1
    ;;
esac
