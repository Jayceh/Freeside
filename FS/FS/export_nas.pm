package FS::export_nas;
use base qw( FS::Record );

use strict;
use vars qw($noexport_hack);

$noexport_hack = '';

=head1 NAME

FS::export_nas - Object methods for export_nas records

=head1 SYNOPSIS

  use FS::export_nas;

  $record = new FS::export_nas \%hash;
  $record = new FS::export_nas { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::export_nas object links RADIUS exports (in the part_export table)
to RADIUS clients (in the nas table).  FS::export_nas inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item exportnasnum

primary key

=item exportnum

exportnum

=item nasnum

nasnum


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'export_nas'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;
  $self->SUPER::insert || 
  ($noexport_hack ? '' : $self->part_export->export_nas_insert($self->nas));
}

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;
  ($noexport_hack ? '' : $self->part_export->export_nas_delete($self->nas))
  || $self->SUPER::delete;
}

=item replace OLD_RECORD

Unavailable.  Delete the record and create a new one.

=cut

sub replace {
  die "replace not implemented for export_nas records";
}

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('exportnasnum')
    || $self->ut_foreign_key('exportnum', 'part_export', 'exportnum' )
    || $self->ut_foreign_key('nasnum', 'nas', 'nasnum')
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

