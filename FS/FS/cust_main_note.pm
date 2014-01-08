package FS::cust_main_note;
use base qw( FS::otaker_Mixin FS::Record );

use strict;
use Carp;
use FS::Record qw( qsearchs ); #qw( qsearch qsearchs );

=head1 NAME

FS::cust_main_note - Object methods for cust_main_note records

=head1 SYNOPSIS

  use FS::cust_main_note;

  $record = new FS::cust_main_note \%hash;
  $record = new FS::cust_main_note { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_main_note object represents a note attachted to a customer.
FS::cust_main_note inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item notenum

primary key

=item custnum

=item classnum

=item _date

=item usernum

=item comments

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new customer note.  To add the note to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_main_note'; }

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

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('notenum')
    || $self->ut_number('custnum')
    || $self->ut_foreign_keyn('classnum', 'cust_note_class', 'classnum')
    || $self->ut_numbern('_date')
    || $self->ut_textn('otaker')
    || $self->ut_anything('comments')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item cust_note_class

Returns the customer note class, as an FS::cust_note_class object, or the empty
string if there is no note class.

=item classname 

Returns the customer note class name, or the empty string if there is no 
customer note class.

=cut

sub classname {
  my $self = shift;
  my $cust_note_class = $self->cust_note_class;
  $cust_note_class ? $cust_note_class->classname : '';
}


#false laziness w/otaker_Mixin & cust_attachment
sub otaker {
  my $self = shift;
  if ( scalar(@_) ) { #set
    my $otaker = shift;
    my($l,$f) = (split(', ', $otaker));
    my $access_user =  qsearchs('access_user', { 'username'=>$otaker }     )
                    || qsearchs('access_user', { 'first'=>$f, 'last'=>$l } )
      or croak "can't set otaker: $otaker not found!"; #confess?
    $self->usernum( $access_user->usernum );
    $otaker; #not sure return is used anywhere, but just in case
  } else { #get
    if ( $self->usernum ) {
      $self->access_user->username;
    } elsif ( length($self->get('otaker')) ) {
      $self->get('otaker');
    } else {
      '';
    }
  }
}

# Used by FS::Upgrade to migrate to a new database.
sub _upgrade_data {  # class method
  my ($class, %opts) = @_;
  $class->_upgrade_otaker(%opts);
}

=back

=head1 BUGS

Lurking in the cracks.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

