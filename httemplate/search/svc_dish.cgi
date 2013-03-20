<& elements/svc_Common.html,
                 'title'       => 'Dish Network Search Results',
                 'name'        => 'services',
                 'query'       => $sql_query,
                 'count_query' => $count_query,
                 'redirect'    => $link,
                 'header'      => [ '#',
                                    'Service',
                                    'Account #',
                                    FS::UI::Web::cust_header(),
                                  ],
                 'fields'      => [ 'svcnum',
                                    'svc',
                                    'acctnum',
                                    \&FS::UI::Web::cust_fields,
                                  ],
                 'links'       => [ $link,
                                    $link,
                                    $link,
                                    ( map { $_ ne 'Cust. Status' ? $link_cust : '' }
                                          FS::UI::Web::cust_header()
                                    ),
                                  ],
                 'align' => 'rll'. FS::UI::Web::cust_aligns(),
                 'color' => [ 
                              '',
                              '',
                              '',
                              FS::UI::Web::cust_colors(),
                            ],
                 'style' => [ 
                              '',
                              '',
                              '',
                              FS::UI::Web::cust_styles(),
                            ],
             
&>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('List services');

#my $conf = new FS::Conf;

my $orderby = 'ORDER BY svcnum';
my @extra_sql = ();
if ( $cgi->param('magic') =~ /^(all|unlinked)$/ ) {

  push @extra_sql, 'pkgnum IS NULL'
    if $cgi->param('magic') eq 'unlinked';

  if ( $cgi->param('sortby') =~ /^(\w+)$/ ) {
    my $sortby = $1;
    $orderby = "ORDER BY $sortby";
  }
} elsif ( $cgi->param('svcpart') =~ /^(\d+)$/ ) {
  push @extra_sql, "svcpart = $1";
}

my $addl_from = ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                ' LEFT JOIN part_svc  USING ( svcpart ) '.
                ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                FS::UI::Web::join_cust_main('cust_pkg', 'cust_pkg');

#here is the agent virtualization
push @extra_sql, $FS::CurrentUser::CurrentUser->agentnums_sql(
                   'null_right' => 'View/link unlinked services'
                 );

my $extra_sql = 
  scalar(@extra_sql)
    ? ' WHERE '. join(' AND ', @extra_sql )
    : '';


my $count_query = "SELECT COUNT(*) FROM svc_dish $addl_from $extra_sql";
my $sql_query = {
  'table'     => 'svc_dish',
  'hashref'   => {},
  'select'    => join(', ',
                   'svc_dish.*',
                   'part_svc.svc',
                   'cust_main.custnum',
                   FS::UI::Web::cust_sql_fields(),
                 ),
  'extra_sql' => $extra_sql,
  'order_by'  => $orderby,
  'addl_from' => $addl_from,
};

my $link  = [ "${p}view/svc_dish.cgi?", 'svcnum', ];

my $link_cust = sub {
  my $svc_x = shift;
  $svc_x->custnum ? [ "${p}view/cust_main.cgi?", 'custnum' ] : '';
};

</%init>
