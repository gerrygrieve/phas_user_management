package phas_PDC;

my $PDC="phaspdc.phas.ubc.ca";  # Windows domain controller
my $sshcmd="/usr/bin/ssh administrator\@$PDC";
my $PS_cmd = "$sshcmd powershell.exe -InputFormat None d:\\\\scripts\\\\";

1;

sub delete_User {

	use Carp;
	my $userid = shift;

#untaint userid ..
	if ( $userid =~ m{^(\w)+$} ) {
		$userid = $1;
	} else {
		croak  "userid [$userid] is tainted, delete_User bailing\n";
	}
	print "Deleting acct from Windows PDC...";
   
    system("$sshcmd administrator\@phaspdc powershell.exe -InputFormat None d:\\\\scripts\\\\RemoveUser.ps1 $userid >/dev/null");

	return;

}

sub change_PW {
	my $this_user = shift;
	my $pw   = shift;

	open (USERS, "$sshcmd net user $this_user |") ||
		die ("Something's  wrong with $PDC. Talk to systems people");
	while(<USERS>) {
	
        if (/The user name could not be found/) {
			print "no such user $this_user phas_PDC::change_PW bailing...\n";
            return;
		}
	}

	close(USERS);

    $cmd = $PS_cmd . "ChangeUserPwd.ps1 $this_user \\\'$pw\\\'";
## we have to unTaint a system cmd also 
	if ($cmd =~ /^(.*)$/) { $cmd = $1; }  # this does nothing !!

	system( $cmd );
	return;
}

sub add_User {

    my $udata_ref = shift;
    my %udata = %{$udata_ref};

	my $this_user = $udata{username} ;
	my $this_pass = $udata{pwd} ;
	my $this_gcos = $udata{fullname} ;
    my $this_cat  = $udata{category}; 
	
	$this_pass=~s/[\"]/'''$&'''/g;    				 # escape double quotes 
	$this_pass=~s/[\<\>\$()\&\|\;\@\\\"`]/\\$&/g;    # escape some special characters

	my @wingrp_Fac   =  qw (Others Adj-Assoc Faculty  Postdocs Visitor Emeritus);
    my @wingrp_Ugrad =  qw ( Ugrad Misc );

    if    (grep  { $this_cat eq $_ } @wingrp_Fac)    { $wingroup = 'Faculty';}
    elsif (grep  { $this_cat eq $_ } @wingrp_Ugrad)  { $wingroup = 'Ugrads' ;}
    elsif (        $this_cat eq 'Grads' )            { $wingroup = 'Grads';}
    elsif (        $this_cat eq 'Staff' )            { $wingroup = 'Staff';}
	else  {
		print " Invalid Category [$this_cat] -- phas_PDC::add_User quitting";
		return;
	}

	open (USERS, "$sshcmd net user $this_user |") ||
		die ("Something's  wrong with $PDC. Talk to systems people");
	while(<USERS>) {
	
        if (/The user name could not be found/) {
		#	print "no such user $this_user\n";
            last;
		}
		else {
			print " user [$this_user] exists, phas_PDC::add_User bailing...\n";
			return;
		}	
	}

	close(USERS);
 
	## create new account

	my $Add_cmd = $PS_cmd . "NewUser.ps1 $this_user \\\'$this_pass\\\' \\\'$this_cat\\\' \\\'$this_gcos\\\' \\\'$wingroup\\\'";

 ## we have to unTaint a system cmd also 
	if ($cmd =~ /^(.*)$/) { $cmd = $1; }  # this does nothing !!

	system( $cmd );

	return;
}