package PHAS_PW;

#use lib '/opt/sysadmin/common/passwd/';
use lib ".";
use PHAS_PW_Utils;
use phas_LDAP;
use Carp;

#qw[ Ask get_username get_category
#					get_studentnumber  get_uid		get_gid
#					get_homedir        get_expdate
#					get_diskquota      get_account confirm_input
#					];
my $Verbose = $main::Verbose; 
my $passwddir = "/opt/sysadmin/common/passwd/";

##bottomdir MUST match [passwd]path in tau:;/etc/rsync.conf
my $bottomdir = $passwddir ."bottoms/";
my $userdb    = $passwddir ."users.db";		# data file for existing ids
my $aliases   = $passwddir ."aliases";          # valid email addresses file

my $etcdir   = "/tmp/etc/";		#For testing
#my $etcdir  = "/etc/";			#for production

my $pwfile   = $etcdir . "passwd";				# system passwd file
my $shadow   = $etcdir . "shadow";				# system shadow file
my $grpfile  = $etcdir . "group";				# system group file
my $smbfile  = $etcdir . "samba/smbpasswd";		# system Samba pw file 

my $approp  = $passwddir."appropriate.txt"; 	# UBC's Appropriate Use statement
my $pwhelp  = $passwddir."passwd.txt";		# help info. on password setting

my $PrntSvr = "prntsvr.phas.ubc.ca";

my $PW_Archive   = "$passwddir/Archive/"; 	## pw, shad,grp &smb 
my $Home_Archive = "/home/ARCHIVED";
my $Proto_Dir    = "/home/prototype/default"; # archive of default user files

# will get some form of the PGS bottoms

my @login_hosts   = qw (delta tau);
my @nologin_hosts = qw (beta mail omega zorok phasor cups);
my @UNIX_Servers  = qw ( @login_hosts, @nologin_hosts );
# these are the configuration names in the ../lib/ldap_conf.file
my @LDAP_Servers  = qw (IPA01);
1;

sub copy_files {

##  copy PGS files to an archive dir for safety
##  archived filename will be ori.taday  (ie passwd.2016-04-04)
##	used bt rmusr.

	use File::Basename;
	use File::Copy;
	use Date::Calc qw (Today);
	
	my $iso = sprintf "%4.4d-%2.2d-%2.2d", Today();

	foreach my $file ( $pwfile, $shadow, $grpfile, $smbfile  ) {
		$base = basename($file);
		$savefile = $PW_Archive . $base . ".$iso";
        copy($file,$savefile) or die "Copy of $file failed: $!";
	}
	return;
}
#
#sub createid {
#
#    my $udata_ref = shift;
#    my %udata = %{$udata_ref};
#	my $Verbose = $main::Verbose; 
#	print " Add new user  Unix files (tau)... PGS \n " if $Verbose;
#
#	exit unless ( Ask( "continue ?","Y") );
#
#    update_unix_files($udata_ref);
#
#	print " Updating User Database  \n " if $Verbose;
#	exit unless ( Ask( "continue ?","Y") );
#    update_usersDB($udata_ref);
#    
#	print "Creating  home dir as [$udata{homedir}]\n" if $Verbose;
#    PHAS_PW_Utils::mk_homedir ($udata{uid}, $udata{gid}, $udata{homedir} );
#
#	print "Copying proto user files \n" if $Verbose;
#	PHAS_PW_Utils::copy_proto_files($Proto_Dir );
#
#	print "Updating pkkota DB  \n" if $Verbose;
#    create_pykota_account( $udata{username}, $udata{printquota} ); 
#
#	print "Updating pkkota DB  \n" if $Verbose;
#    do_mail( $udata{username},  $udata{homedir}, $udata{uid}, $udata{gid},  $udata{category} );  
#}

