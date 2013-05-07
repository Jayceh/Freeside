package FS::part_pkg::voip_inbound;
use base qw( FS::part_pkg::recur_Common );

use strict;
use vars qw($DEBUG %info);
use Date::Format;
use Tie::IxHash;
use Text::CSV_XS;
use FS::Conf;
use FS::Record qw(qsearchs qsearch);
use FS::cdr;
use FS::rate_detail;
use FS::detail_format;

$DEBUG = 0;

tie my %temporalities, 'Tie::IxHash',
  'upcoming'  => "Upcoming (future)",
  'preceding' => "Preceding (past)",
;

tie my %granularity, 'Tie::IxHash', FS::rate_detail::granularities();

%info = (
  'name' => 'VoIP flat rate pricing of CDRs for inbound calls',
  'shortname' => 'VoIP/telco CDR rating (inbound)',
  'inherit_fields' => [ 'prorate_Mixin', 'global_Mixin' ],
  'fields' => {
    #false laziness w/flat.pm
    'recur_temporality' => { 'name' => 'Charge recurring fee for period',
                             'type' => 'select',
                             'select_options' => \%temporalities,
                           },
    'cutoff_day'    => { 'name' => 'Billing Day (1 - 28) for prorating or '.
                                   'subscription',
                         'default' => '1',
                       },

    'recur_method'  => { 'name' => 'Recurring fee method',
                         'type' => 'select',
                         'select_options' => \%FS::part_pkg::recur_Common::recur_method,
                       },

    'min_charge' => { 'name' => 'Charge per minute',
                    },
    
    'min_included' => { 'name' => 'Minutes included',
                    },

    'sec_granularity' => { 'name' => 'Granularity',
                           'type' => 'select',
                           'select_options' => \%granularity,
                         },

    'default_prefix' => { 'name'    => 'Default prefix optionally prepended to customer DID numbers when searching for CDR records',
                          'default' => '+1',
                        },

    'use_amaflags' => { 'name' => 'Only charge for CDRs where the amaflags field is set to "2" ("BILL"/"BILLING").',
                        'type' => 'checkbox',
                      },

    'use_carrierid' => { 'name' => 'Only charge for CDRs where the Carrier ID is set to any of these (comma-separated) values: ',
                         },

    'use_cdrtypenum' => { 'name' => 'Only charge for CDRs where the CDR Type is set to this cdrtypenum: ',
                         },
    
    'ignore_cdrtypenum' => { 'name' => 'Do not charge for CDRs where the CDR Type is set to this cdrtypenum: ',
                         },

    'use_calltypenum' => { 'name' => 'Only charge for CDRs where the CDR Call Type is set to this cdrtypenum: ',
                         },
    
    'ignore_calltypenum' => { 'name' => 'Do not charge for CDRs where the CDR Call Type is set to this cdrtypenum: ',
                         },
    
    'ignore_disposition' => { 'name' => 'Do not charge for CDRs where the Disposition is set to any of these (comma-separated) values: ',
                         },
    
    'disposition_in' => { 'name' => 'Only charge for CDRs where the Disposition is set to any of these (comma-separated) values: ',
                         },

    'skip_dcontext' => { 'name' => 'Do not charge for CDRs where the dcontext is set to any of these (comma-separated) values:',
                       },

    'skip_dstchannel_prefix' => { 'name' => 'Do not charge for CDRs where the dstchannel starts with:',
                                },

    'skip_dst_length_less' => { 'name' => 'Do not charge for CDRs where the destination is less than this many digits:',
                              },

    'skip_lastapp' => { 'name' => 'Do not charge for CDRs where the lastapp matches this value',
                      },

    'use_duration'   => { 'name' => 'Calculate usage based on the duration field instead of the billsec field',
                          'type' => 'checkbox',
                        },

    #false laziness w/cdr_termination.pm
    'output_format' => { 'name' => 'CDR invoice display format',
                         'type' => 'select',
                         'select_options' => { FS::cdr::invoice_formats() },
                         'default'        => 'default', #XXX test
                       },

    'usage_section' => { 'name' => 'Section in which to place usage charges (whether separated or not)',
                       },

    'summarize_usage' => { 'name' => 'Include usage summary with recurring charges when usage is in separate section',
                          'type' => 'checkbox',
                        },

    'usage_mandate' => { 'name' => 'Always put usage details in separate section',
                          'type' => 'checkbox',
                       },
    #eofalse

    'bill_every_call' => { 'name' => 'Generate an invoice immediately for every call.  Useful for prepaid.',
                           'type' => 'checkbox',
                         },

    #XXX also have option for an external db
#    'cdr_location' => { 'name' => 'CDR database location'
#                        'type' => 'select',
#                        'select_options' => \%cdr_location,
#                        'select_callback' => {
#                          'external' => {
#                            'enable' => [ 'datasrc', 'username', 'password' ],
#                          },
#                          'internal' => {
#                            'disable' => [ 'datasrc', 'username', 'password' ],
#                          }
#                        },
#                      },
#    'datasrc' => { 'name' => 'DBI data source for external CDR table',
#                   'disabled' => 'Y',
#                 },
#    'username' => { 'name' => 'External database username',
#                    'disabled' => 'Y',
#                  },
#    'password' => { 'name' => 'External database password',
#                    'disabled' => 'Y',
#                  },

  },
  'fieldorder' => [qw(
                       recur_temporality
                       recur_method cutoff_day ),
                       FS::part_pkg::prorate_Mixin::fieldorder,
                   qw( min_charge min_included sec_granularity
                       default_prefix
                       use_amaflags
                       use_carrierid
                       use_cdrtypenum ignore_cdrtypenum
                       use_calltypenum ignore_calltypenum
                       ignore_disposition disposition_in
                       skip_dcontext skip_dstchannel_prefix
                       skip_dst_length_less skip_lastapp
                       use_duration
                       output_format usage_mandate summarize_usage usage_section
                       bill_every_call
                     )
                  ],
  'weight' => 42,
);

