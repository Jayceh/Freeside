package FS::dsl_device;
use base qw( FS::Record );

use strict;

=head1 NAME

FS::dsl_device - Object methods for dsl_device records

=head1 SYNOPSIS

  use FS::dsl_device;

  $record = new FS::dsl_device \%hash;
  $record = new FS::dsl_device { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::dsl_device object represents a specific customer MAC address.  The 
following fields are currently supported:

=over 4

=item devicenum

primary key

=item svcnum

svcnum

=item mac_addr

mac_addr


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new device.  To add the device to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'dsl_device'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid device.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('devicenum')
    || $self->ut_foreign_key('svcnum', 'svc_dsl', 'svcnum' )
    || $self->ut_mac_addr('mac_addr')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item svc_dsl

Returns the DSL (see L<FS::svc_dsl>) associated with this customer
device.

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

