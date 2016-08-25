package PW_Rsync;


use File::Copy "cp";			#cp will preserve the source file's permission bits
use Date::Calc qw ( Today);
my $DEBUG= 1;
my $etcDir = $DEBUG ? "/tmp/etc/" : "/etc/";

if ($etcDir eq  "/tmp/etc/")  {
	mk_test_files($etcDir);
}


my $mysmbfile  = $etcDir .  "/samba/smbpasswd";
my $mypassfile = $etcDir .  "passwd";
my $myshadfile = $etcDir .  "shadow";
my $mygrpfile  = $etcDir .  "group";
my $mypassbot  = $etcDir .  "passwd.bot";
my $myshadbot  = $etcDir .  "shadow.bot";
my $mygrpbot   = $etcDir .  "group.bot";

1;

sub check_linecounts {

	my $err = ""; 
	foreach my $old (  $mypassfile, $myshadfile, $mygrpfile  ) {
		my $new = $old . ".new";
		my $lold = `wc -l < $old`;
		my $lnew = `wc -l < $new`;
		my $diff = abs ( $lnew - $lold );
		$err .= "difference in $old file is $diff\n "
			if ( $diff > 2 );
	}
	return $err;
}

sub mk_new_files {
	foreach my $old (  $mypassfile, $myshadfile, $mygrpfile  ) {
		my $top = get_top($old);
		my $new = $old . ".new";
		my $bot = $old . ".bot";
		` cat  $top $bot > $new`;
#		system (" cat ", "$top $bot > $new");
		chmod 0400, $new if ($new =~ /shadow/);
	}
}

sub mk_today_files {
	my $today_iso = sprintf "%4d%2.2d%2.2d", Today();
	foreach my $old (  $mypassfile, $myshadfile, $mygrpfile, $mysmbfile  ) {
		$today_file = $old . ".$today_iso";
		cp ( $old,  $today_file);
	}
	return;
}

sub rsync_files {
	my $nologin  = shift;
	my $SOA_IP   = shift;
	my $rsync    = "/usr/bin/rsync -o -g -p";

	my $passfile = ($nologin  == 1 ) ? "passwd.nologin.bot" : "passwd.bot";

#	print ("A rsync cmd [$rsync ${SOA_IP}::passwd/$passfile $mypassbot]\n" );

	system ( "$rsync ${SOA_IP}::passwd/$passfile     $mypassbot");
	system ( "$rsync ${SOA_IP}::passwd/shadow.bot    $myshadbot");
	system ( "$rsync ${SOA_IP}::passwd/group.bot     $mygrpbot");
	system ( "$rsync ${SOA_IP}::etc/samba/smbpasswd  $mysmbfile");

	return;
}

sub mk_test_files{

	$etcDir = shift;
	mkdir $etcDir unless -d $etcDir;
	cp ( "/etc/passwd",  $etcDir."passwd");
	cp ( "/etc/shadow",  $etcDir."shadow");
#	chmod 0400, $etcDir."shadow";
	cp ( "/etc/group",   $etcDir."group");

	mkdir  $etcDir.'samba' unless -d $etcDir.'samba';
	cp ( "/etc/samba/smbpasswd", $etcDir."/samba/smbpasswd");
#	chmod 0400, $etcDir."shadow";
	return;
}

sub get_top {
	my $file =shift;

## note that tops currently ( 2016-08) pre-build as ( /etc/passwd_top, /etc/shadow_top, /etc/group_top)
## we just return these names

	$file =~ s[^/tmp][];		# if we are debugging
	my $top = $file . "_top";

	return $top;
}