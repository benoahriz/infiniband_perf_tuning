I don't currently have access to the original hardware I used so most of this is off memory and some notes I made.
Also I'll present the caveat and warning that all these things I tested not with a view to stability for a production environment but this allowed me to get an Idea of what things I could do to eke out more performance.

There were a few of basic designs I tested with.  The hardware was a supermicro chassis with E5 series intel cpu's 2x quad core 64GB ram. The raid card was LSI 9266-8i (capacitor bbu + fastpath and cachecade addons) that connected to a supermicro sas expander backplane.  I tested with several different array's of disks the most interesting were the SSD's so for this example I was using 10 samsung 840pro 512gb ssd's in raid 10 plus 2 hotspares.  This server setup was designed to serve raw LVM based lun's to single U nodes via 20gb Infiniband running ISCSI protocol.

Here is a general list of stuff I did to maximize the performance I learned a lot about what things made the most differences.  I also worked extensively with the engineers at LSI to optimize things.

## Hardware.
- PCI slots.  
Its not stated anywhere in the documentation but faster is not always better.  Working directly with the LSI engineers I learned that for the greatest speed and stability you should be using an 8x pci slot for the raid card.  Also you want to make sure that your infiniband cards are registering at the right speeds on the PCI bus.  You'll want to use 'lspci' with lots of verbosity to verify that the pci cards come up at the right speeds.  I had some driver and BIOS issues that caused some infiniband cards to only come up at half speed or 2.5gb/s vs 5.0gb/s

### Bios updates
For the head nodes I was using INTEL chassis with Intel chipsets.  These were very buggy and needed to be constantly updated as Intel was fixing things in the BIOS which caused great instability. Make sure all the BIOS is latest and greatest.  Supermicro's firmware's seemed much more stable in comparison. 

## Protocols.
This is a very interesting topic.  In a nutshell this was probably the biggest benefit.  Originally I had been using Ethernet over infiniband  or IPoIB which gave me very fast speeds compared to 1gb networking but no where near the speeds I would expect to see from a raid10 SSD array via 20gb infiniband.  Using IPoIB also bogged down cpu's so wasn't ideal in my situation.  So the magic really starts when you use iscsi + iser + RDMA.

You still need IP based communication to do the target discovery but once the nodes all know about each other they switch to using RDMA which is way more efficient.   This requires using a iscsi target software that supports iser as well as compiling the drivers for your current kernel from the Mellanox or OFED package of your choice. 

## Linux Distribution
Primarily I tested centos 6 however I also tested with Ubuntu 12.04.  The best performance really depended on the kernel version. 

### Kernel
I tested with centos 6 default and Ubuntu's 12.04 kernels and they both gave mediocre results.  I highly recommend the mainline kernel repo the mainline kernel had some significant performance patches/fixes for SSD's in general.