sub price_info {
    my $self = shift;
    my $str = $self->SUPER::price_info;
    $str .= " plus usage" if $str;
    $str;
}

sub calc_recur {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  my $charges = 0;

  $charges += $self->calc_usage(@_);
  $charges += $self->calc_recur_Common(@_);

  $charges;

}

# use the default
#sub calc_cancel {
#  my $self = shift;
#  my($cust_pkg, $sdate, $details, $param ) = @_;
#
#  $self->calc_usage(@_);
#}

#false laziness w/voip_sqlradacct calc_recur resolve it if that one ever gets used again

sub calc_usage {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  #my $last_bill = $cust_pkg->last_bill;
  my $last_bill = $cust_pkg->get('last_bill'); #->last_bill falls back to setup

  return 0
    if $self->recur_temporality eq 'preceding'
    && ( $last_bill eq '' || $last_bill == 0 );

  my $spool_cdr = $cust_pkg->cust_main->spool_cdr;


  my $charges = 0;

#  my $downstream_cdr = '';

  my $included_min  = $self->option('min_included', 1) || 0;
  my $use_duration  = $self->option('use_duration');
  my $output_format = $self->option('output_format', 1) || 'default';

  my $formatter = 
    FS::detail_format->new($output_format, buffer => $details, inbound => 1);

  my $granularity   = length($self->option('sec_granularity'))
                        ? $self->option('sec_granularity')
                        : 60;

  #for check_chargable, so we don't keep looking up options inside the loop
  my %opt_cache = ();

  my $csv = new Text::CSV_XS;

  foreach my $cust_svc (
    grep { $_->part_svc->svcdb eq 'svc_phone' } $cust_pkg->cust_svc
  ) {
    my $svc_phone = $cust_svc->svc_x;

    my $cdr_search = $svc_phone->psearch_cdrs(
      'inbound'        => 1,
      'default_prefix' => $self->option('default_prefix'),
      'status'         => '', # unprocessed only
      'for_update'     => 1,
    );
    $cdr_search->limit(1000);
    $cdr_search->increment(0);
    while ( my $cdr = $cdr_search->fetch ) {

      my $reason = $self->check_chargable( $cdr,
                                           'option_cache' => \%opt_cache,
                                         );
      if ( $reason ) {
        warn "not charging for CDR ($reason)\n" if $DEBUG;
        $cdr_search->adjust(1);
        next;
      }

      if ( $DEBUG > 1 ) {
        warn "rating inbound CDR $cdr\n".
             join('', map { "  $_ => ". $cdr->{$_}. "\n" } keys %$cdr );
      }

      my $seconds = $use_duration ? $cdr->duration : $cdr->billsec;

      $seconds += $granularity - ( $seconds % $granularity )
        if $seconds      # don't granular-ize 0 billsec calls (bills them)
        && $granularity; # 0 is per call
      my $minutes = sprintf("%.1f",$seconds / 60); 
      $minutes =~ s/\.0$// if $granularity == 60; # count whole minutes, convert to integer
      $minutes = 1 unless $granularity; # per call

      my $charge_min = $minutes;
      my $charge = 0;

      $included_min -= $minutes;
      if ( $included_min > 0 ) {
        $charge_min = 0;
      }
      else {
         $charge_min = 0 - $included_min;
         $included_min = 0;
      }
      
      $charge = sprintf('%.4f', ( $self->option('min_charge') * $charge_min )
                                + 0.00000001 ); #so 1.00005 rounds to 1.0001

      if ( $charge > 0 ) {
        $charges += $charge;
        my @call_details = (
          $cdr->downstream_csv( 'format'      => $output_format,
                                'charge'      => $charge,
                                'seconds'     => ($use_duration
                                                   ? $cdr->duration
                                                   : $cdr->billsec
                                                 ),
                                'granularity' => $granularity,
                              )
        );
#        push @$details,
#          { format      => 'C',
#            detail      => $call_details[0],
#            amount      => $charge,
#            classnum    => $cdr->calltypenum, #classnum
#            #phonenum    => $self->phonenum,
#            accountcode => $cdr->accountcode,
#            startdate   => $cdr->startdate,
#            duration    => $seconds,
#            # regionname?? => '', #regionname, not set for inbound calls
#          };
      }

      # eventually use FS::cdr::rate for this
      my $error = $cdr->set_status_and_rated_price(
        'done',
        $charge,
        $cust_svc->svcnum,
        'rated_seconds'     => $use_duration ? $cdr->duration : $cdr->billsec,
        'rated_granularity' => $granularity, 
        'rated_classnum'    => $cdr->calltypenum,
        'inbound'        => 1,
      );
      die $error if $error;
      $formatter->append($cdr);

      $cdr_search->adjust(1) if $cdr->freesidestatus eq '';

    } #$cdr
  } # $cust_svc
#  unshift @$details, { format => 'C',
#                       detail => FS::cdr::invoice_header($output_format),
#                     }
#    if @$details;
  
  $formatter->finish;
  unshift @$details, $formatter->header if @$details;

  $charges;
}

