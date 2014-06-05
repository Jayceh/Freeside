package FS::ClientAPI::PrepaidPhone;

use strict;
use vars qw($DEBUG $me);
use FS::Record qw(qsearchs);
use FS::Conf;
use FS::rate;
use FS::svc_phone;

$DEBUG = 0;
$me = '[FS::ClientAPI::PrepaidPhone]';

#TODO:
# - shared-secret auth? (set a conf value)

=item call_time HASHREF

HASHREF contains the following parameters:

=over 4

=item src

Source number (with countrycode)

=item dst

Destination number (with countrycode)

=back

Always returns a hashref.  If there is an error, the hashref contains a single
"error" key with the error message as a value.  Otherwise, returns a hashref
with the following keys:

=over 4

=item custnum

Empty if no customer is found associated with the number, customer number
otherwise.

=item seconds

Number of seconds remaining for a call to destination number

=back

=cut

sub call_time {
  my $packet = shift;

  my $src = $packet->{'src'};
  my $dst = $packet->{'dst'};

  my $chargeto;
  my $rateby;
  #my $conf = new FS::Conf;
  #if ( #XXX toll-free?  collect?
  #  $phonenum = $dst;
  #} else { #use the src to find the customer
    $chargeto = $src;
    $rateby = $dst;
  #}

  my( $countrycode, $phonenum );
  if ( $chargeto #an interesting regex to parse out 1&2 digit countrycodes
         =~ /^(2[078]|3[0-469]|4[013-9]|5[1-8]|6[0-6]|7|8[1-469]|9[0-58])(\d*)$/
       || $chargeto =~ /^(\d{3})(\d*)$/
     )
  {
    $countrycode = $1;
    $phonenum = $2;
  } else { 
    return { 'error' => "unparsable billing number: $chargeto" };
  }


  my $svc_phone = qsearchs('svc_phone', { 'countrycode' => $countrycode,
                                          'phonenum'    => $phonenum,
                                        }
                          );

  unless ( $svc_phone ) {
    return { 'error' => "can't find customer for +$countrycode $phonenum" };
#    return { 'custnum' => '',
#             'seconds' => 0,
#             #'balance' => 0,
#           };
  };

  my $cust_pkg = $svc_phone->cust_svc->cust_pkg;
  my $cust_main = $cust_pkg->cust_main;

  my $part_pkg = $cust_pkg->part_pkg;
  my @part_pkg = ( $part_pkg, map $_->dst_pkg, $part_pkg->bill_part_pkg_link );
  #XXX uuh, behavior indeterminate if you have more than one voip_cdr+prefix
  #add-on, i guess.
  warn "$me ". scalar(@part_pkg). ': '.
       join('/', map { $_->plan. $_->option('rating_method') } @part_pkg )
    if $DEBUG;
  @part_pkg =
    grep { $_->plan eq 'voip_cdr' && $_->option('rating_method') eq 'prefix' }
         @part_pkg;

  my %return = (
    'custnum' => $cust_pkg->custnum,
    #'balance' => $cust_pkg->cust_main->balance,
  );

  warn "$me: ". scalar(@part_pkg). ': '.
       join('/', map { $_->plan. $_->option('rating_method') } @part_pkg )
    if $DEBUG;
  return \%return unless @part_pkg;

  warn "$me searching for rate ". $part_pkg[0]->option('ratenum')
    if $DEBUG;

  my $rate = qsearchs('rate', { 'ratenum'=>$part_pkg[0]->option('ratenum') } );

  unless ( $rate ) {
    my $error = 'ratenum '. $part_pkg[0]->option('ratenum'). ' not found';
    warn "$me $error"
      if $DEBUG;
    return { 'error'=>$error };
  }

  warn "$me found rate ". $rate->ratenum
    if $DEBUG;

  #rate the call and arrive at a max # of seconds for the customer's balance

  my( $rate_countrycode, $rate_phonenum );
  if ( $rateby #this is an interesting regex to parse out 1&2 digit countrycodes
         =~ /^(2[078]|3[0-469]|4[013-9]|5[1-8]|6[0-6]|7|8[1-469]|9[0-58])(\d*)$/
       || $rateby =~ /^(\d{3})(\d*)$/
     )
  {
    $rate_countrycode = $1;
    $rate_phonenum = $2;
  } else { 
    return { 'error' => "unparsable rating number: $rateby" };
  }

  my $rate_detail = $rate->dest_detail({ 'countrycode' => $rate_countrycode,
                                         'phonenum'    => $rate_phonenum,
                                       });
  unless ( $rate_detail ) {
    return { 'error'=>"can't find rate for +$rate_countrycode $rate_phonenum"};
  }

  unless ( $rate_detail->min_charge > 0 ) {
    #XXX no charge??  return lots of seconds, a default, 0 or what?
    #return { 'error' => '0 rate for +$rate_countrycode $rate_phonenum; prepaid service not available" };
    #customer wants no default for now# $return{'seconds'} = 1800; #half hour?!
    return \%return;
  }

  my $balance = FS::ClientAPI::PrepaidPhone->prepaid_phone_balance( $cust_pkg );

  #XXX granularity?  included minutes?  another day...
  if ( $balance >= 0 ) {
    return { 'error'=>'No balance' };
  } else {
    $return{'seconds'} = int(60 * abs($balance) / $rate_detail->min_charge);
  }

  warn "$me returning seconds: ". $return{'seconds'};

  return \%return;
 
}