[elrepo Mainline kernel](http://elrepo.org/tiki/kernel-ml)

### ISCSI software
In Linux there are a few choices here.  Originally I had been using ietd but then moved to tgtd because of support for iser RDMA which was a critical performance gain.

[stgt](http://stgt.sourceforge.net/)


### Infiniband software/drivers.
Originally I had worked with the OFED drivers but soon realized that my Mellanox branded cards performed better when I used the firmware specifically from Mellanox it was an older revision of OFED but compiled specifically for my cards.  
[MLNX branded drivers](http://www.mellanox.com/page/products_dyn?product_family=26&mtag=linux_sw_drivers)


This was a very helpful guide on the tuning recommendations I followed.
[Performance Tuning Guide for Mellanox Network Adapters](http://www.mellanox.com/related-docs/prod_software/Performance_Tuning_Guide_for_Mellanox_Network_Adapters.pdf)

### Openib.conf

	This file allowed me to enable and disable certain drivers.  Specifically I wanted to enable the iser as well as IPoIB


### Sysctl.conf

The settings in sysctl.conf made significant improvements on performance.
	
Network settings
```
net.ipv4.tcp_timestamps=0
net.ipv4.tcp_sack=0
net.ipv4.tcp_mem=16777216 16777216 16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_low_latency = 1

net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=16777216
net.core.wmem_default=16777216
net.core.optmem_max=16777216
net.core.netdev_max_backlog=250000
```

### Virtual memory settings

Of the sysctl settings these defintily make a huge difference.  Depending on the workloads of the guest machines these settings could be tweaked per your environment.  I noticed significant differences in performance based on different types of workloads.  YMMV

```
vm.swappiness=0
vm.zone_reclaim_mode=0
vm.dirty_ratio=10
vm.dirty_background_ratio=5
```
	
## IRQ affinity

	This was a HUGE item to improve performance.  First disable irqbalance and manually pin your cpu/irq affinity.
	The Mellanox package comes with a shell script that was helpful in resetting the affinity.  I used this same script to help balance between my raid card and Infiniband card.  Also since I had dual a dual socket motherboard I thought it best to install the infiniband card on one PCI bus and the raid card on the other bus with the other cpu.
	 set_irq_affinity_cpulist.sh is the name of the script.  
	
	
### Unbalanced
	
	```
	[root@demo mnt]# cat /proc/interrupts |grep megasas
	  80:       2506          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
	  81:        124          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
	  82:         24          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
	  83:          7          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
	  84:        993          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
	  85:         80          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
	  86:         17          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
	  87:          8          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
	```

### Balanced

	```
	$ cat /proc/interrupts |grep mega
	  80:     650586          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
	  81:     242572      87388          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
	  82:     240192          0     247210          0          0          0          0          0  IR-PCI-MSI-edge      megasas
	  83:      41286          0          0      42410          0          0          0          0  IR-PCI-MSI-edge      megasas
	  84:     184197          0          0          0      52479          0          0          0  IR-PCI-MSI-edge      megasas
	  85:     113659          0          0          0          0      58953          0          0  IR-PCI-MSI-edge      megasas
	  86:      33822          0          0          0          0          0      37659          0  IR-PCI-MSI-edge      megasas
	  87:      28633          0          0          0          0          0          0      35605  IR-PCI-MSI-edge      megasas
	```
	
	Some additional reading on interuppt spreading.
	
	[LSI helpdesk on smp affinity](http://mycusthelp.info/LSI/_cs/AnswerDetail.aspx?sSessionID=2094971131CRRKKVQBLHOQVMGXAIOEYJYLYNWQIB&inc=8273&caller=~%2fFindAnswers.aspx%3ftxtCriteria%3dssd%26sSessionid%3d2094971131CRRKKVQBLHOQVMGXAIOEYJYLYNWQIB)
	
	[msi-x-the-right-way-to-spread-interrupt-load](http://www.alexonlinux.com/msi-x-the-right-way-to-spread-interrupt-load)
	
	[smp-affinity-and-proper-interrupt-handling-in-linux](http://www.alexonlinux.com/smp-affinity-and-proper-interrupt-handling-in-linux)
	
	
## CPU frequency/speed.
	
## Raid firmware

If you update the raid firmware make sure that all the settings are set correctly still.  
Also double check to make sure that the drivers are using enough interuppts.
For example the stock megaraid_sas driver was only using 1 interrupt.  Installing the latest driver from LSI allowed all 8 to be used. 

Before and then after installing the new driver.

``` 
[root@demo mnt]# cat /proc/interrupts |grep megasas
  79:       2506          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
[root@demo mnt]# cat /proc/interrupts |grep megasas
  80:       2506          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
  81:        124          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
  82:         24          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
  83:          7          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
  84:        993          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
  85:         80          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
  86:         17          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas
  87:          8          0          0          0          0          0          0          0  IR-PCI-MSI-edge      megasas

```

Check this link at the bottom it has an attached PDF which is a really good runthrough of all the information you need.

[LSI tuning guide](http://mycusthelp.info/LSI/_cs/AnswerDetail.aspx?inc=8196)

### C-states

### Disk Schedulers

### Hugepages

### SSD brands
The samsung 840pro's gave much much worse performance than earlier plextor m5 256gb drives I used in the past.  These newer samsung drives are much slower and have a known issue with the caching on disk that conflicts with LSI firmware making them good or desktop machines but not very good in a Raid Array.  I highly recommend researching this issue.  Some people have worked around this by flashing differently branded firmwares onto the LSI branded cards.  I wasn't brave enough to risk bricking my raid cards so I didn’t try it.

### Mount options
Much performance can be gained as well by adding less safe mount options.
The best performance I saw was when I tested against ext4 with 

```
discard,noatime,data=writeback,barrier=0,acl,user_xattr,nobh
```

More to come.
