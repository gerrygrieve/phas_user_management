package PHAS_PW_Utils;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use lib "/opt/sysadmin/common/lib";
my $def_protodir = "/home/prototype/default/";

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT_OK      = ( );
@EXPORT   = qw(Ask  do_protofiles get_username get_category get_studentnumber get_uid get_gid get_homedir
                   get_expdate get_diskquota get_account confirm_input get_Pass_from_Terminal
				   validate_Pass kybd_patterns);

my $passwddir = "/opt/sysadmin/common/passwd/";
my $aliases = $passwddir."aliases";          # valid email addresses file
my $userdb  = $passwddir."users.db";
my $pwfile  = "/etc/passwd";			# system passwd file
my $shadow  = "/etc/shadow";			# system shadow file
my $grpfile = "/etc/group";			# system group file

##these are the acceptable chars in a password
my @pw_upper = ( A .. Z);
my @pw_lower = ( 'a' .. 'z');
my @pw_digit = ( 0 .. 9 );
my ($special_help, $otherref) = special_characters();
my @pw_other  = @{$otherref};

my @cats_help = (   "account needed for system software",
                    "an undergraduate student",
                    "adjunct & Associate Faculty",
                    "Regular faculty",,
                    "grad student",
                    "astro grad student, gets homedir =  /ahome",
                    "???",
                    "Post docs",
                    "dept staff member",
                    "generic account for course (eg. physNNN) or group (eg. mbelab) - expiry date required",
                    "default - expiry date required",
                );
my @cats_all = ( qw [ System  Ugrad Adj-Assoc
                      Faculty Grads AGrad
                      Others Postdocs Staff Misc Visitor]);
my @cats_mail = qw [  Faculty  Staff Postdocs  Adj-Assoc
                      Grads    AGrad Others ];

## Password restections:
   my $min_length  = 12;
    my $min_length2 = 15;			## not used
    my $max_length  = 128;
    my $min_charclass    = 4;
    my $min_charclass2   = 2;		## not used
    my $gecos_string_len = 4;

    
    my %specials = (	"left   bracket"      => "[",  
                        "right  bracket"      => "]",
                        "left  parenthesis"   => "(",
                        "right parenthesis"   => ")",
                    #	"left  Brace"         => "{", 		##not accpetable by MS ??? 
                    #	"right Brace"         => "}",
                        hash                  => '#',
                        caret				  => '^',
                        colon				  => ':',
                        comma				  => ',',
                        "semi-colon"		  => ';',
                        "exclamation mark"    => '!',
                        "vertical bar"        => '|',
                        ampersand			  => '&',
                        underscore            => '_',
                        backtick			  => '`',
                        tilde				  => '~',
                        at 			          => '@',
                        dollar 		          => '$',
                        percent		 	      => '%',
                        slash 		 		  => "\/",
                        backslash     		  => "\\",
                        equal			 	  => '=',
                        plus			 	  => '+',
                        minus			      => '-',
                        asterisk              => '*',
                    );

                      
1;

sub get_catmail { return @cats_mail; }

sub special_characters {
    ## reference http://www.sussex.ac.uk/its/help/faq?faqid=839
    # define the accepctable Special character table for passwords
    # return a scalar which is a help text w annotated lsi of chars
    # return a array ref of the acceptbale chars
    

    my $j = 0;
    my $ncols = 5;
    my @others = ();
    my $special_list = "\n The list of acceptable special characters are ...\n";
    foreach my $c ( sort { $specials{$a} cmp $specials{$b}} keys %specials ) {
        push @others, $specials{$c};
        $j++;
        $special_list .= sprintf "%17s %s  ", $c, $specials{$c} ;
        $special_list .= "\n" unless  $j%$ncols;
    }
    $special_list .= "\n";
    
  
    return $special_list, \@others;
}

sub do_protofiles {
    use File::Copy;
    my $def_protodir = "/home/prototype/default/";

    my $protodir = shift;
    my $homedir  = shift;
    my $uid      = shift;
    my $gid      = shift;
    $protodir = $protodir ? $protodir : $def_protodir;
    die "ERROR: No $protodir! " unless  -d $protodir;
    
    opendir (PD, $protodir) || die "Cannot open dir $protodir";
    my $file ="";
    while (defined ($file = readdir PD) ) {
        next if $file =~/^\.\.?$/;          #skip "." & ".."
        next unless $file =~ /^./;          # skip non "." files
		my $src = $protodir . $file;
        my $dest = $homedir . $file;
        copy($src,$dest) or die "Copy failed: $!";
        chown $uid, $gid, $dest;
    }
}

