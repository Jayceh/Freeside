package FS::Auth::legacy;
#use base qw( FS::Auth ); #::internal ?

use strict;
use Apache::Htpasswd;

#substitute in?  we're trying to make it go away...
my $htpasswd_file = '/usr/local/etc/freeside/htpasswd';

sub authenticate {
  my($self, $username, $check_password ) = @_;

  Apache::Htpasswd->new( { passwdFile => $htpasswd_file,
                           ReadOnly   => 1,
                         }
    )->htCheckPassword($username, $check_password);
}

sub autocreate { 0; }

# for legacy, if have a good cookie they don't need any extra verification
sub verify_user {
  return 1;
}

#don't support this in legacy?  change in both htpasswd and database like 3.x
# for easier transitioning?  hoping its really only me+employees that have a
# mismatch in htpasswd vs access_user, so maybe that's not necessary
#sub change_password {
#}

1;