=item call_time_nanpa 

Like I<call_time>, except countrycode 1 is not required, and all other
countrycodes must be prefixed with 011.

=cut

# - everything is assumed to be countrycode 1 unless it starts with 011(ccode)
sub call_time_nanpa {
  my $packet = shift;

  foreach (qw( src dst )) {
    if ( $packet->{$_} =~ /^011(\d+)/ ) {
      $packet->{$_} = $1;
    } elsif ( $packet->{$_} !~ /^1/ ) {
      $packet->{$_} = '1'.$packet->{$_};
    }
  }

  call_time($packet);

}

=item phonenum_balance HASHREF

HASHREF contains the following parameters:

=over 4

=item countrycode

Optional countrycode.  Defaults to 1.

=item phonenum

Phone number.

=back

Always returns a hashref.  If there is an error, the hashref contains a single
"error" key with the error message as a value.  Otherwise, returns a hashref
with the following keys:

=over 4

=item custnum

Empty if no customer is found associated with the number, customer number
otherwise.

=item balance

Customer balance.

=back

=cut

sub phonenum_balance {
  my $packet = shift;

  warn "$me phonenum_balance called with countrycode ".$packet->{'countrycode'}.
       " and phonenum ". $packet->{'phonenum'}. "\n"
    if $DEBUG;

  my $svc_phone = qsearchs('svc_phone', {
    'countrycode' => ( $packet->{'countrycode'} || 1 ),
    'phonenum'    => $packet->{'phonenum'},
  });

  unless ( $svc_phone ) {
    warn "$me no phone number found\n" if $DEBUG;
    return { 'custnum' => '',
             'balance' => 0,
           };
  };

  my $cust_pkg = $svc_phone->cust_svc->cust_pkg;

  my $balance = FS::ClientAPI::PrepaidPhone->prepaid_phone_balance( $cust_pkg );

  warn "$me returning $balance balance for pkgnum ".  $cust_pkg->pkgnum.
                                        ", custnum ". $cust_pkg->custnum
    if $DEBUG;

  return {
    'custnum' => $cust_pkg->custnum,
    'balance' => $balance,
  };

}

sub prepaid_phone_balance {
  my $class = shift; # i guess
  my ($cust_pkg) = @_;

  my $conf = new FS::Conf;

  my $pkg_balances = $conf->config_bool('pkg-balances');
  
  my $balance = $pkg_balances ? $cust_pkg->balance
                              : $cust_pkg->cust_main->balance;

  if ( $conf->config_bool('cdr-prerate') ) {
    my @cust_pkg = $pkg_balances ? ( $cust_pkg )
                                 : ( $cust_pkg->cust_main->ncancelled_pkgs );
    foreach my $cust_pkg ( @cust_pkg ) {

      #we only support prerated CDRs with "VOIP/telco CDR rating (standard)"
      # and "Phone numbers (svc_phone.phonenum)" CDR service matching for now
      my $part_pkg = $cust_pkg->part_pkg;
      next unless $part_pkg->plan eq 'voip_cdr'
               && ($part_pkg->option('cdr_svc_method') || 'svc_phone.phonenum')
                    eq 'svc_phone.phonenum'
               && ! $part_pkg->option('bill_inactive_svcs');
      #XXX skip when there's included minutes

      #select prerated cdrs & subtract them from balance

      # false laziness w/ part_pkg/voip_cdr.pm sorta

      my %options = (
          'disable_src'    => $part_pkg->option('disable_src'),
          'default_prefix' => $part_pkg->option('default_prefix'),
          'cdrtypenum'     => $part_pkg->option('use_cdrtypenum'),
          'calltypenum'    => $part_pkg->option('use_calltypenum'),
          'status'         => 'rated',
          'by_svcnum'      => 1,
      );  # $last_bill, $$sdate )

      my @cust_svc = grep { $_->part_svc->svcdb eq 'svc_phone' }
                       $cust_pkg->cust_svc;
      foreach my $cust_svc ( @cust_svc ) {
        
        my $svc_x = $cust_svc->svc_x;
        my $sum_cdr = $svc_x->sum_cdrs(%options);
        $balance += $sum_cdr->rated_price;

      }

    }
  }

  $balance;

}

1;
