#!/bin/bash
#DISKS="sda sdb sdc sdd sde"
DISKS="vda vdb"
SCHMODE=deadline
ROTATIONAL=0
NRREQUEST=975
QUEUEDEPTH=975
RQAFFINITY=0

case "$1" in
check)
for DISK in $DISKS
                do
                SCHPATH="/sys/block/$DISK/queue/scheduler"
                ROTATIONALPATH="/sys/block/$DISK/queue/rotational"
                NRREQUESTSPATH="/sys/block/$DISK/queue/nr_requests"
                QUEUEDEPTHPATH="/sys/block/$DISK/device/queue_depth"
                RQAFFINITYPATH="/sys/block/$DISK/queue/rq_affinity"
                for f in $ROTATIONALPATH;do echo "$DISK ROTATIONAL:" $(cat $f); done
                for f in $SCHPATH;do echo "$DISK SCHEDULER:" $(cat $f); done
                for f in $NRREQUESTSPATH;do echo "$DISK NRREQUESTS:" $(cat $f); done
                for f in $QUEUEDEPTHPATH;do echo "$DISK QUEUEDEPTH:" $(cat $f); done
                for f in $RQAFFINITYPATH;do echo "$DISK RQAFFINITY:" $(cat $f); done
                done
;;

change)
for DISK in $DISKS
        do
        SCHPATH="/sys/block/$DISK/queue/scheduler"
        ROTATIONALPATH="/sys/block/$DISK/queue/rotational"
        NRREQUESTSPATH="/sys/block/$DISK/queue/nr_requests"
        QUEUEDEPTHPATH="/sys/block/$DISK/device/queue_depth"
        RQAFFINITYPATH="/sys/block/$DISK/queue/rq_affinity"
        #set ROTATIONAL
        for f in $ROTATIONALPATH
                do
                                echo "$ROTATIONAL" > $f
                done
        #set Scheduler
        for f in $SCHPATH
                do
                                echo "$SCHMODE" > $f
                done
        #set nr_requests
        for f in $NRREQUESTSPATH
                do
                                echo "$NRREQUEST" > $f
                done
        #set queue depth
        for f in $QUEUEDEPTHPATH
                do
                                echo "$QUEUEDEPTH" > $f
                done
        #set rqaffinity
        for f in $RQAFFINITYPATH
                do
                                echo "$RQAFFINITY" > $f
                done
        done
;;
*)
echo "Usage check | change"
echo "If you want to change the settings make sure to edit the variables at the top of this script"
;;
#       it might be good to also add these parameters to the mount options
#       tune2fs -o journal_data_writeback /dev/vda1
#       tune2fs -o journal_data_writeback /dev/vdb
#       tune2fs -o journal_data_writeback /dev/vdc
#       tune2fs -o journal_data_writeback /dev/vdd
#       tune2fs -o journal_data_writeback  /dev/mapper/vg_ew108-lv_root
#       noatime,data=writeback,barrier=0,nobh,errors=remount-ro
esac
