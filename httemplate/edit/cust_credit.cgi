<%
#<!-- $Id: cust_credit.cgi,v 1.7 2001-12-26 15:07:06 ivan Exp $ -->

use strict;
use vars qw( $cgi $query $custnum $otaker $p1 $_date $amount $reason );
use Date::Format;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::CGI qw(header popurl small_custview);
use FS::Record qw(fields);
#use FS::cust_credit;

my $conf = new FS::Conf;

$cgi = new CGI;
cgisuidsetup($cgi);

if ( $cgi->param('error') ) {
  #$cust_credit = new FS::cust_credit ( {
  #  map { $_, scalar($cgi->param($_)) } fields('cust_credit')
  #} );
  $custnum = $cgi->param('custnum');
  $amount = $cgi->param('amount');
  #$refund = $cgi->param('refund');
  $reason = $cgi->param('reason');
} else {
  ($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $custnum = $1;
  $amount = '';
  #$refund = 'yes';
  $reason = '';
}
$_date = time;

$otaker = getotaker;

$p1 = popurl(1);

print header("Post Credit", '');
print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');
print <<END, small_custview($custnum, $conf->config('countrydefault'));
    <FORM ACTION="${p1}process/cust_credit.cgi" METHOD=POST>
    <INPUT TYPE="hidden" NAME="crednum" VALUE="">
    <INPUT TYPE="hidden" NAME="custnum" VALUE="$custnum">
    <INPUT TYPE="hidden" NAME="paybatch" VALUE="">
    <INPUT TYPE="hidden" NAME="_date" VALUE="$_date">
    <INPUT TYPE="hidden" NAME="credited" VALUE="">
    <INPUT TYPE="hidden" NAME="otaker" VALUE="$otaker">
END

print '<BR><BR>Credit'. ntable("#cccccc", 2).
      '<TR><TD ALIGN="right">Date</TD><TD BGCOLOR="#ffffff">'.
      time2str("%D",$_date).  '</TD></TR>';

print qq!<TR><TD ALIGN="right">Amount</TD><TD BGCOLOR="#ffffff">\$<INPUT TYPE="text" NAME="amount" VALUE="$amount" SIZE=8 MAXLENGTH=8></TD></TR>!;

#print qq! <INPUT TYPE="checkbox" NAME="refund" VALUE="$refund">Also post refund!;

print qq!<TR><TD ALIGN="right">Reason</TD><TD BGCOLOR="#ffffff"><INPUT TYPE="text" NAME="reason" VALUE="$reason"></TD></TR>!;

print qq!<TR><TD ALIGN="right">Auto-apply<BR>to invoices</TD><TD><SELECT NAME="apply"><OPTION VALUE="yes" SELECTED>yes<OPTION>no</SELECT></TD>!;

print <<END;
</TABLE>
<BR>
<INPUT TYPE="submit" VALUE="Post credit">
    </FORM>
  </BODY>
</HTML>
END

%>
