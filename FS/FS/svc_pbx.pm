package FS::svc_pbx;
use base qw( FS::o2m_Common FS::svc_External_Common );

use strict;
use Tie::IxHash;
use FS::Record qw( qsearch qsearchs dbh );
use FS::PagedSearch qw( psearch );
use FS::Conf;
use FS::cust_svc;
use FS::svc_phone;
use FS::svc_acct;

=head1 NAME

FS::svc_pbx - Object methods for svc_pbx records

=head1 SYNOPSIS

  use FS::svc_pbx;

  $record = new FS::svc_pbx \%hash;
  $record = new FS::svc_pbx { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_pbx object represents a PBX tenant.  FS::svc_pbx inherits from
FS::svc_Common.  The following fields are currently supported:

=over 4

=item svcnum

Primary key (assigned automatcially for new accounts)

=item id

(Unique?) number of external record

=item title

PBX name

=item max_extensions

Maximum number of extensions

=item max_simultaneous

Maximum number of simultaneous users

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new PBX tenant.  To add the PBX tenant to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'svc_pbx'; }

sub table_info {

  tie my %fields, 'Tie::IxHash',
    'svcnum' => 'PBX',
    'id'     => 'PBX/Tenant ID',
    'title'  => 'Name',
    'max_extensions' => 'Maximum number of User Extensions',
    'max_simultaneous' => 'Maximum number of simultaneous users',
  ;

  {
    'name' => 'PBX',
    'name_plural' => 'PBXs',
    'lcname_plural' => 'PBXs',
    'longname_plural' => 'PBXs',
    'sorts' => 'svcnum', # optional sort field (or arrayref of sort fields, main first)
    'display_weight' => 70,
    'cancel_weight'  => 90,
    'fields' => \%fields,
  };
}

=item search_sql STRING

Class method which returns an SQL fragment to search for the given string.

=cut

#XXX
#or something more complicated if necessary
#sub search_sql {
#  my($class, $string) = @_;
#  $class->search_sql_field('title', $string);
#}

=item label

Returns the title field for this PBX tenant.

=cut

sub label {
  my $self = shift;
  $self->title;
}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

=cut

sub insert {
  my $self = shift;
  my $error;

  $error = $self->SUPER::insert;
  return $error if $error;

  '';
}

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $svc_phone (qsearch('svc_phone', { 'pbxsvc' => $self->svcnum } )) {
    $svc_phone->pbxsvc('');
    my $error = $svc_phone->replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $svc_acct  (qsearch('svc_acct',  { 'pbxsvc' => $self->svcnum } )) {
    my $error = $svc_acct->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}


=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

#sub replace {
#  my ( $new, $old ) = ( shift, shift );
#  my $error;
#
#  $error = $new->SUPER::replace($old);
#  return $error if $error;
#
#  '';
#}

=item suspend

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item unsuspend

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item cancel

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid PBX tenant.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my $self = shift;

  my $x = $self->setfixed;
  return $x unless ref($x);
  my $part_svc = $x;


  $self->SUPER::check;
}

sub _check_duplicate {
  my $self = shift;

  my $conf = new FS::Conf;
  
  $self->lock_table;

  foreach my $field ('title', 'id') {
    my $global_unique = $conf->config("global_unique-pbx_$field");
    # can be 'disabled', 'enabled', or empty.
    # if empty, check per exports; if not empty or disabled, check 
    # globally.
    next if $global_unique eq 'disabled';
    my @dup = $self->find_duplicates(
      ($global_unique ? 'global' : 'export') , $field
    );
    next if !@dup;
    return "duplicate $field '".$self->getfield($field).
           "': conflicts with svcnum ".$dup[0]->svcnum;
  }
  return '';
}

=item psearch_cdrs OPTIONS

Returns a paged search (L<FS::PagedSearch>) for Call Detail Records 
associated with this service.  By default, "associated with" means that 
the "charged_party" field of the CDR matches the "title" field of the 
service.  To access the CDRs themselves, call "->fetch" on the resulting
object.

=over 2

Accepts the following options:

=item for_update => 1: SELECT the CDRs "FOR UPDATE".

=item status => "" (or "done"): Return only CDRs with that processing status.

=item inbound => 1: No-op for svc_pbx CDR processing.

=item default_prefix => "XXX": Also accept the phone number of the service prepended 
with the chosen prefix.

=item disable_src => 1: No-op for svc_pbx CDR processing.

=item by_svcnum => 1: Select CDRs where the svcnum field matches, instead of 
title/charged_party.  Normally this field is set after processing.

=item by_ip_addr => 'src' or 'dst': Select CDRs where the src_ip_addr or 
dst_ip_addr field matches title.  In this case, some special logic is applied
to allow title to indicate a range of IP addresses.

=item begin, end: Start and end of date range, as unix timestamp.

=item cdrtypenum: Only return CDRs with this type.

=item calltypenum: Only return CDRs with this call type.

=back

=cut

sub psearch_cdrs {
  my($self, %options) = @_;
  my %hash = ();
  my @where = ();

  my @fields = ( 'charged_party' );
  $hash{'freesidestatus'} = $options{'status'}
    if exists($options{'status'});

  if ($options{'cdrtypenum'}) {
    $hash{'cdrtypenum'} = $options{'cdrtypenum'};
  }
  if ($options{'calltypenum'}) {
    $hash{'calltypenum'} = $options{'calltypenum'};
  }

  my $for_update = $options{'for_update'} ? 'FOR UPDATE' : '';

  if ( $options{'by_svcnum'} ) {
    $hash{'svcnum'} = $self->svcnum;
  }
  elsif ( $options{'by_ip_addr'} =~ /^src|dst$/) {
    my $field = 'cdr.'.$options{'by_ip_addr'}.'_ip_addr';
    push @where, FS::cdr->ip_addr_sql($field, $self->title);
  }
  else {
    #matching by title
    my $title = $self->title;

    my $prefix = $options{'default_prefix'};

    my @orwhere =  map " $_ = '$title'        ", @fields;
    push @orwhere, map " $_ = '$prefix$title' ", @fields
      if length($prefix);
    if ( $prefix =~ /^\+(\d+)$/ ) {
      push @orwhere, map " $_ = '$1$title' ", @fields
    }

    push @where, ' ( '. join(' OR ', @orwhere ). ' ) ';
  }

  if ( $options{'begin'} ) {
    push @where, 'startdate >= '. $options{'begin'};
  }
  if ( $options{'end'} ) {
    push @where, 'startdate < '.  $options{'end'};
  }

  my $extra_sql = ( keys(%hash) ? ' AND ' : ' WHERE ' ). join(' AND ', @where )
    if @where;

  psearch( {
      'table'      => 'cdr',
      'hashref'    => \%hash,
      'extra_sql'  => $extra_sql,
      'order_by'   => "ORDER BY startdate $for_update",
  } );
}

=item get_cdrs (DEPRECATED)

Like psearch_cdrs, but returns all the L<FS::cdr> objects at once, in a 
single list.  Arguments are the same as for psearch_cdrs.  This can take
an unreasonably large amount of memory and is best avoided.

=cut

sub get_cdrs {
  my $self = shift;
  my $psearch = $self->psearch_cdrs($_);
  qsearch ( $psearch->{query} )
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>,
L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

