<%init>

my $curuser = $FS::CurrentUser::CurrentUser;
die "access denied\n" unless $curuser->access_right('Configuration');

my $fsconf = new FS::Conf;
if ( $fsconf->exists('disable_settings_changes') ) {
  my @changers = split(/\s*,\s*/, $fsconf->config('disable_settings_changes'));
  my %changers = map { $_=>1 } @changers;
  unless ( $changers{$curuser->username} ) {
    errorpage("Disabled in web demo");
    die "shouldn't be reached";
  }
}

$cgi->param('confnum') =~ /^(\d+)$/ or die "illegal or missing confnum";
my $confnum = $1;

my $conf = qsearchs('conf', {'confnum' => $confnum});
die "Configuration not found!" unless $conf;
$conf->delete;

my $redirect = popurl(2);
if ( $cgi->param('redirect') eq 'config_view_showagent' ) {
  $redirect .= 'config/config-view.cgi?showagent=1#'. $conf->name;
} elsif ( $cgi->param('redirect') eq 'config_view' ) {
  $redirect .= 'config/config-view.cgi';
} else {
  $redirect .= 'browse/agent.cgi';
}

</%init>
<% $cgi->redirect($redirect) %>
