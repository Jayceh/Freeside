package FS::vend_class;

use strict;
use base qw( FS::class_Common );
#use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::vend_class - Object methods for vend_class records

=head1 SYNOPSIS

  use FS::vend_class;

  $record = new FS::vend_class \%hash;
  $record = new FS::vend_class { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::vend_class object represents a vendor class.  FS::vend_class inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item classnum

primary key

=item classname

classname

=item disabled

disabled


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new vendor class.  To add the vendor class to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'vend_class'; }

sub _target_table { 'vend_main'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid vendor class.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('classnum')
    || $self->ut_text('classname')
    || $self->ut_enum('disabled', [ '', 'Y' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

