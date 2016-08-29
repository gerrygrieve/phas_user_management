package phas_LDAP;

# Description:  provide CRUD functions for the LDAP servers
#				currently in use.

use Config::Tiny;
use Net::LDAP;
use Net::LDAP::Extension::SetPassword;
use Carp;

my $cfile = '/opt/sysadmin/common/lib/ldap_conf.file';
my $Config = Config::Tiny->new;
$Config = Config::Tiny->read( $cfile );

my @attrs = qw (  objectClass gecos cn
                  uidNumber gidNumber loginShell homeDirectory uid);
my @ldap_servers = keys %{$Config};

1;

sub _connect {
	my $this_server = shift;
	my $ldap = Net::LDAP->new( 	$Config->{$this_server}->{'server'},
								version => 3 )
       or
       croak "$this_server error: Cannot create new LDAP object - $@";

	my $result = $ldap->start_tls( verify => 'none',        
								   cafile => $Config->{$this_server}->{cafile}
							     );
	croak "$this_server  error: ", $result->code, ": ", $result->error() if ($result->code());


	$result = $ldap->bind($Config->{$this_server}->{root_dn},
                        password=>$Config->{$this_server}->{'auth'});
	croak "$this_server  error: ", $result->code, ": ", $result->error() if ($result->code());

	return $ldap;
}

#Description: for a given "uid" {(aka username )  ldap's schema uses uidNumber
# for the unix uid.} return a  reference to a hash indexed by uid.
# for eaxmaple a query for uid="bboop" will return something like
#        %attrs = {
#					objectClass   =>  posixAccount 
  #					gecos         =>  Betty Boop 
  #					cn            =>  Betty Boop 
  #					uidNumber     =>  2147 
  #					gidNumber     =>  307 
  #					loginShell    =>  /bin/bash 
  #					homeDirectory =>  /home/bboop 
 #					}


sub query {
	my $uid = shift;
	my $server = shift;

	my $ldap = _connect($server );
	my $result = $ldap->search(	base   => $Config->{$server}->{base_dn},
					            filter => "(uid=bboop)",
                                );
	croak "$server  error: ", $result->error if $result->code;

	my %attrs = ();
	if  ($result->count == 1 ) {
		my @entries = $result->entries;
		my $entry = $entries[0];
		
		foreach my $kk ( @attrs ) {
			next if ($kk eq 'uid');
			my $val = $entry->get_value ( $kk );
			$attrs{$kk} = $val;
		}
	} elsif ($result->count > 1 ) {
		print $result->count,  " records found for $uid\n";
	} else {
		print " no records found for $uid\n";
	}
	return \%attrs;
}

sub delete {
	my $uid = shift;
	my $server = shift;

	my $ldap = _connect($server);
	my $result = $ldap->search(	base   => $Config->{$server}->{base_dn},
					            filter => "(uid=$uid)",
                                );
	croak "$server  error: ", $result->error if $result->code;

	if  ($result->count eq 1) {		# good ... found 1 & only 1 
		 $result = $ldap->delete("uid=$uid,".$Config->{$server}->{dn_suffix});

	} else {
		print " no records found for $uid\n";
	}
	return \%attrs;
}

sub update_pw {
	my $uid = shift;
	my $pw  = shift;
	my $server = shift;

	my $ldap = _connect($server);
 # check if LDAP account already exists
	my $result = $ldap->search(	base   => $Config->{$server}->{base_dn},
					            filter => "(uid=$uid)",
                                );
	croak "$server  error: ", $result->error if $result->code;

	if ( $result->count == 1 ) { # account exists - just change password
		$result = $ldap->set_password ( user => "uid=$uid,".$Config{"dn_suffix"},
                                      newpasswd => $pw );
		croak "error: ", $result->code, ": ", $result->error() if ($result->code());
	} elsif ($result->count == 0 ) {
		croak "No entry found for $uid\n";
	} elsif ($result->count > 1 ) {
		croak $result->count , " No entry found for $uid\n";
	}

}

sub add_LDAP_user {
    my $user_data = shift;
	my $server = shift;

	my %udata = %$user_data;
	my $uid = $udata{uid};
	my $ldap = _connect($server);

 # check if LDAP account already exists
	my $result = $ldap->search(	base   => $Config->{$server}->{base_dn},
					            filter => "(uid=$uid)",
                              );
	croak "$server  error: ", $result->error if $result->code;

	if ($result->count == 0 ) {

		$mesg = $ldap->add("uid=$uid,".$Config{"dn_suffix"},
						attrs => [
									"objectclass"   => $Config{"obj_class"},
									"uidNumber"     => $udata{uid},
									"gidNumber"     => $udata{gid},
									"cn"            => $udata{gcos},
									"gecos"         => $udata{gcos},
									"sn"            => $udata{lastname},
									"givenName"     => $udata{firstname},
									"homeDirectory" => $udata{homedir},
									"loginShell"    => $udata{shell},
									"mail"          => $uid . "\@phas.ubc.ca",
									"userPassword"  => $udata{pwd}
								 ] );
        die "error: ", $mesg->code, ": ", $mesg->error() if ($mesg->code());
# set password for new account
 
		$mesg = $ldap->set_password ( user => "uid=$uid,".$Config{"obj_class"},
									  newpasswd => $udata{pwd});
	
	} elsif ( $result->count == 1 ) { # account exists - just change password
		croak "$uid already exists \n";
	} 

}