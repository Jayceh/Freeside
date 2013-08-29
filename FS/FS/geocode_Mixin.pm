package FS::geocode_Mixin;

use strict;
use vars qw( $DEBUG $me );
use Carp;
use Locale::Country;
use Geo::Coder::Googlev3; #compile time for now, until others are supported
use FS::Record qw( qsearchs qsearch );
use FS::Conf;
use FS::cust_pkg;
use FS::cust_location;
use FS::cust_tax_location;
use FS::part_pkg;

$DEBUG = 0;
$me = '[FS::geocode_Mixin]';

=head1 NAME

FS::geocode_Mixin - Mixin class for records that contain address and other
location fields.

=head1 SYNOPSIS

  package FS::some_table;
  use base ( FS::geocode_Mixin FS::Record );

=head1 DESCRIPTION

FS::geocode_Mixin - This is a mixin class for records that contain address
and other location fields.

=head1 METHODS

=over 4

=cut

=item location_hash

Returns a list of key/value pairs, with the following keys: address1, address2,
city, county, state, zip, country, geocode, location_type, location_number,
location_kind.  The shipping address is used if present.

=cut

#geocode dependent on tax-ship_address config

sub location_hash {
  my $self = shift;
  my $prefix = $self->has_ship_address ? 'ship_' : '';

  map { my $method = ($_ eq 'geocode') ? $_ : $prefix.$_;
        $_ => $self->get($method);
      }
      qw( address1 address2 city county state zip country geocode 
	location_type location_number location_kind );
}

=item location_label [ OPTION => VALUE ... ]

Returns the label of the service location (see analog in L<FS::cust_location>) for this customer.

Options are

=over 4

=item join_string

used to separate the address elements (defaults to ', ')

=item escape_function

a callback used for escaping the text of the address elements

=back

=cut

sub location_label {
  my $self = shift;
  my %opt = @_;

  my $separator = $opt{join_string} || ', ';
  my $escape = $opt{escape_function} || sub{ shift };
  my $ds = $opt{double_space} || '  ';
  my $line = '';
  my $cydefault = 
    $opt{'countrydefault'} || FS::Conf->new->config('countrydefault') || 'US';
  my $prefix = $self->has_ship_address ? 'ship_' : '';

  my $notfirst = 0;
  foreach (qw ( address1 address2 ) ) {
    my $method = "$prefix$_";
    $line .= ($notfirst ? $separator : ''). &$escape($self->$method)
      if $self->$method;
    $notfirst++;
  }

  my $lt = $self->get($prefix.'location_type');
  if ( $lt ) {
    my %location_type;
    if ( 1 ) { #ikano, switch on via config
      { no warnings 'void';
        eval { 'use FS::part_export::ikano;' };
        die $@ if $@;
      }
      %location_type = FS::part_export::ikano->location_types;
    } else {
      %location_type = (); #?
    }

    $line .= ' '.&$escape( $location_type{$lt} || $lt );
  }

  $line .= ' '. &$escape($self->get($prefix.'location_number'))
    if $self->get($prefix.'location_number');

  $notfirst = 0;
  foreach (qw ( city county state zip ) ) {
    my $method = "$prefix$_";
    if ( $self->$method ) {
      $line .= ' (' if $method eq 'county';
      $line .= ($notfirst ? ' ' : $separator). &$escape($self->$method);
      $line .= ' )' if $method eq 'county';
      $notfirst++;
    }
  }
  $line .= $separator. &$escape(code2country($self->country))
    if $self->country ne $cydefault;

  $line;
}

=item set_coord [ PREFIX ]

Look up the coordinates of the location using (currently) the Google Maps
API and set the 'latitude' and 'longitude' fields accordingly.

PREFIX, if specified, will be prepended to all location field names,
including latitude and longitude.

=cut

