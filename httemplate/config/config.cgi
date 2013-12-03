<% include("/elements/header-popup.html", $title) %>

<SCRIPT>
var gSafeOnload = new Array();
var gSafeOnsubmit = new Array();
window.onload = SafeOnload;
function SafeAddOnLoad(f) {
  gSafeOnload[gSafeOnload.length] = f;
}
function SafeOnload() {
  for (var i=0;i<gSafeOnload.length;i++)
    gSafeOnload[i]();
}
function SafeAddOnSubmit(f) {
  gSafeOnsubmit[gSafeOnsubmit.length] = f;
}
function SafeOnsubmit() {
  for (var i=0;i<gSafeOnsubmit.length;i++)
    gSafeOnsubmit[i]();
}
</SCRIPT>

<% include('/elements/error.html') %>

<FORM NAME="OneTrueForm" ACTION="config-process.cgi" METHOD="POST" enctype="multipart/form-data" onSubmit="SafeOnsubmit()">
<INPUT TYPE="hidden" NAME="agentnum" VALUE="<% $agentnum %>">
<INPUT TYPE="hidden" NAME="locale" VALUE="<% $locale %>">
<INPUT TYPE="hidden" NAME="key" VALUE="<% $key %>">

Setting <b><% $key %></b>

% my $description_printed = 0;
% if ( grep $_ eq 'textarea', @types ) {
%   $description_printed = 1;

    - <% $description %>

% }

<table><tr><td>

