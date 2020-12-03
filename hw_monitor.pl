#!/usr/bin/perl -w

our %drives; # list of drives 'sdX'

# use sed to remove deg symbol as html hates it
my @TEMPS=`/usr/bin/sensors | egrep "Core|Temper" | sed -e 's/\xC2\xB0//g;' 2>&1`;

#my @GPU=`/usr/bin/nvclock -T 2>&1`;
# kernel: [102126.787985] nvclock:23410 freeing invalid memtype d0000000-d0010000
my @GPU=`nvidia-smi -a 2>/dev/null | grep Gpu | tail -1`;
if (scalar(@GPU) == 0 ) {
	@GPU=`/usr/bin/sensors | grep -A2 radeon | tail -1`;
};
 
my @FANS=`/usr/bin/sensors | grep "FAN" 2>&1`;

my @RAID=`cat /proc/mdstat | sed -e 's/</\\&lt\;/g;s/>/\\&gt\;/g;' 2>&1`;
#my @dmRAID=`sudo dmraid -r --sep , -cpath,size,status 2>&1`;

my @IPMI=`ipmitool sdr list full`;

sub getDrives() {
	open(P,"/proc/partitions");
	while (<P>) {

		if (my ($drive)=/(sd[a-z])/) {;
			$drives{$drive}++;
		};

	};
	close(P);
};

sub printOK () {
	print " <span style='background-color:#57E964'> OK </span>\n";
};

sub printWarn ($) {
	local $device=shift;
	print " <span style='background-color:orange'> WARNING </span>\n";

	`echo ""| mailx "$ENV{HOSTNAME} reports WARNING on $device" root`;
};

sub printAlert ($) {
	local ($device)=shift;

#print "\n\n>>>>>>>>>>>>>$device\n";
	print " <span style='background-color:red'> ALERT! </span>\n";


	`echo ""| mailx  "$ENV{HOSTNAME} reports ALERT on $device" root`;
};

sub printIgnored () {
	local $device=shift;
	print " <span style='background-color:#B4CFEC'> ignored </span>\n";
};




sub checkFan($$$$) {
        local ($device,$current,$high, $crit) = @_;

        #print "device:$dev, current:$current, high:$high, crit:$crit\n";
	if ($high==-1 && $crit==-1) {
		printIgnored;
	} elsif ($current>$high) {
                printOK;
                return 0;
        } elsif ($current>=$high && $current<$crit) {
                printWarn($device." current:= $current");
                return 1;
        } else {
                printAlert($device." current:= $current");
                return 2;
        };
};

sub checkTemp($$$$) {
	local ($device,$current,$high, $crit) = @_;

	#print "device:$dev, current:$current, high:$high, crit:$crit\n";
	if ($current<$high) {
		printOK;
		return 0;
	} elsif ($current>=$high && $current<$crit) {
		printWarn($device." current:= $current");
                return 1;
        } else {
		printAlert($device." current:= $current");
                return 2;
	};
};


print<<HEAD; 

<html>
<head>
	<title>hw_monitor</title>
</head>
<h3>hw_monitor</h3>

<pre>
HEAD

getDrives(); # find all drives, sda, sdb, sdc, sdd etc
my @d=sort keys %drives;
my $disks = "@d"; # flat string of disks, space separated

my @dd=map{ sprintf "/dev/$_" } @d;  # prepend the /dev/
my $diskdevs="@dd";

print localtime()."\n\n";
print `uname -a`."\n";

print "\n<b>Motherboard Temperatures</b>\n";
foreach (@TEMPS) {

	chomp;
	print $_;
	
	if (/Core.*?\+([\d\.]+)/) {
		checkTemp("Core0",$1,90,125);
	};

	if (/CPU.*?\+([\d\.]+)/) {
                checkTemp("CPU",$1,90,125);
        };

	if (/MB.*?\+([\d\.]+)/) {
                checkTemp("Motherboard",$1,70,125);
        };	
};