sub get_username {
	my $guess = shift;
	my $have_goodun = 0;
	my $username ="";
	while (! $have_goodun) {
		$username = lc( Ask("Enter preferred uname 2-32 chars ", $guess) );
		
		if (length($username) <2 ) { print "username {$username} too short! must be >2 \n";
			                         next;
		}
	    if (length($username) > 20 ) {print "username {$username} too long! must be <20 \n" ;
		                             next;
		}
		if ( $exists = account_exists($username) ) {
				print "Username $username is a valid email username or alias already.  Choose another one.\n";
				next;
		}
		$have_goodun++;
	}
	return $username;
}

sub account_exists {
   my $username = shift;
   
    foreach my $filename (    $aliases, $pwfile  ) {
       $exists = `grep "^$username:" $filename`;
       if ( $exists ) { return 1; }
   }
   
   #foreach my $filename (  $userdb,  $aliases, $pwfile, $shadow) {
   #    $exists = `grep "^$username:" $filename`;
   #    if ( $exists ) { return 1; }
   #}
   return 0;
}

sub get_studentnumber {
	my $category = shift;
	use lib "/opt/sysadmin/common/lib";
	use phasDB_users;

    my $snum = "";
	my $goon = 1;
	
	if ( $category ne "Ugrad" and
		 $category ne "Grads") { return "Not applicable"; }
	
SN:	while ($goon) {
		$snum  = Ask ( "Enter the Student Number");
		if ( !($snum =~ /^\d\d\d\d\d\d\d\d$/) ) {
			print "\nLooking for an 8-digit number here.  Try again.\n ";
			next SN;
		}
		elsif ( phasDB_users::have_student_number("", $snum) ) {
			print "student Number {$snum} is currently in DB Try again.\n";
		    $goon = 1;
		}
		else {
			$goon = 0;
		}
    }
	return $snum;
}

sub get_uid {
	my $category = shift;
	my $cat = ($category eq "Ugrad") ? "Ugrad" : "Other";
	my %uidlimits = ( Ugrad => { minuid => 15001,
								 maxuid => 19000},
					  Other => { minuid => 5001,
								 maxuid => 10000},		 
					);
	for ( $count = $uidlimits{$cat}->{minuid}; $count < $uidlimits{$cat}->{maxuid}; $count++) {
		my @F = getpwuid($count);
   
		if ( ! $F[2] ) {
			$uid = $count;
			return $uid;
		}
    }
    die "Could not find a uid in the range for {$cat} $uidlimits{$cat}->{minuid} : $uidlimits{$cat}->{maxuid} \n";
}

sub get_gid {
	my $uid  = shift;
	my $help = " convention is that GID is set to the UID";
    my $gid  = "";
    
    while ($gid !~ /^\d+$/) {
        $gid =  Ask ("Enter Group Id ", $uid, $help );
    }
    return $gid;
}

sub get_homedir {
	my $cat      = shift;
	my $username = shift;
	
	
	my %homebase = ( Ugrad => "/home2/",
					 Grads => "/home2/",
					 AGrad => "/ahome/",
		             others   => "/home/" );
	
	if ( $cat ne 'Ugrad' and $cat ne 'Grads' and $cat ne 'Agrad') {
		$cat = 'others';
	}
	
	my $h    = $homebase{$cat} . $username;
	my $home =  Ask ("Enter Home Directory", $h,  );
	return $home;
}

sub get_expdate {

	use Date::Calc qw (Today);
	my $category = shift;
	my $help = "This is to notify systems staff when a user has overstayed their welcome \n"; 
	my ($y, $m, $d) = Today(); 
	
    if ( $category eq "Visitor" || $category eq "Misc" ) {
		$y++;
		$m++;
        $expdate= sprintf "%4d%2.2d01",$y,$m;
	} elsif ( $category eq "Ugrad") {
		$y = $y + 2;
		$expdate = sprintf "%4d0901",$y; 
	} else {
		$expdate = "20290101"; 
	}
	my $xdate =  Ask ("Enter Best by Date", $expdate, $help );
	return $xdate;
}