% my $n = 0;
% my $submit = 0;
% foreach my $type (@types) {
%   if ( $type eq '' ) {

  <font color="#ff0000">no type</font>

%   } elsif ( $type eq 'image' ) { 
%     $submit++;

  <% $conf->exists($key, $agentnum)
       ? 'Current image<br>'.
         '<img src="config-image.cgi?key='.      $key.
                                   ';agentnum='. $agentnum.
                                   ';locale='.   $locale .'"><br>'
       : ''
  %>

  <BR>
  New image filename <input type="file" name="<% "$key$n" %>">

%   } elsif ( $type eq 'binary' ) { 
%     $submit++;

  Filename <input type="file" name="<% "$key$n" %>">

%   } elsif ( $type eq 'textarea' ) { 
%     $submit++;

  <textarea name="<% "$key$n" %>" rows=12 cols=78 wrap="off"><% join("\n", $conf->config($key, $agentnum)) |h %></textarea>

%   } elsif ( $type eq 'checkbox' ) { 
%
%     if ( $agentnum && $conf->exists($key) && ! $agent_bool ) {

        <input name="<% "$key$n" %>" type="checkbox" value="1" CHECKED DISABLED>
        <FONT SIZE="-1"><I>(global setting cannot yet be overridden)</I></FONT>

%     } else {
%       $submit++;

        <input name="<% "$key$n" %>" type="checkbox" value="1"
          <% $conf->config_bool($key, $agentnum) ? 'CHECKED' : '' %> >
%     }

%   } elsif ( $type eq 'text' )  {
%     $submit++;

  <input name="<% "$key$n" %>" type="text" value="<% $conf->exists($key, $agentnum) ? $conf->config($key, $agentnum) : '' |h %>">

%   } elsif ( $type eq 'select' || $type eq 'selectmultiple' )  {
%     $submit++;
 
  <select name="<% "$key$n" %>" <% $type eq 'selectmultiple' ? 'MULTIPLE' : '' %> size='15'>

%
%     my %hash = ();
%     if ( $config_item->select_enum ) {
%       tie %hash, 'Tie::IxHash',
%         '' => '', map { $_ => $_ } @{ $config_item->select_enum };
%     } elsif ( $config_item->select_hash ) {
%       if ( ref($config_item->select_hash) eq 'ARRAY' ) {
%         tie %hash, 'Tie::IxHash', '' => '', @{ $config_item->select_hash };
%       } else {
%         tie %hash, 'Tie::IxHash', '' => '', %{ $config_item->select_hash };
%       }
%     } else {
%       %hash = ( '' => 'WARNING: neither select_enum nor select_hash specified in Conf.pm for configuration option "'. $key. '"' );
%     }
%
%     my %saw = ();
%     foreach my $value ( keys %hash ) {
%       local($^W)=0; next if $saw{$value}++;
%       my $label = $hash{$value};
%        

    <option value="<% $value %>"

%       if ( $value eq $conf->config($key, $agentnum)
%            || ( $type eq 'selectmultiple'
%                 && grep { $_ eq $value } $conf->config($key, $agentnum) ) ) {

      SELECTED

%       }

    ><% $label %>

%     } 
%     my $curvalue = $conf->config($key, $agentnum);
%     if ( $conf->exists($key, $agentnum) && $curvalue && ! $hash{$curvalue} ) {

    <option value="<% $curvalue %>" SELECTED>

%       if ( exists( $hash{ $conf->config($key, $agentnum) } ) ) {

      <% $hash{ $conf->config($key, $agentnum) } %>

%       }else{

      <% $curvalue %>

%       }
%     } 

  </select>

%   } elsif ( $type eq 'select-sub' ) {
%     $submit++;

  <select name="<% "$key$n" %>" <% $config_item->multiple ? 'MULTIPLE' : '' %> size='15' >

%     unless ( $config_item->multiple ) {
        <option value="">
%     }

%     my %options = &{$config_item->options_sub};
%     my @options = keys %options;
%     my $sortsub = $config_item->sort_sub || sub { $a <=> $b };
%     @options = sort $sortsub @options;
%     my %saw;
%     foreach my $value ( @options ) {
%       local($^W)=0; next if $saw{$value}++;

        <option value="<% $value %>"

%         if ( $value eq $conf->config($key, $agentnum)
%              || ( $config_item->multiple
%                   && grep { $_ eq $value } $conf->config($key, $agentnum) ) ){
            SELECTED
%         }

        ><% $value %>: <% $options{$value} %>

%     } 
%     my $curvalue = $conf->config($key, $agentnum);
%     if ( $conf->exists($key, $agentnum) && $curvalue && ! $options{$curvalue} ) {

    <option value="<% $curvalue %>" SELECTED> <% $curvalue %>: <% &{ $config_item->option_sub }( $curvalue ) %> 

%     } 

  </select>

%   } elsif ( $type eq 'editlist' ) {
%     $submit++;
  <script>
    function doremove<% "$key$n" %>() {
      fromObject = document.OneTrueForm.<% "$key$n" %>;
      for (var i=fromObject.options.length-1;i>-1;i--) {
        if (fromObject.options[i].selected)
          deleteOption<% "$key$n" %>(fromObject,i);
      }
    }
    function deleteOption<% "$key$n" %>(object,index) {
      object.options[index] = null;
    }
    function selectall<% "$key$n" %>() {
      fromObject = document.OneTrueForm.<% "$key$n" %>;
      for (var i=fromObject.options.length-1;i>-1;i--) {
        fromObject.options[i].selected = true;
      }
    }
    function doadd<% "$key$n" %>(object) {
      var myvalue = "";

%     if ( defined($config_item->editlist_parts) ) { 
%       foreach my $pnum ( 0 .. scalar(@{$config_item->editlist_parts})-1 ) { 

      if ( myvalue != "" ) { myvalue = myvalue + " "; }

%         if ( $config_item->editlist_parts->[$pnum]{type} eq 'select' ) { 

      myvalue = myvalue + object.add<% "$key${n}_$pnum" %>.options[object.add<% "$key${n}_$pnum" %>.selectedIndex].value
      <!-- #RESET SELECT??  maybe not... -->

%         } elsif ( $config_item->editlist_parts->[$pnum]{type} eq 'immutable' ) { 

      myvalue = myvalue + object.add<% "$key${n}_$pnum" %>.value

%         } else { 

      myvalue = myvalue + object.add<% "$key${n}_$pnum" %>.value
      object.add<% "$key${n}_$pnum" %>.value = ""

%         } 
%       } 
%     } else { 

      myvalue = object.add<% "$key${n}_1" %>.value

%     } 

      var optionName = new Option(myvalue, myvalue);
      var length = object.<% "$key$n" %>.length;
      object.<% "$key$n" %>.options[length] = optionName;
    }
  </script>
  <select multiple size=5 name="<% "$key$n" %>">
    <option selected>----------------------------------------------------------------</option>

%     foreach my $line ( $conf->config($key, $agentnum) ) { 

    <option value="<% $line %>"><% $line %></option>

%     } 

  </select><br>
  <input type="button" value="remove selected" onClick="doremove<% "$key$n" %>()">
  <script>SafeAddOnLoad(doremove<% "$key$n" %>);
    SafeAddOnSubmit(selectall<% "$key$n" %>);
  </script>
  <br><% itable() %><tr>

%     if ( defined $config_item->editlist_parts ) { 
%       my $pnum=0;
%       foreach my $part ( @{$config_item->editlist_parts} ) { 

    <td>

%         if ( $part->{type} eq 'text' ) { 

      <input type="text" name="add<% "$key${n}_$pnum" %>">

%         } elsif ( $part->{type} eq 'immutable' ) { 

      <% $part->{value} %>
      <input type="hidden" name="add<% "$key${n}_$pnum" %>" value="<% $part->{value} %>">

%         } elsif ( $part->{type} eq 'select' ) { 

      <select name="add<% qq!$key${n}_$pnum! %>">

%           foreach my $key ( keys %{$part->{select_enum}} ) { 

        <option value="<% $key %>"><% $part->{select_enum}{$key} %></option>

%           } 

      </select>

%         } else { 

      <font color="#ff0000">unknown type <% $part->type %> </font>

%         } 

    </td>

%         $pnum++;
%       } 
%     } else { 

    <td><input type="text" name="add<% "$key${n}_0" %>></td>

%     } 

    <td><input type="button" value="add" onClick="doadd<% "$key$n" %>(this.form)"></td>
  </tr></table>

%   } elsif ( $element_types{$type} ) {
%     $submit++;
%
%     my %opt = ( 'element_name' => "$key$n",
%                 'empty_label'  => ' ',
%               );
%     if ( $config_item->multiple ) {
%       $opt{'multiple'} = 1 if $config_item->multiple;
%       $opt{'curr_value'} = [ $conf->config($key, $agentnum) ];
%     } else {
%       $opt{'curr_value'} = 
%         $conf->exists($key, $agentnum) ? $conf->config($key, $agentnum) : '';
%     }

      <% include("/elements/$type.html", %opt ) %>

%   } else {

      <font color="#ff0000">unknown type <% $type %></font>

%   }
% $n++;
% }

  </td>