#returns a reason why not to rate this CDR, or false if the CDR is chargeable
# lots of false laziness w/voip_cdr...
sub check_chargable {
  my( $self, $cdr, %flags ) = @_;

  return 'amaflags != 2'
    if $self->option_cacheable('use_amaflags') && $cdr->amaflags != 2;

  return "disposition NOT IN ( ". $self->option_cacheable('disposition_in')." )"
    if $self->option_cacheable('disposition_in') =~ /\S/
    && !grep { $cdr->disposition eq $_ } split(/\s*,\s*/, $self->option_cacheable('disposition_in'));
  
  return "disposition IN ( ". $self->option_cacheable('ignore_disposition')." )"
    if $self->option_cacheable('ignore_disposition') =~ /\S/
    && grep { $cdr->disposition eq $_ } split(/\s*,\s*/, $self->option_cacheable('ignore_disposition'));

  return "carrierid NOT IN ( ". $self->option_cacheable('use_carrierid'). " )"
    if $self->option_cacheable('use_carrierid') =~ /\S/
    && !grep { $cdr->carrierid eq $_ } split(/\s*,\s*/, $self->option_cacheable('use_carrierid')); #eq otherwise 0 matches ''

  # unlike everything else, use_cdrtypenum is applied in FS::svc_x::get_cdrs.
  return "cdrtypenum != ". $self->option_cacheable('use_cdrtypenum')
    if length($self->option_cacheable('use_cdrtypenum'))
    && $cdr->cdrtypenum ne $self->option_cacheable('use_cdrtypenum'); #ne otherwise 0 matches ''
  
  return "cdrtypenum == ". $self->option_cacheable('ignore_cdrtypenum')
    if length($self->option_cacheable('ignore_cdrtypenum'))
    && $cdr->cdrtypenum eq $self->option_cacheable('ignore_cdrtypenum'); #eq otherwise 0 matches ''

  # unlike everything else, use_calltypenum is applied in FS::svc_x::get_cdrs.
  return "calltypenum != ". $self->option_cacheable('use_calltypenum')
    if length($self->option_cacheable('use_calltypenum'))
    && $cdr->calltypenum ne $self->option_cacheable('use_calltypenum'); #ne otherwise 0 matches ''
  
  return "calltypenum == ". $self->option_cacheable('ignore_calltypenum')
    if length($self->option_cacheable('ignore_calltypenum'))
    && $cdr->calltypenum eq $self->option_cacheable('ignore_calltypenum'); #eq otherwise 0 matches ''

  return "dcontext IN ( ". $self->option_cacheable('skip_dcontext'). " )"
    if $self->option_cacheable('skip_dcontext') =~ /\S/
    && grep { $cdr->dcontext eq $_ } split(/\s*,\s*/, $self->option_cacheable('skip_dcontext'));

  my $len_prefix = length($self->option_cacheable('skip_dstchannel_prefix'));
  return "dstchannel starts with ". $self->option_cacheable('skip_dstchannel_prefix')
    if $len_prefix
    && substr($cdr->dstchannel,0,$len_prefix) eq $self->option_cacheable('skip_dstchannel_prefix');

  my $dst_length = $self->option_cacheable('skip_dst_length_less');
  return "destination less than $dst_length digits"
    if $dst_length && length($cdr->dst) < $dst_length;

  return "lastapp is ". $self->option_cacheable('skip_lastapp')
    if length($self->option_cacheable('skip_lastapp')) && $cdr->lastapp eq $self->option_cacheable('skip_lastapp');

  #all right then, rate it
  '';
}

sub is_free {
  0;
}

#  This equates svc_phone records; perhaps svc_phone should have a field
#  to indicate it represents a line
sub calc_units {    
  my($self, $cust_pkg ) = @_;
  my $count = 
      scalar(grep { $_->part_svc->svcdb eq 'svc_phone' } $cust_pkg->cust_svc);
  $count;
}

1;