sub get_diskquota {
	my $category = shift;
	my $help = qq { This appears to be an arbritary string...\n};
	my %quota = ( 	"System",    "disk100",
					"Ugrad",     "disk20",
					"Adj-Assoc", "disk100",
					"Faculty",   "disk100",
					"Grads",     "disk100",
					"Others",    "disk100",
					"Postdocs",  "disk100",
					"Staff",     "disk100",
					"Misc",      "disk100",
					"Visitor",   "disk100",
	);
	my $q =  Ask ("Enter quota", $quota{$category}, $help );
	return $q;
}

sub get_category {
	use List::MoreUtils qw (none);
#	use List::Util qw(none);
	# Get $category
	$default = "Visitor";
	
	my $help = "An Explanation of Categories: \n";
    foreach my $c  ( 0 .. $#cats_all ) {
        $help .= sprintf "%10s : %s\n", $cats_all[$c], $cats_help[$c];
    }

	my $cat = "x";
    my $goon = 1;

	while ( $goon == 1) {
		$cat =  Ask ("Enter Category (@cats_all)", $default, $help );
		if (none {$cat eq $_} @cats_all) { print "invalid category, try again\n"; }
		else                             { $goon = 0;}
	}
    
	return $cat;
}

sub get_account {
	use List::MoreUtils qw( none );

	my $category = shift;
	my $default = ( $category eq "Grads" ) ? "Dept" : "Cash";
	my @accounts  = get_accounts_list();
	my $help = "This is a list of possible codes to link to a ledger for print charges\n";
	my $i = 0;
	foreach my $c (sort @accounts) {
		$help .= "\n" if $i%4 == 0;
		$help .= sprintf "%16s ", $c;
		$i++; 
	}
	$help .= "\n";
	
	my $goon = 1;
	my $account =  "";
	while ( $goon == 1) {
		$account = Ask("Enter prnt_acct for Category = $category  ", $default, $help);
		if (none {$account eq $_} @accounts) { print "invalid account for  print charges, try again\n"; }
		else                          		 { $goon = 0; }
	}	
	return $account;
}

sub get_accounts_list {
    use DBI;
    ## get a list of poss
  
     # get list of faculty lastnames from directory
     my $dir_db = DBI->connect("DBI:mysql:directory:mysql.phas.ubc.ca","sel_only","not-bad")
	          || report_problem("SQL Connect error: $DBI::errstr");
     my $dir_sql = "SELECT DISTINCT LastName FROM department WHERE 
                           EmailList='Faculty' OR EmailList='Adj-Assoc' 
                        OR Position LIKE '%Grad Sup%' OR GradSup='y' ORDER BY LastName";
     my $dir_select= $dir_db->prepare($dir_sql);
     $dir_select->execute() || report_problem("SQL error: $DBI::errstr");
     while ( my $dir_ref = $dir_select->fetchrow_hashref()) {
          my $lastname = $dir_ref->{'LastName'};
     	  $lastname  =~ tr/ //d;
          push @accounts, $lastname;
     }
     $dir_select->finish();
     $dir_db->disconnect();
     # add print codes from accounts database
     my $acct_db = DBI->connect("DBI:mysql:accounts:mysql.phas.ubc.ca","acct-read","237_get!real")
	          || report_problem("SQL Connect error: $DBI::errstr");
     my $acct_sql = "SELECT DISTINCT *  FROM main WHERE 
			    ptr_code !='' AND ptr_code IS NOT NULL ORDER BY ptr_code";
     my $acct_select= $acct_db->prepare($acct_sql);
     $acct_select->execute() || report_problem("SQL error: $DBI::errstr");
     while ( my $acct_ref = $acct_select->fetchrow_hashref()) {
          my $ptr_code = $acct_ref->{'ptr_code'};
          my $inactive = $acct_ref->{'Active'};
        #  print "$ptr_code is $inactive\n";
          next if $inactive;
          push @accounts, $ptr_code;
     }
     $acct_select->finish();
     $acct_db->disconnect();
    
     # add any other account codes in use
     my $sysadm_db = DBI->connect("DBI:mysql:sysadmin:mysql.phas.ubc.ca","sel_only","not-bad")
	          || report_problem("SQL Connect error: $DBI::errstr");
     my $sysadm_sql = "SELECT DISTINCT account FROM phas_users WHERE 
			    account !='' AND account IS NOT NULL ORDER BY account";
     my $sysadm_select= $sysadm_db->prepare($sysadm_sql);
     $sysadm_select->execute() || report_problem("SQL error: $DBI::errstr");
     while ( my $sysadm_ref = $sysadm_select->fetchrow_hashref()) {
          my $sysacct = $sysadm_ref->{'account'};
      #    print "account from phas-users {$sysacct}\n "; 
          push @accounts, $sysacct;
     }
     $sysadm_select->finish();
     $sysadm_db->disconnect();
     
    my %codes =();
    foreach my $c (@accounts) {
#        printf "acc %17s\n ", $c;
        $c = ucfirst $c ;
        $codes{$c}++;
    }
    return keys %codes;
}

