#!/usr/bin/perl -w

my @procs=(
#	'/usr/bin/perl -w .*/owfs-fuseget.pl',
#	'/usr/bin/perl -w .*/cc128-pachube-mysql.pl',
#	'/usr/bin/perl -w .*/cid.pl',
	'/usr/sbin/mysqld',
#	'/usr/sbin/apache2 -k start',
#	'/usr/bin/mediatomb -c /etc/mediatomb/config.xml',
#	'/sbin/apcupsd',
#	'/opt/owfs/bin/owserver',
#	'/opt/owfs/bin/owfs',
#	'/usr/bin/perl -w .*/vfd.pl',
#	'/sbin/mdadm --monitor',
	'/usr/sbin/sshd -D',
	'rsyslogd',
#	'smbd -F',
#	'nmbd -D',
	# postfix processes
#	'/usr/lib/postfix/master',
	'/usr/lib/postfix/sbin/master',
	'pickup -l -t unix -u -c',
	'qmgr -l -t unix -u',
	'tlsmgr -l -t unix -u -c',
	'/usr/bin/dockerd'
);

my @PS=`ps -ef`;


sub printOK () {
	print " <span style='background-color:#57E964'> OK </span>\n";
};

sub printWarn ($) {
	local $device=shift;
	print " <span style='background-color:orange'> WARNING </span>\n";

	`/opt/pygNotify/sendit.sh "Ubuntu reports WARNING on $device"`;
};

sub printAlert ($) {
	local $device=shift;
	print " <span style='background-color:red'> ALERT! </span>\n";


	`/opt/pygNotify/sendit.sh "Ubuntu reports ALERT on $device"`;
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
                printWarn($device);
                return 1;
        } else {
                printAlert($device);
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
		printWarn($device);
                return 1;
        } else {
		printAlert($device);
                return 2;
	};
};


print<<HEAD; 

<html>
<head>
	<title>proc_monitor</title>
</head>
<h3>hw_monitor</h3>

<pre>
HEAD

print localtime()."\n\n";
print `uname -a`."\n";

print "\n<b>Process Checker</b>\n";
foreach $proc (@procs) {

	print "$proc ";

	if ( scalar ( grep /$proc/, @PS ) == 0 ) {

		printWarn(" $proc is NOT running");
	} else {

		printOK();
        };	
};


print<<FOOT;
</pre>
</body>
</html>
FOOT




