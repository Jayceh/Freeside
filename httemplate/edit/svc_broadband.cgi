<& elements/svc_Common.html,
     'post_url'             => popurl(1). 'process/svc_broadband.cgi',
     'name'                 => 'broadband service',
     'table'                => 'svc_broadband',
     'fields'               => \@fields, 
     'svc_field_callback'   => $svc_field_callback,
     'svc_new_callback'     => $svc_edit_callback,
     'svc_edit_callback'    => $svc_edit_callback,
     'svc_error_callback'   => $svc_edit_callback,
     'dummy'                => $cgi->query_string,
     'onsubmit'             => 'validate_coords',
     'html_foot'            => $js,
&>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

# If it's stupid but it works, it's still stupid.
#  -Kristian

my $conf = new FS::Conf;

my $js = <<END
    <script type="text/javascript">
        function validate_coords(f){
END
;
if ( $conf->exists('svc_broadband-require-nw-coordinates') ) {
$js .= <<END
            var lon = f.longitude;
            var lat = f.latitude;
            if ( lon == null || lat == null || 
                lon.value.length == 0 || lat.value.length == 0 ) return true;

            return (ut_coord(lat.value,1,90) && ut_coord(lon.value,-180,-1));
        } // validate_coords

        /* this is a JS re-implementation of FS::Record::ut_coord */
        function ut_coord(coord,lower,upper) {
            var neg = /^-/.test(coord);
            coord = coord.replace(/^-/,'');

            var d = 0;
            var m = 0;
            var s = 0;
            
            var t1 = /^(\\s*\\d{1,3}(?:\\.\\d+)?)\\s*\$/.exec(coord);
            var t2 = /^(\\s*\\d{1,3})\\s+(\\d{1,2}(?:\\.\\d+))\\s*\$/.exec(coord);
            var t3 = /^(\\s*\\d{1,3})\\s+(\\d{1,2})\\s+(\\d{1,3})\\s*\$/.exec(coord);
            if ( t1 != null ) {
                d = t1[1];
            } else if ( t2 != null ) {
                d = t2[1];
                m = t2[2];
            } else if ( t3 != null ) {
                d = t3[1];
                m = t3[2];
                s = t3[3];
            } else {
                alert('Invalid co-ordinates! Latitude must be positive and longitude must be negative.');
                return false;
            } 
            
            var ts = /^\\d{3}\$/.exec(s);
            if ( ts != null || s > 59 ) {
               s /= 1000; 
            } else {
                s /= 60;
            }
            s /= 60;

            m /= 60;
            if ( m > 59 ) {
                alert('Invalid coordinate with minutes > 59');
                return false;
            }

            var tmp = parseInt(d)+parseInt(m)+parseInt(s);
            tmp = tmp.toFixed(8);
            coord = (neg ? -1 : 1) * tmp;

            if(coord < lower) {
                alert('Error: invalid coordinate < '+lower);
                return false;
            }
            if(coord > upper) {
                alert('Error: invalid coordinate > '+upper);
                return false;
            }

            return true;
END
;
}
$js .= <<END
        }
    </script>
END
;

my @fields = (
  qw( description speed_down speed_up ),
  { field=>'sectornum', type=>'select-tower_sector', },
  { field=>'routernum', type=>'select-router_block_ip' },
  { field=>'mac_addr' , type=>'input-mac_addr' },
  qw(
      latitude longitude altitude
      radio_serialnum radio_location poe_location rssi suid
    ),
  { field=>'shared_svcnum', type=>'search-svc_broadband', },
  qw( vlan_profile performance_profile authkey plan_id ),
);

if ( $conf->exists('svc_broadband-radius') ) {
  push @fields,
  { field     => 'usergroup',
    type      => 'select-radius_group',
    multiple  => 1,
  }
}

my $part_svc;

my $svc_edit_callback = sub {
  my ($cgi, $svc_x, $part_svc_x, $cust_pkg, $fields, $opt) = @_;

  $part_svc = $part_svc_x; #for field_callback to use

  my ($nas_export) = $part_svc->part_export('broadband_nas');
  #can we assume there's only one of these per part_svc?
  if ( $nas_export ) {
    my $nas;
    if ( $svc_x->svcnum ) {
      $nas = qsearchs('nas', { 'svcnum' => $svc_x->svcnum });
    }
    $nas ||= $nas_export->default_nas;
    $svc_x->set($_, $nas->$_) foreach fields('nas');

    # duplicates the fields in httemplate/edit/nas.html (mostly)
    push @$fields,
      { type  => 'tablebreak-tr-title', 
        #value => 'Attached NAS',
        value => $nas_export->exportname,
        colspan => 2,
      },
      { field=>'nasnum', type=>'hidden', },
      { field=>'shortname', size=>16, maxlength=>32 },
      { field=>'secret', size=>40, maxlength=>60, required=>1 },
      { field=>'type', type=>'select',
        options=>[qw( cisco computone livingston max40xx multitech netserver
        pathras patton portslave tc usrhiper other )],
      },
      { field=>'ports', size=>5 },
      { field=>'server', size=>40, maxlength=>64 },
      { field=>'community', size=>40, maxlength=>50 },
    ;

    $opt->{'labels'}{'shortname'} = 'Short name';
    $opt->{'labels'}{'secret'}    = 'Shared secret';
    $opt->{'labels'}{'type'}      = 'Type';
    $opt->{'labels'}{'ports'}     = 'Ports';
    $opt->{'labels'}{'server'}    = 'Server';
    $opt->{'labels'}{'community'} = 'Community';
  }
};

my $svc_field_callback = sub {
  my ($cgi, $object, $fieldref) = @_;

  my $columndef = $part_svc->part_svc_column($fieldref->{'field'});
  if ($fieldref->{field} eq 'usergroup' && $columndef->columnflag eq 'F') {
    
    $fieldref->{'formatted_value'} = 
      [ $object->radius_groups('long_description') ];
  }

}; 

</%init>