sub confirm_input {
	my $udata_ref = shift;
	my %udata = %$udata_ref;
	my @porder = qw (	username   fullname   	category    studentno 
						uid        gid       	shell       homedir  
						expdate    diskquota    account     printquota
					);
	my %prompts = (	username  	=> "Username",
					fullname  	=> "FullName", 
					category  	=> "Category",
					studentno  	=> "StudentNo",
					uid   		=> "UID",
					gid   		=> "GID",
					shell   	=> "Shell",
					homedir   	=> "homedir",
					expdate   	=> "ExpDate",
					diskquota 	=> "diskquota",
					account   	=> "Print_Account",
					printquota  => "Print_Quota",
				);

	print " \nPlease confirm these paramters are to used for account creation \n\n";  
	
	foreach my $p ( @porder ) {
		printf "%15s: %s\n",$prompts{$p}, $udata{$p};
	}
	my $ans = Ask ("Confirm [Y continues: N goes back]", "Y",);
}

sub mk_homedir {
	#Make directory and copy environment files
	use File::Copy;
	my $uid      = shift;
	my $gid      = shift;
	my $hdir     = shift;
	my $protodir = shift;
	
    if ( $hdir =~ /^([a-z0-9-_\/]+)$/ ) { $hdir = $1; }
	else                                  { die "Bad data in home dir [$hdir]"; }
	if ( ! $uid =~ /^([0-9]+)$/ ) { die "Bad data in $uid"; }
    if ( ! $gid =~ /^([0-9]+)$/ ) { die "Bad data in $gid"; }
    
    mkdir  $hdir, 0750;
    chown $uid, $gid, $hdir;
	
	if ( -d $protodir ) {
		opendir (P,  $protodir) || die "can't opendir $protodir: $!\n";
		while (defined ($f = readdir P) ) {
			next if /^\.\.?$/;
			my $xf = untaint ($f);
			if ($xf) {
				$xf = $protodir . "/" . $xf;
				my $h =  $hdir . "/" . $xf;
				copy ($xf, $h) || warn " cannot copy $protodir/$f $!\n";
				chown $uid, $gid, $h;
				chmod 0744, $h;
			} else {
				warn "$f was Tainted.  I will not copy !!";
			}
		}
    }
	return 1;
}
	
sub untaint {
	my $in = shift;
	my $out = "";
	if ($in =~ /^([A-Za-z-_\.]+)$/ ) {
		$out = $1;
	}
	return $out;
}

sub get_password {
    my $uid = shift;
    my $approp = $passwddir."appropriate.txt"; 	# UBC's Appropriate Use statement
    my $pwhelp = $passwddir."passwd.txt";		# help info. on password setting
    my $pass1 = "";
    {
        open my $fh, '<', $approp or warn "cannot open $approp\n";
		local $/ = undef;
		$data = <$fh>;
		close $fh;
	}
    
    if ( Ask("Want to set password for this id? ", "Yes") !~ /^y/i) {
        print "Terminating addusr.\n"; exit 0;}
	else {
		system "clear";
		print  $data
;
		if (Ask("DO YOU AGREE TO THESE TERMS?", "no", $pwhelp ) !~/^n/i) {
 
			while ($pass1 eq "") {
			    my $try  = get_Pass_from_Terminal();
			    if ( validate_Pass($try,$uid) ) {
			        my $retry = get_Pass_from_Terminal("Please Re-enter your password :");
			        if ($try eq $retry) { $pass1 = $try;}
			        else                { print "Password do not match, try again!\n\n";}
				}
			}
		}    
	}
    return $pass1;
}