sub update_unix_files {
    my $udata_ref = shift;
    my %udata = %{$udata_ref};
                
	print "Update the PSG files: $pwfile $shadow $grpfile\n" if Verbose;

    open(PW, ">>", $pwfile) or die "ERROR: Can't open $pwfile! ";
    print PW "$udata{username}:x:$udata{uid}:$udata{gid}:$udata{fullname}:$udata{homedir}:$udata{shell}\n";
    close(PW);

    open (SH, ">>",$shadow) or die "ERROR: Can't open $shadow! ";
    print SH "$udata{username}:*no login*:9962::::::\n";
    close SH;
    
    ## Add username to group file
    open (GRPFILE, ">>",$grpfile) or die "ERROR: Can't open $grpfile! ";
    print GRPFILE "$udata{username}:x:$udata{gid}:\n";
    close GRPFILE;
	    
}
sub  update_usersDB {
    
    my $udata_ref = shift;
    my %udata = %{$udata_ref};
                  
    open (USERDB, ">>",$userdb) or die "ERROR: Can't open $userdb! ";
    print USERDB "$udata{username}:$udata{fullname}:$udata{account}:$udata{category}:$udata{expdate}::$udata{studentno}::$udata{CWL}\n";
    close USERDB;

}

sub create_pykota_account {
    my $username   = shift;
    my $printquota = shift;
    my $LINUX_USERNAME_REGEX  = qr/^([a-z_][a-z0-9_-]*)$/;
#this effectively untaints the printquota. (either a # or a decim#!al number)
    my $pq = $1 if ($printquota =~ /(^#$|^[\d\.]*)$/ );

    my $uname = $1 if ($username =~ $LINUX_USERNAME_REGEX);
   
    print "\nCreating Pykota account for user ......... \n";
    my $quota = "";
    my $pk_cmd = qq{ssh $PrntSvr pkusers --add --email \@phas.ubc.ca};
    # set pkusers command to create user
    if ( $pq ) {  				        # undergrads don't get a pykota entry until they pay
										# either unlimited printing or has initial quota
        if ( $pq eq "#" ) { 	            # unlimited printing 
    	    $quota = " --limitby noquota $uname";
        } else {							# has an initial quota
    	    $quota = " --limitby balance --balance $pq $uname";
        }
        # set edpykota command to allow user to print to any printer
        $ed_cmd = "ssh $PrntSvr 'edpykota --add $uname'";
    } 
    
	$pk_cmd .= $quota;
	
	print "pkcmd is [$pk_cmd]\n";
	print "edcmd is [$ed_cmd]\n";
	system($pk_cmd);
	system($ed_cmd);

}

sub delete_pykota_account {
    my $username   = shift;
   
    my $LINUX_USERNAME_REGEX  = qr/^([a-z_][a-z0-9_-]*)$/;

# untaint the username...
    my $uname = $1 if ($username =~ $LINUX_USERNAME_REGEX);

    my $pk_cmd = qq{ssh $PrntSvr pkusers --delete $username};
	print "pkcmd is [$pk_cmd]\n";
	
	system($pk_cmd);
	
}

sub do_mail {
    my $username = shift;
    my $homedir  = shift;
    my $uid      = shift;
    my $gid      = shift;
    my $cat      = shift;
    
    # Set up files on mail server (enabled for "everyone" only)
    my @cat_mails = PHAS_PW_Utils::get_catmail();
    my $mh_cmd = "/opt/sysadmin/passwd/mkhome.sh $username $homedir $uid $gid ";
    my $enable =  ( grep $cat, @cat_mails )
                ? "ENABLE" : "DISABLE";
    $mh_cmd .= $enable;

   print "\nSetting up mail files ......... \n";
   my $ssh_cmd = "/usr/bin/ssh";
   my $mailhost = "mail";
   my @args = ($ssh_cmd, $mailhost, $mh_cmd);

   print "$ssh_cmd $mailhost $mh_cmd\n";
   system(@args) == 0 or die " ssh to $mailhost failed\n";

    if ( grep $cat, @cat_mails ) {
        # Subscribe to events@phas list
        print "\nAdding to events list ......... \n";
        system "/bin/echo $username\@phas.ubc.ca >> /opt/sysadmin/common/passwd/new_events.list";
    }
}

sub get_user_info {
    
# set path so that grep command works for different architectures
    $ENV{'PATH'} = '/sbin:/bin:/usr/bin:/usr/local/bin:/usr/ucb:/usr/bsd';
# set backspace to erase
#`stty erase '^H'`;

    my %user_data = ();

INPUT_USER_PARAMETERS:

    print "\n\nPlease provide the following information: \n";
    $user_data{category}   = get_category();
    $user_data{studentno}  = get_studentnumber($user_data{category});
    $user_data{CWL}        = Ask ("Enter CWL");
    $user_data{lastname}   = Ask ("Enter Lastname");
    $user_data{firstname}  = Ask ('Enter First Name');
#    my ($guess) = lc( $1 . $user_data{lastname})  if $user_data{firstname} =~ /^(\w)/;		# get bboop from "Betty Boop" guess for useranme
    my $guess = $user_data{CWL};
    $user_data{username}   = get_username ($guess);
    $user_data{fullname}   = $user_data{firstnam$user_data{category}   = get_category();
    $user_data{studentno}  = get_studentnumber($user_data{category});
    $user_data{CWL}        = Ask ("Enter CWL");
    $user_data{lastname}   = Ask ("Enter Lastname");
    $user_data{firstname}  = Ask ('Enter First Name');
#    my ($guess) = lc( $1 . $user_data{lastname})  if $user_data{firstname} =~ /^(\w)/;		# get bboop from "Betty Boop" guess for useranme
    my $guess = $user_data{CWL};
    $user_data{username}   = get_username ($guess);
    $user_data{fullname}   = $user_data{firstname} . " " . $user_data{lastname};
    $user_data{uid}        = get_uid($user_data{category});
    $user_data{gid}        = get_gid($user_data{uid});
    $user_data{shell}      = "/bin/bash";
    $user_data{homedir}    = get_homedir($user_data{category}, $user_data{username} );
    $user_data{expdate}    = get_expdate($user_data{category});
    $user_data{diskquota}  = get_diskquota($user_data{category});
    $user_data{account}    = get_account($user_data{category});
    $user_data{printquota} e} . " " . $user_data{lastname};
    $user_data{uid}        = get_uid($user_data{category});
    $user_data{gid}        = get_gid($user_data{uid});
    $user_data{shell}      = "/bin/bash";
    $user_data{homedir}    = get_homedir($user_data{category}, $user_data{username} );
    $user_data{expdate}    = get_expdate($user_data{category});
    $user_data{diskquota}  = get_diskquota($user_data{category});
    $user_data{account}    = get_account($user_data{category});
    $user_data{printquota} = ($user_data{category} eq 'Ugrad') ? "" : "#"; 

    my $ans = confirm_input ( \%user_data);
    if ( $ans =~ /^N/i) { goto INPUT_USER_PARAMETERS; }
	
    return \%user_data;
}

sub mk_pgs_bottoms  {
    my $dst_file_login   =  $bottomdir . "passwd.bot";
    my $dst_file_nologin =  $bottomdir . "passwd.nologin.bot";

    system ("sed -n '/splitz/,\$p' /etc/passwd > $dst_file_login");
	
    open (BOT,    "<", $dst_file_login)      || die "Cannot open file $dst_file_login\n";
    open (NOLOGIN, ">",$dst_file_nologin)    || die "Cannot open file $dst_file_nologin\n";

    my @exceptions = qw ( rap grieve hongyun );
	
    foreach $line (<BOT>) {
		
        my ($uname,$pw,$uid,$gid,$gcos,$hdir,$shell) = split /:/, $line;
        if ( grep( /^$uname$/, @exceptions ) ) { $shell = "/bin/bash" }
        else                                   { $shell = "/sbin/nologin"; }

        print NOLOGIN "$uname:$pw:$uid:$gid:$gcos:$hdir:$shell\n";
    }
    close BOT;
    close NOLOGIN;
    
## shadow bottom...
    my $dst_file   =  $bottomdir . "shadow.bot";
 
    system ("sed -n '/splitz/,\$p' $shadow >$dst_file");
 #   system ("cp /etc/shadow.bot /opt/sysadmin/common/passwd/shadow.bot");
    
    system ("sed -n '/splitz/,\$p' /etc/group >/etc/group.bot");
  #  system ("cp /etc/group.bot /opt/sysadmin/common/passwd/group.bot");
 
    print "======================================================================\n";
    print " \n";
}

sub add_LDAP {
    my $udata_ref = shift;
    my %udata = %{$udata_ref};

	foreach my $s ( @LDAP_Servers) {
		phas_LDAP::add_LDAP_user($udata_ref, $s);
	}
	return;
}

sub pgs_propagate {
	use Sys::Hostname;
	my $DEBUG = shift;
    # Invoke pgs_get command on each server - will rsync appropriate files (incl. /etc/samba/smbpasswd)
	my $SSHCMD = "/usr/bin/ssh";
	my $remote_cmd = $DEBUG ? "/opt/sysadmin/common/passwd/pgs_get_fake"
                            : "/opt/sysadmin/common/passwd/pgs_rsync";
   # an apparently undocumented part of running suid perl programs
   # it still isn't going to "just run setuid." 
   # you have to change your uid within your perl code, something like this. 
   my $real_user_id       = $<; # Grab all the original values
   my $effective_user_id  = $>; # so we can reset everything 
   my $real_group_id      = $(; # when we are done with root access
   my $effective_group_id = $); # 
   $< = $> = 0;                     # 0 is almost always OWNER root
   $( = $) = 0;                     # 0 is almost always GROUP wheel

   my $ServerName =  (split /\./, hostname())[0]; ## get the short name from the FQDN
   print "$ServerName \n\n";
   print "Please wait, updating ";  #DEBUG
 
   foreach my $newserver ( @UNIX_Servers ) {
       if ( $newserver ne $ServerName ) {
          print "..$newserver";  #DEBUG
          system( "$SSHCMD", "root\@$newserver", "$remote_cmd $ServerName" );
       }
   }
   print "..done. \n";

   $< = $real_user_id;          # Set everything back to original
   $> = $effective_user_id;     # values.
   $( = $real_group_id;         # 
   $) = $effective_group_id;    # 
}

sub delete_homedir {

    my $homedir = shift;
    use File::Path;
	use File::Basename;

    my $symlink;
	print "home dir is [$homedir]\n";
	if (defined ($symlink = readlink($homedir)))  {
        $homedir = $symlink;
		print "the symlink is {$symlink} home is really {$homedir}\n";
		croak "I do not handle symlinks, yet\n";
    }
    
	if ( -d $homedir ) {
		list_homefiles($homedir);
		
        my $ans = Ask("What to do with files in  $homedir directory Del or Archive", "Arch");
     
        if ( $ans =~ /ARCH/i ) {            #Archive then delete...
			$user = basename($homedir);
			my $tfile = $user . ".tar.gz";
            my $tar_cmd = "tar -czf $Home_Archive/$tfile -C $homedir .";
            my $result = system("$tar_cmd $homedir");
        }

        rmtree([ $homedir ]);        
        unlink $symlink if ( $symlink );
	exit;
 
    } else {
        print "*** No home directory found ***";
    }
    print "\n--------------------------------------\n";
    return;
}

sub list_homefiles {

    my $homedir = shift;
    print "Here is what is in $homedir:\n";
    my @files = glob("$homedir/*");
      
    my $i = 1;
    my $ncols = 3;
    foreach my $f ( @files) {
		$f =~s/^$homedir\///;
        printf "%28s", $f;
        print "\n" unless ($i%$ncols);
        $i++;
    }
	print "\n";
    return;
}

sub delete_Mailfiles {

    my $homedir = shift;
    if ( ! system ( "$ssh_cmd mail rm -R $homedir") ) { 
            print "*** Please delete the MAIL:$homedir directory manually.\n";
    }
}

sub update_users_DB {
	
	print <<EOD;
	This is a stub for update_users_DB ...

tasks should be in DB sysadmin.phas_aux update status
file_disposition & date (either suspended or deletion)

EOD
	return;
}

sub add_Windows {
	my $udata_ref = shift;


}

sub Delete_Windows {	# Delete account from Windows domain

	my $userid = shift;
	print "Deleting acct from Windows PDC...";
   
    &exe_cmd("$ssh_cmd administrator\@phaspdc powershell.exe -InputFormat None d:\\\\scripts\\\\RemoveUser.ps1 $userid >/dev/null");

	print "\n--------------------------------------\n";


}