sub set_coord {
  my $self = shift;
  my $pre = scalar(@_) ? shift : '';

  #my $module = FS::Conf->new->config('geocode_module') || 'Geo::Coder::Googlev3';

  my $geocoder = Geo::Coder::Googlev3->new;

  my $location = eval {
    $geocoder->geocode( location =>
      $self->get($pre.'address1'). ','.
      ( $self->get($pre.'address2') ? $self->get($pre.'address2').',' : '' ).
      $self->get($pre.'city'). ','.
      $self->get($pre.'state'). ','.
      code2country($self->get($pre.'country'))
    );
  };
  if ( $@ ) {
    warn "geocoding error: $@\n";
    return;
  }

  my $geo_loc = $location->{'geometry'}{'location'} or return;
  if ( $geo_loc->{'lat'} && $geo_loc->{'lng'} ) {
    $self->set($pre.'latitude',  $geo_loc->{'lat'} );
    $self->set($pre.'longitude', $geo_loc->{'lng'} );
    $self->set($pre.'coord_auto', 'Y');
  }

}

=item geocode DATA_VENDOR

Returns a value for the customer location as encoded by DATA_VENDOR.
Currently this only makes sense for "CCH" as DATA_VENDOR.

=cut

sub geocode {
  my ($self, $data_vendor) = (shift, shift);  #always cch for now

  my $geocode = $self->get('geocode');  #XXX only one data_vendor for geocode
  return $geocode if $geocode;

  if ( $self->isa('FS::cust_main') ) {
    warn "WARNING: FS::cust_main->geocode deprecated";

    # do the best we can
    my $m = FS::Conf->new->exists('tax-ship_address') ? 'ship_location'
                                                      : 'bill_location';
    my $location = $self->$m or return '';
    return $location->geocode($data_vendor);
  }

  my($zip,$plus4) = split /-/, $self->get('zip')
    if $self->country eq 'US';

  $zip ||= '';
  $plus4 ||= '';
  #CCH specific location stuff
  my $extra_sql = $plus4 ? "AND plus4lo <= '$plus4' AND plus4hi >= '$plus4'"
                         : '';

  my @cust_tax_location =
    qsearch( {
               'table'     => 'cust_tax_location', 
               'hashref'   => { 'zip' => $zip, 'data_vendor' => $data_vendor },
               'extra_sql' => $extra_sql,
               'order_by'  => 'ORDER BY plus4hi',#overlapping with distinct ends
             }
           );
  $geocode = $cust_tax_location[0]->geocode
    if scalar(@cust_tax_location);

  warn "WARNING: customer ". $self->custnum.
       ": multiple locations for zip ". $self->get("zip").
       "; using arbitrary geocode $geocode\n"
    if scalar(@cust_tax_location) > 1;

  $geocode;
}

=item process_district_update CLASS ID

Queueable function to update the tax district code using the selected method 
(config 'tax_district_method').  CLASS is either 'FS::cust_main' or 
'FS::cust_location'; ID is the key in one of those tables.

=cut

sub process_district_update {
  my $class = shift;
  my $id = shift;

  eval "use FS::Misc::Geo qw(get_district); use FS::Conf; use $class;";
  die $@ if $@;
  die "$class has no location data" if !$class->can('location_hash');

  my $conf = FS::Conf->new;
  my $method = $conf->config('tax_district_method')
    or return; #nothing to do if null
  my $self = $class->by_key($id) or die "object $id not found";

  # dies on error, fine
  my $tax_info = get_district({ $self->location_hash }, $method);
  
  if ( $tax_info ) {
    $self->set('district', $tax_info->{'district'} );
    my $error = $self->replace;
    die $error if $error;

    my %hash = map { $_ => $tax_info->{$_} } 
      qw( district city county state country );
    my $old = qsearchs('cust_main_county', \%hash);
    if ( $old ) {
      my $new = new FS::cust_main_county { $old->hash, %$tax_info };
      warn "updating tax rate for district ".$tax_info->{'district'} if $DEBUG;
      $error = $new->replace($old);
    }
    else {
      my $new = new FS::cust_main_county $tax_info;
      warn "creating tax rate for district ".$tax_info->{'district'} if $DEBUG;
      $error = $new->insert;
    }
    die $error if $error;

  }
  return;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

