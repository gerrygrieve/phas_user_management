package phas_SMB;

use Passwd::Samba;
my $smbpw = "/etc/samba/smbpasswd";

1;

sub delete_User {

	my $userid = shift;
    my $ps = Passwd::Samba->new();
    $ps->smbpasswd_file($smbpw);
    $ps->del($userid);

	return;
}

sub change_PW {
	my $this_user = shift;
	my $pw   = shift;

    my $ps  = Passwd::Samba->new();
    $ps->smbpasswd_file($smbpw);
    my $err = $ps->passwd($this_user, $pw );
    
    $myerr = "SMB passwd or $this_user NOT reset" unless $err;

	return $myerr;
}

sub add_User {
	my $this_user = shift;
	my $pw   = shift;

    my $ps = Passwd::Samba->new();
    $ps->smbpasswd_file($smbpw);
    my $err = $ps->user( $this_user, $pw );
 
	return;
}