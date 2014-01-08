package FS::cgp_rule;
use base qw( FS::o2m_Common FS::Record );

use strict;
use FS::Record qw( dbh );

=head1 NAME

FS::cgp_rule - Object methods for cgp_rule records

=head1 SYNOPSIS

  use FS::cgp_rule;

  $record = new FS::cgp_rule \%hash;
  $record = new FS::cgp_rule { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cgp_rule object represents a mail filtering rule.  FS::cgp_rule
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item rulenum

primary key

=item name

name

=item comment

comment

=item svcnum

svcnum

=item priority

priority


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new rule.  To add the rule to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cgp_rule'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

#  sub insert {
#    my $self = shift;
#  
#    local $SIG{HUP} = 'IGNORE';
#    local $SIG{INT} = 'IGNORE';
#    local $SIG{QUIT} = 'IGNORE';
#    local $SIG{TERM} = 'IGNORE';
#    local $SIG{TSTP} = 'IGNORE';
#    local $SIG{PIPE} = 'IGNORE';
#  
#    my $oldAutoCommit = $FS::UID::AutoCommit;
#    local $FS::UID::AutoCommit = 0;
#    my $dbh = dbh;
#  
#    my $error = $self->SUPER::insert(@_);
#    if ( $error ) {
#      $dbh->rollback if $oldAutoCommit;
#      return $error;
#    }
#  
#    #conditions and actions not in yet
#    #$error = $self->svc_export;
#    #if ( $error ) {
#    #  $dbh->rollback if $oldAutoCommit;
#    #  return $error;
#    #}
#  
#    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
#    '';
#  }

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

  my @del = $self->cgp_rule_condition;
  push @del, $self->cgp_rule_action;

  foreach my $del (@del) {
    my $error = $del->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $self->SUPER::delete(@_);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $error = $self->svc_export;
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

sub replace {
  my $new = shift;

  my $old = ( ref($_[0]) eq ref($new) )
              ? shift
              : $new->replace_old;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $new->SUPER::replace($old, @_);
  if ( $error ) {
    $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
    return $error;
  }

  #conditions and actions not in yet
  #$error = $new->svc_export;
  #if ( $error ) {
  #  $dbh->rollback if $oldAutoCommit;
  #  return $error;
  #}

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item svc_export

Calls the replace export for any communigate exports attached to this rule's
service.

=cut

sub svc_export {
  my $self = shift;

  my $cust_svc = $self->cust_svc;
  my $svc_x = $cust_svc->svc_x;
  
  #_singledomain too
  my @exports = $cust_svc->part_svc->part_export('communigate_pro');
  my @errors = map $_->export_replace($svc_x, $svc_x), @exports;

  @errors ? join(' / ', @errors) : '';

}

=item check

Checks all fields to make sure this is a valid rule.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('rulenum')
    || $self->ut_text('name')
    || $self->ut_textn('comment')
    || $self->ut_foreign_key('svcnum', 'cust_svc', 'svcnum')
    || $self->ut_number('priority')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item clone NEW_SVCNUM

Clones this rule into an identical rule for the specified new service.

If there is an error, returns the error, otherwise returns false.

=cut

#should return the newly inserted rule instead? used in misc/clone-cgp_rule.html

#i should probably be transactionalized so i'm all-or-nothing
sub clone {
  my( $self, $svcnum ) = @_;

  my $new = $self->new( { $self->hash } );
  $new->rulenum('');
  $new->svcnum( $svcnum );
  my $error = $new->insert;
  return $error if $error;

  my @dup = $self->cgp_rule_condition;
  push @dup, $self->cgp_rule_action;

  foreach my $dup (@dup) {
    my $new_dup = $dup->new( { $dup->hash } );
    my $pk = $new_dup->primary_key;
    $new_dup->$pk('');
    $new_dup->rulenum( $new->rulenum );

    $error = $new_dup->insert;
    return $error if $error;

  }

  $error = $new->svc_export;
  return $error if $error;

  '';

}

=item cust_svc

=item cgp_rule_condition

Returns the conditions associated with this rule, as FS::cgp_rule_condition
objects.

=item arrayref

Returns an arraref representing this rule, suitable for Communigate Pro API
commands:

The first element specifies the rule priority.

The second element specifies the rule name.

The third element specifies the rule conditions.

The fourth element specifies the rule actions.

The fifth element specifies the rule comment.

=cut

sub arrayref {
  my $self = shift;
  [ $self->priority,
    $self->name,
    [ map $_->arrayref, $self->cgp_rule_condition ],
    [ map $_->arrayref, $self->cgp_rule_action ],
    $self->comment,
  ],
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

