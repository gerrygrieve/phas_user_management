#!/usr/bin/perl

deleteIPA('xx');

sub deleteIPA 
{
use Net::LDAP;

   my $me=shift(@_);

   if ( !$me ) { return 1; }

   # set LDAP configuration options
   my %CONF = (
    "server"     => "ipa.phas.ubc.ca",
    "root_dn"    => "cn=Directory Manager",
    "base_dn"    => "cn=users,cn=compat,dc=phas,dc=ubc,dc=ca",
    "dn_suffix"  => "cn=users,cn=accounts,dc=phas,dc=ubc,dc=ca",
    "obj_class"  => ["posixAccount","top","person","organizationalPerson",
                     "inetOrgPerson","shadowAccount"],
    "cafile"     => '/etc/ldap/cacerts/ipa02.phas.ubc.ca.crt'
              );


   # read administrative ldap password out of /etc/ldap.secret. the password should
   # be the only line in that file, and should be by itself on the first line.
   open(PW,"</etc/ldap.secret") or die "ERROR: Cannot open ldap.secret file";
   chomp(my $secretpw = (<PW>)[0]);
   close(PW);
print " try connecting to  \n";
print " try connecting to $CONF{"server"} \n";
   # connect to ldap server
   my $ldap = Net::LDAP->new( $CONF{"server"}, version => 3 ) or
        die "IPA02 Cannot create new LDAP object - $@";

 print " connected ...\n";
exit;
   # using TLS
   my $mesg = $ldap->start_tls(
                           verify => 'none',
                           cafile => $CONF{"cafile"}
                         ); 
   die "IPA error: ", $mesg->code, ": ", $mesg->error() if ($mesg->code());

   # make ldap bind
   $mesg = $ldap->bind($CONF{"root_dn"},password=>$secretpw);
   die "IPA02 error: ", $mesg->code, ": ", $mesg->error() if ($mesg->code());

   # check if LDAP account exists
   $mesg = $ldap->search( 
                        base   => $CONF{"base_dn"},
                        filter => "(uid=$me)"
                      );
   die "IPA02 error: ", $mesg->code, ": ", $mesg->error() if ($mesg->code());

   if ( $mesg->count eq 1 ) { # account exists - pretend to delete it
##?? pretend??
      print "IPA02: Deleting LDAP record for $me.\n";
      $mesg = $ldap->delete("uid=$me,".$CONF{"dn_suffix"});
      die "error: ", $mesg->code, ": ", $mesg->error() if ($mesg->code());
      print "IPA02: LDAP record for $me has been deleted.\n";

   } elsif ( $mesg->count eq 0 ) { # account doesn't exist
      print "IPA02: No such LDAP user: $me:\n";

   } else {
      print "IPA02 Error - more than one entry for $me on LDAP server.\n";
   }

   # disconnect
   $mesg = $ldap->unbind;
}

1;

