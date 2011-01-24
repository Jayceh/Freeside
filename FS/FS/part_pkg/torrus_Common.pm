package FS::part_pkg::torrus_Common;

use base qw( FS::part_pkg::prorate );
use List::Util qw(max);

our %info = ( 'disabled' => 1 ); #torrus_Common not a usable price plan directly

our $DEBUG = 1;

sub calc_recur {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  my $charges = 0;

  $charges += $self->calc_usage(@_);
  $charges += $self->calc_prorate(@_, 1);
  #$charges -= $self->calc_discount(@_);

  $charges;

}

#sub calc_cancel {  #somehow trigger an early report?

#have to look at getting the discounts to apply to the usage charges
sub can_discount { 0; }

sub calc_usage {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;


  my @sdate = localtime($$sdate);
  my $rep_date = ($sdate[5]+1900). '-'. ($sdate[4]+1). '-01';
  warn "searching for MonthlyUsage report for $rep_date\n" if $DEBUG;
  my $rep_sql = "
    SELECT id FROM reports WHERE rep_date = ?
                             AND reportname = 'MonthlyUsage' and iscomplete = 1
  ";
  my $rep_id = $self->scalar_sql($rep_sql, $rep_date) or return 0;
  warn "report id $rep_id found\n" if $DEBUG;

  #abort if ! iscomplete instead?

  my $conf = new FS::Conf;
  my $money_char = $conf->config('money_char') || '$';

  my $sql = "
    SELECT value FROM reportfields
      WHERE rep_id = $rep_id
        AND name = ?
        AND servciceid = ?
  ";
 
  my $total = 0;
  foreach my $svc_port (
    grep $_->table('svc_port'), map $_->svc_x, $cust_pkg->cust_svc
  ) {

    my $serviceid = $svc_port->serviceid;

    warn "searching for $serviceid usage\n" if $DEBUG;
    my $in  = $self->scalar_sql($sql, $self->_torrus_name, $serviceid.'_IN');
    my $out = $self->scalar_sql($sql, $self->_torrus_name, $serviceid.'_OUT');

    my $max = max($in,$out);
    warn "$serviceid usage is $max\n" if $DEBUG;

    my $inc = $self->option($self->_torrus_base);#aggregate instead of per-port?
    $max -= $inc;
    next if $max < 0;

    my $amount = sprintf('%.2f', $self->option($self->_torrus_rate) * $max );
    $total += $amount;

    #add usage details to invoice
    my $l = $self->_torrus_label;
    my $d = "Last month's usage for $serviceid: $max$l";
    $d .= " (". ($max+$inc). "$l - $inc$l included)" if $inc;
    $d .= ": $money_char$amount";

    push @$details, $d;

  }

  return sprintf('%.2f', $total );

}

1;