sub get_Pass_from_Terminal {

    my $prompt = shift;
    my $nohrlp = shift;
    my $sc = join "", values %specials;
    
    
    print <<"EndofPWRules" unless $nohelp;
    
    
    Rules enforced for an acceptable password;  
        1.  length < 129 characters (maximum)
        2.  length > 12  characters (minimun)
        3. at least 1 character from EACH of the 4 character classes
            character class are;
            i. ASCII Lower Case Characters -- [a-z]
           ii. ASCII Upper Case Characters -- [A-Z]
          iii. Numeric charaters  [0-9]
           iv. Special characters ( $sc )
        4. qwerty (keyboard) sequences are not allowed ( eg qwer/vbnm )
        5. 4 character fragments of the full name are not allowed
        
    Note asteriks, "*", will be displayed in place of the typed characters 
           
        
EndofPWRules


	$prompt = "Enter a password" unless $prompt;
    use Term::ReadKey;

	ReadMode('cbreak');
    my $pass = '';
    my $DEL = 127;
    my $BACKSPACE = 8;

    print " $prompt :";
    while ( ! $pass ) {
        my $c;
        while (1) {
          1 until defined ($c = ReadKey(-1)) ;
          last if $c eq "\n";
          if ((ord $c eq $DEL) or (ord $c eq $BACKSPACE)) { print "\b \b"; chop $pass;}
          else                                            { print "*";  $pass .= $c;}
        }
    }

    ReadMode('restore');
	print "\n";
    return $pass;
}

sub validate_Pass {
    use English;
    my $str    = shift;
    my $uid    = shift;

    my $min_length  = 12;
    my $min_length2 = 15;			## not used
    my $max_length  = 128;
    my $min_charclass    = 4;
    my $min_charclass2   = 2;		## not used
    my $gecos_string_len = 4;

 
# At least more than $min_length characters
    if (length($str) < $min_length) {
        print "Please use at least $min_length characters\n";
        return 0;
    }

# check the number of char classes
    my $nupper++ if  ( map {$str =~ /$_/} @pw_upper);
    my $nlower++ if  ( map {$str =~ /$_/} @pw_lower);
    my $ndigit++ if  ( map {$str =~ /$_/} @pw_digit);
    my $nother++ if  ( map { my $x = q{\\} . $_;  $str =~ /$x/}  @pw_other);
    my $char_err = "";
    $char_err .= " You must in at least 1 upper case letter\n"   unless ( $nupper);
    $char_err .= " You must in at least 1 lower case letter\n"   unless ( $nlower);
    $char_err .= " You must in at least 1 numerical character\n" unless ( $ndigit);
    $char_err .= " You must in at least 1 other character\n"     unless ( $nother);
    
    if  ( $char_err ) {
        print $char_err;
        return 0;
    }
# Embedded null can spoof crypt routine.
    if ($str =~ /\0/) {
        print "Please don't use the null character in your password.\n";
        return 0;
    }
 
# Single quote can't get through to PDC
    if ( $str =~ /\'/ ) {
        print "Please don't use single quotes.\n";
        return 0;
    }

# Horizontal tab can't get through to LDAP
    if ($str =~ /\11/) {
        print "Please don't use the tab character in your password.\n";
        return 0;
    }
#    my $regex = qr/(.)\1{4,}/;

    if ( my $err = kybd_patterns($str) ) {
        print $err;
        return 0;
    }
    
    if ($uid ) {                # for current users only
        if ($EFFECTIVE_USER_ID == 0) {
            $current_pw = (getpwuid($uid))[1];
#print "validate_Pass line 580; current  [$current_pw] uid [$uid]\n";
            if ($current_pw  and
                crypt($str, $current_pw) eq $current_pw) {
            	print "Please use a different password than your current one\n";
                return 0;
            }
        } else { print "I need root privs, to compare the old passwd\n"}
	}
	return 1;
}

sub kybd_patterns {
    my $str = shift;
    my $pat_limit = 4;
    my $row0 = "1234567890"; 
    my $row1 = "qwertyuiop";
    my $row2 = "asdfghjkl";
    my $row3 = "zxcvbnm";
    
    foreach my $test ( $row0, $row1, $row2, $row3) {
        foreach $off ( 0 .. ( (length $test) - $pat_limit ) ) {
            $sub = substr ( $test, $off, $pat_limit );
            if ($str =~ /$sub/ ) {
                return "$sub is  a keyboard  pattern-- do not use";
            }
        }
    }
    return 0;
}

sub Ask  {
	 my $prompt  = shift;
	 my $default = shift;
	 my $helpx    = shift;
	 my $maxplen  = 25;
	 my $answer = "";
	 
	while ( ! $answer ) {
		if ($default ) { printf ("%25s [%s] >", $prompt, $default); }
		else           { printf "%25s >", $prompt;                  }
		chomp($answer=<STDIN>);
		$answer = $default if ($answer eq "");
		if ($answer eq "?") { 
			print $helpx;
			$answer = "";
		}
		
	}
	return $answer;
}