print "\n<b>Disk Temperatures</b>\n";
my @DISKTEMPS=`/usr/sbin/hddtemp $diskdevs | sed -e 's/\xC2\xB0//g;' 2>&1`;
foreach (@DISKTEMPS) {

	chomp;
        print $_;
	if (/^(\S+):\s+ST380817AS:\s+([\d]+)/) {
                checkTemp($1,$2,50,60);
        };

	if (/^(\S+):\s+WDC WD20EARS.*?:\s+([\d]+)/) {
                checkTemp($1,$2,58,60);
        };
	if (/^(\S+):\s+SAMSUNG HD103UJ:\s+([\d]+)/) {
                checkTemp($1,$2,58,60);
        };
	if (/^(\S+):\s+WDC WD20EZRX-\w+:\s+([\d]+)/) {
                checkTemp($1,$2,58,60);
        };
       	if (/^(\S+):\s+WDC WD40EZRX-\w+:\s+([\d]+)/) {
                checkTemp($1,$2,58,60);
        };
  

#	print "\n";

};

print "\n<b>GPU Temperature</b>\n";
foreach (@GPU) {                                                                             

	chomp;
        print $_;                                                                             

       if (/Gpu.*?([\d]+) C/) {                                                
                checkTemp("GFX GPU",$1,65,75);                                                         
        };    

       if (/Board.*?([\d]+)/) {                                                
                checkTemp("GFX Board",$1,50,60);                                                         
        }; 
      if (/temp\d+:.*?([\d]+)/) {                                                
                checkTemp("GFX Board",$1,50,60);                                                         
        }; 
		print "\n";   
};


print "\n<b>Fans</b>\n";
foreach (@FANS) {

	chomp;
        print $_;
	if (/CPU.*?([\d]+)/) {                                                                 
                checkFan("CPU Fan",$1,1000,0);                                                              
        } else {
		checkFan("",0,-1,-1); # ignored
	};
};

print "\n<b>mdadm RAID</b>\n";
my $device="";
foreach (@RAID) {

	chomp;
        print $_;

	#$device=m/active/ ? $_ : "";
	if (m/active/) { $device = $_ };

        if (/\[U_|_U|__\]/) {
#print "\n::::::::::::::::device:   $device\n" if ($device);
                #printAlert("$device");
		$device="";
        } elsif (/\[U+\]/) {
		printOK;
		$device="";
	};

	print "\n";

};

# print "\n<b>dmraid RAID</b>\n";
# foreach (@dmRAID) {

# 	chomp;
#         print $_;

# 	my($device,$size,$status)=split(",");

#         if ($status!~/ok/) {
# #print "\n::::::::::::::::device:   $device\n" if ($device);
#                 printAlert("dmraid $device $status");
# 		$device="";
#         } elsif ($status=~/ok/) {
# 		printOK;
# 		$device="";
# 	};

# 	print "\n";

# };



print "\n<b>SMART</b>\n";                                                                      
foreach my $disk (keys %drives) {                                                                             

	print "Disk: /dev/$disk\n";
	my @SMARTS=`/usr/sbin/smartctl -H /dev/$disk 2>&1`;

	foreach ( @SMARTS ) {
		chomp;

		if (/overall-health self-assessment test result: (.*)/) {
			print $_;

			if ($1 =~ /PASSED/) {
				printOK;
			} else {
				printAlert("SMART HDD $disk");
			};

			print "\n";
		};
	};                                                                         
};                                                                                            


print "\n<b>IPMI Sensors</b>\n";                                                                      
foreach (@IPMI) {

	chomp;
	my ($snr,$value,$status)=split('\|');

	print "$snr| $value| $status";

	if ($status=~/ok/) {

		printOK;
	} elsif ($status=~/ns/) {
		printIgnored;
	} else {
		printAlert("IPMI Sensor fault $snr $value $status");
	};
};

print<<FOOT;
</pre>
</body>
</html>
FOOT




