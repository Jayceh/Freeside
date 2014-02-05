% if( $response->is_success ) {
<% $response->decoded_content %>
% }
% else {
<% $response->error_as_HTML %>
% }
<%init>

my( $custnum ) = $cgi->param('custnum');
my $cust_main = qsearchs('cust_main', { custnum => $custnum } ) 
  or die "custnum '$custnum' not found"; # just check for existence

my $conf = new FS::Conf;
my $url = $conf->config('cust_main-custom_link');

my $agentnum = $cust_main->agentnum;
my $agent_custid = $cust_main->agent_custid;
my $curuser = $FS::CurrentUser::CurrentUser;
my $usernum = $curuser->usernum;
# like eval(qq("$url")) but with fewer things that can go wrong
# and if $custnum isn't mentioned, assume it goes at the end
$url =~ s/\$custnum/$custnum/ or $url .= $custnum;
$url =~ s/\$agentnum/$agentnum/;
$url =~ s/\$agent_custid/$agent_custid/;
$url =~ s/\$usernum/$usernum/;

#warn $url;

die "access denied"
  unless $curuser->access_right('View customer');

my $ua = new LWP::UserAgent;
my $response = $ua->get($url);
</%init>