% unless ( $description_printed ) {
    <td><% $description %></td>
% }
</tr>
</table>

% if ( $submit ) {
  <INPUT TYPE="submit" VALUE="<% $title %>">
% }
</FORM>

</BODY>
</HTML>
<%once>

my %element_types = map { $_ => 1 } qw(
  select-part_svc select-part_pkg select-pkg_class select-agent
);

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $action = 'Set';

my $agentnum = '';
if ($cgi->param('agentnum') =~ /(\d+)$/) {
  $agentnum=$1;
}

my $locale = '';
if ( $cgi->param('locale') =~ /^(\w+_\w+)$/) {
  $locale = $1;
}

my $conf = new FS::Conf { 'locale' => $locale, 'localeonly' => 1 };
my @config_items = $conf->config_items; 
my %confitems = map { $_->key => $_ } @config_items;

my $agent = '';
my $title;
if ($agentnum) {
  $agent = qsearchs('agent', { 'agentnum' => $1 } );
  die "Agent $agentnum not found!" unless $agent;

  $title = "$action configuration override for ". $agent->agent;
} else {
  $title = "$action global configuration";
}

$cgi->param('key') =~ /^([-.\w]+)$/ or die "illegal configuration item";
my $key = $1;
my $value = $conf->config($key);
my $config_item = $confitems{$key};

my $description = $config_item->description;
my $config_type = $config_item->type;
my @types = ref($config_type) ? @$config_type : ($config_type);
my $agent_bool = $config_item->agent_bool;

</%init>
