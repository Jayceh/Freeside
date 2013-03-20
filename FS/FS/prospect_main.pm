package FS::prospect_main;

use strict;
use base qw( FS::Quotable_Mixin FS::o2m_Common FS::Record );
use vars qw( $DEBUG @location_fields );
use Scalar::Util qw( blessed );
use FS::Record qw( dbh qsearch qsearchs );
use FS::agent;
use FS::cust_location;
use FS::contact;
use FS::qual;

$DEBUG = 0;

#started as false laziness w/cust_main/Location.pm

use Carp qw(carp);

my $init = 0;
BEGIN {
  # set up accessors for location fields
  if (!$init) {
    no strict 'refs';
    @location_fields = 
      qw( address1 address2 city county state zip country district
        latitude longitude coord_auto censustract censusyear geocode
        addr_clean );

    foreach my $f (@location_fields) {
      *{"FS::prospect_main::$f"} = sub {
        carp "WARNING: tried to set cust_main.$f with accessor" if (@_ > 1);
        my @cust_location = shift->cust_location or return '';
        #arbitrarily picking the first because the UI only lets you add one
        $cust_location[0]->$f
      };
    }
    $init++;
  }
}

#debugging shim--probably a performance hit, so remove this at some point
sub get {
  my $self = shift;
  my $field = shift;
  if ( $DEBUG and grep { $_ eq $field } @location_fields ) {
    carp "WARNING: tried to get() location field $field";
    $self->$field;
  }
  $self->FS::Record::get($field);
}

=head1 NAME

FS::prospect_main - Object methods for prospect_main records

=head1 SYNOPSIS

  use FS::prospect_main;

  $record = new FS::prospect_main \%hash;
  $record = new FS::prospect_main { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::prospect_main object represents a prospect.  FS::prospect_main inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item prospectnum

primary key

=item agentnum

Agent

=item company

company

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new prospect.  To add the prospect to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'prospect_main'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;
  my %options = @_;
  warn "FS::prospect_main::insert called on $self with options ".
       join(', ', map "$_=>$options{$_}", keys %options)
    if $DEBUG;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  warn "  inserting prospect_main record" if $DEBUG;
  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $options{'cust_location'} ) {
    warn "  inserting cust_location record" if $DEBUG;
    my $cust_location = $options{'cust_location'};
    $cust_location->prospectnum($self->prospectnum);
    $error = $cust_location->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  warn "  commiting transaction" if $DEBUG;
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

=item delete

Delete this record from the database.

=cut

#delete dangling locations?

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my $new = shift;

  my $old = ( blessed($_[0]) && $_[0]->isa('FS::Record') )
              ? shift
              : $new->replace_old;

  my %options = @_;

  warn "FS::prospect_main::replace called on $new to replace $old with options".
       " ". join(', ', map "$_ => ". $options{$_}, keys %options)
    if $DEBUG;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  warn "  replacing prospect_main record" if $DEBUG;
  my $error = $new->SUPER::replace($old);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $options{'cust_location'} ) {
    my $cust_location = $options{'cust_location'};
    $cust_location->prospectnum($new->prospectnum);
    my $method = $cust_location->locationnum ? 'replace' : 'insert';
    warn "  ${method}ing cust_location record" if $DEBUG;
    $error = $cust_location->$method();
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  } elsif ( exists($options{'cust_location'}) ) {
    foreach my $cust_location (
      qsearch('cust_location', { 'prospectnum' => $new->prospectnum } )
    ) {
      $error = $cust_location->delete();
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }

  warn "  commiting transaction" if $DEBUG;
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

=item check

Checks all fields to make sure this is a valid prospect.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('prospectnum')
    || $self->ut_foreign_key('agentnum', 'agent', 'agentnum' )
    || $self->ut_textn('company')
  ;
  return $error if $error;

  my $company = $self->company;
  $company =~ s/^\s+//; 
  $company =~ s/\s+$//; 
  $company =~ s/\s+/ /g;
  $self->company($company);

  $self->SUPER::check;
}

=item name

Returns a name for this prospect, as a string (company name for commercial
prospects, contact name for residential prospects).

=cut

sub name {
  my $self = shift;
  return $self->company if $self->company;

  my $contact = ($self->contact)[0]; #first contact?  good enough for now
  return $contact->line if $contact;

  'Prospect #'. $self->prospectnum;
}

=item contact

Returns the contacts (see L<FS::contact>) associated with this prospect.

=cut

sub contact {
  my $self = shift;
  qsearch( 'contact', { 'prospectnum' => $self->prospectnum } );
}

=item cust_location

Returns the locations (see L<FS::cust_location>) associated with this prospect.

=cut

sub cust_location {
  my $self = shift;
  qsearch( 'cust_location', { 'prospectnum' => $self->prospectnum,
                              'custnum'     => '' } );
}

=item qual

Returns the qualifications (see L<FS::qual>) associated with this prospect.

=cut

sub qual {
  my $self = shift;
  qsearch( 'qual', { 'prospectnum' => $self->prospectnum } );
}

=item agent

Returns the agent (see L<FS::agent>) for this customer.

=cut

sub agent {
  my $self = shift;
  qsearchs( 'agent', { 'agentnum' => $self->agentnum } );
}

=item search HASHREF

(Class method)

Returns a qsearch hash expression to search for the parameters specified in
HASHREF.  Valid parameters are:

=over 4

=item agentnum

=back

=cut

sub search {
  my( $class, $params ) = @_;

  my @where = ();
  my $orderby;

  ##
  # parse agent
  ##

  if ( $params->{'agentnum'} =~ /^(\d+)$/ and $1 ) {
    push @where,
      "prospect_main.agentnum = $1";
  }

  ##
  # setup queries, subs, etc. for the search
  ##

  $orderby ||= 'ORDER BY prospectnum';

  # here is the agent virtualization
  push @where, $FS::CurrentUser::CurrentUser->agentnums_sql;

  my $extra_sql = scalar(@where) ? ' WHERE '. join(' AND ', @where) : '';

  my $count_query = "SELECT COUNT(*) FROM prospect_main $extra_sql";
  
  my $sql_query = {
    'table'         => 'prospect_main',
    #'select'        => $select,
    'hashref'       => {},
    'extra_sql'     => $extra_sql,
    'order_by'      => $orderby,
    'count_query'   => $count_query,
    #'extra_headers' => \@extra_headers,
    #'extra_fields'  => \@extra_fields,
  };

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

