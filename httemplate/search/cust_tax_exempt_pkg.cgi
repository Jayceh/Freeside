<& elements/search.html,
                 'title'       => 'Tax exemptions',
                 'name'        => 'tax exemptions',
                 'query'       => $query,
                 'count_query' => $count_query,
                 'count_addl'  => [ $money_char. '%.2f total', ],
                 'header'      => [
                   '#',
                   'Month',
                   'Amount',
                   'Line item',
                   'Invoice',
                   'Date',
                   FS::UI::Web::cust_header(),
                 ],
                 'fields'      => [
                   'exemptpkgnum',
                   sub { $_[0]->month. '/'. $_[0]->year; },
                   sub { $money_char. $_[0]->amount; },

                   sub {
                     $_[0]->billpkgnum. ': '.
                     ( $_[0]->pkgnum > 0
                         ? $_[0]->get('pkg')
                         : $_[0]->get('itemdesc')
                     ).
                     ' ('.
                     ( $_[0]->setup > 0
                         ? $money_char. $_[0]->setup. ' setup'
                         : ''
                     ).
                     ( $_[0]->setup > 0 && $_[0]->recur > 0
                       ? ' / '
                       : ''
                     ).
                     ( $_[0]->recur > 0
                         ? $money_char. $_[0]->recur. ' recur'
                         : ''
                     ).
                     ')';
                   },

                   'invnum',
                   sub { time2str('%b %d %Y', shift->_date ) },

                   \&FS::UI::Web::cust_fields,
                 ],
                 'links'       => [
                   '',
                   '',
                   '',

                   '',
                   $ilink,
                   $ilink,

                   ( map { $_ ne 'Cust. Status' ? $clink : '' }
                         FS::UI::Web::cust_header()
                   ),
                 ],
                 'align' => 'rrrlrc'.FS::UI::Web::cust_aligns(), # 'rlrrrc',
                 'color' => [ 
                              '',
                              '',
                              '',
                              '',
                              '',
                              '',
                              FS::UI::Web::cust_colors(),
                            ],
                 'style' => [ 
                              '',
                              '',
                              '',
                              '',
                              '',
                              '',
                              FS::UI::Web::cust_styles(),
                            ],
&>
<%once>

my $join_cust = "
    JOIN cust_bill USING ( invnum )" .
    FS::UI::Web::join_cust_main('cust_bill', 'cust_pkg');

my $join_pkg = "
    LEFT JOIN cust_pkg USING ( pkgnum )
    LEFT JOIN part_pkg USING ( pkgpart )
";

my $join = "
    JOIN cust_bill_pkg USING ( billpkgnum )
    $join_pkg
    $join_cust
";

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View customer tax exemptions');

my @where = ( "exempt_monthly = 'Y'" );

my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);
if ( $beginning || $ending ) {
  push @where, "_date >= $beginning",
               "_date <= $ending";
               #"payby != 'COMP';
}

if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  push @where, "cust_main.agentnum = $1";
}

if ( $cgi->param('custnum') =~ /^(\d+)$/ ) {
  push @where,  "cust_main.custnum = $1";
}

if ( $cgi->param('country' ) ) {

  my $county  = dbh->quote( $cgi->param('county')  );
  my $state   = dbh->quote( $cgi->param('state')   );
  my $country = dbh->quote( $cgi->param('country') );
  push @where, "( county  = $county OR $county = '' )",
               "( state   = $state  OR $state = ''  )",
               "  country = $country";
  push @where, 'taxclass = '. dbh->quote( $cgi->param('taxclass') )
    if $cgi->param('taxclass');

}

if ( $cgi->param('taxnum') ) {

  my @taxnums = grep /^\d+$/, map { split(',', $_) } $cgi->param('taxnum');
  if ( $cgi->param('taxnum') =~ /^([\d,]+)$/) {
    push @where, "cust_tax_exempt_pkg.taxnum IN ($1)";
  }

}

if ( $cgi->param('classnum') =~ /^(\d+)$/ ) {
  push @where, "COALESCE(part_pkg.classnum,0) = $1";
}

my $where = scalar(@where) ? 'WHERE '.join(' AND ', @where) : '';

my $count_query = "SELECT COUNT(*), SUM(amount)".
                  "  FROM cust_tax_exempt_pkg $join $where";

my $query = {
  'table'     => 'cust_tax_exempt_pkg',
  'addl_from' => $join,
  'hashref'   => {},
  'select'    => join(', ',
                   'cust_tax_exempt_pkg.*',
                   'cust_bill_pkg.*',
                   'cust_bill.*',
                   'part_pkg.pkg',
                   'cust_main.custnum',
                   FS::UI::Web::cust_sql_fields(),
                 ),
  'extra_sql' => $where,
};

my $ilink = [ "${p}view/cust_bill.cgi?", 'invnum' ];
my $clink = [ "${p}view/cust_main.cgi?", 'custnum' ];

my $conf = new FS::Conf;
my $money_char = $conf->config('money_char') || '$';

</%init>
