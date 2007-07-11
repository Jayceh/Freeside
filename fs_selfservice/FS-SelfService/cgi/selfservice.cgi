#!/usr/bin/perl -Tw

use strict;
use vars qw($DEBUG $cgi $session_id $form_max $template_dir);
use subs qw(do_template);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Text::Template;
use HTML::Entities;
use Date::Format;
use Number::Format 1.50;
use FS::SelfService qw( login customer_info invoice
                        payment_info process_payment 
                        process_prepay
                        list_pkgs order_pkg signup_info order_recharge
                        part_svc_info provision_acct provision_external
                        unprovision_svc change_pkg
                        list_svcs list_svc_usage myaccount_passwd
                      );

$template_dir = '.';

$DEBUG = 1;

$form_max = 255;

$cgi = new CGI;

unless ( defined $cgi->param('session') ) {
  do_template('login',{});
  exit;
}

if ( $cgi->param('session') eq 'login' ) {

  $cgi->param('username') =~ /^\s*([a-z0-9_\-\.\&]{0,$form_max})\s*$/i
    or die "illegal username";
  my $username = $1;

  $cgi->param('domain') =~ /^\s*([\w\-\.]{0,$form_max})\s*$/
    or die "illegal domain";
  my $domain = $1;

  $cgi->param('password') =~ /^(.{0,$form_max})$/
    or die "illegal password";
  my $password = $1;

  my $rv = login(
    'username' => $username,
    'domain'   => $domain,
    'password' => $password,
  );
  if ( $rv->{error} ) {
    do_template('login', {
      'error'    => $rv->{error},
      'username' => $username,
      'domain'   => $domain,
    } );
    exit;
  } else {
    $cgi->param('session' => $rv->{session_id} );
    $cgi->param('action'  => 'myaccount' );
  }
}

$session_id = $cgi->param('session');

#order|pw_list XXX ???
$cgi->param('action') =~
    /^(myaccount|view_invoice|make_payment|make_ach_payment|payment_results|ach_payment_results|recharge_prepay|recharge_results|logout|change_bill|change_ship|customer_order_pkg|process_order_pkg|customer_change_pkg|process_change_pkg|process_order_recharge|provision|provision_svc|process_svc_acct|process_svc_external|delete_svc|view_usage|view_usage_details|change_password|process_change_password)$/
  or die "unknown action ". $cgi->param('action');
my $action = $1;

warn "calling $action sub\n"
  if $DEBUG;
$FS::SelfService::DEBUG = $DEBUG;
my $result = eval "&$action();";
die $@ if $@;

if ( $result->{error} eq "Can't resume session"
  || $result->{error} eq "Expired session" ) { #ick

  do_template('login',{});
  exit;
}

#warn $result->{'open_invoices'};
#warn scalar(@{$result->{'open_invoices'}});

warn "processing template $action\n"
  if $DEBUG;
do_template($action, {
  'session_id' => $session_id,
  'action'     => $action, #so the menu knows what tab we're on...
  %{$result}
});

#--

sub myaccount { customer_info( 'session_id' => $session_id ); }

sub view_invoice {

  $cgi->param('invnum') =~ /^(\d+)$/ or die "illegal invnum";
  my $invnum = $1;

  invoice( 'session_id' => $session_id,
           'invnum'     => $invnum,
         );

}

sub customer_order_pkg {
  my $init_data = signup_info( 'customer_session_id' => $session_id );
  return $init_data if ( $init_data->{'error'} );

  my $customer_info = customer_info( 'session_id' => $session_id );
  return $customer_info if ( $customer_info->{'error'} );

  return {
    ( map { $_ => $init_data->{$_} }
          qw( part_pkg security_phrase svc_acct_pop ),
    ),
    %$customer_info,
  };
}

sub customer_change_pkg {
  my $init_data = signup_info( 'customer_session_id' => $session_id );
  return $init_data if ( $init_data->{'error'} );

  my $customer_info = customer_info( 'session_id' => $session_id );
  return $customer_info if ( $customer_info->{'error'} );

  return {
    ( map { $_ => $init_data->{$_} }
          qw( part_pkg security_phrase svc_acct_pop ),
    ),
    ( map { $_ => $cgi->param($_) }
        qw( pkgnum pkg )
    ),
    %$customer_info,
  };
}

sub process_order_pkg {

  my $results = '';

  unless ( length($cgi->param('_password')) ) {
    my $init_data = signup_info( 'customer_session_id' => $session_id );
    $results = { 'error' => $init_data->{msgcat}{empty_password} };
    $results = { 'error' => $init_data->{error} } if($init_data->{error});
  }
  if ( $cgi->param('_password') ne $cgi->param('_password2') ) {
    my $init_data = signup_info( 'customer_session_id' => $session_id );
    $results = { 'error' => $init_data->{msgcat}{passwords_dont_match} };
    $results = { 'error' => $init_data->{error} } if($init_data->{error});
    $cgi->param('_password', '');
    $cgi->param('_password2', '');
  }

  $results ||= order_pkg (
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) }
        qw( custnum pkgpart username _password _password2 sec_phrase popnum )
  );


  if ( $results->{'error'} ) {
    $action = 'customer_order_pkg';
    return {
      $cgi->Vars,
      %{customer_order_pkg()},
      'error' => '<FONT COLOR="#FF0000">'. $results->{'error'}. '</FONT>',
    };
  } else {
    return $results;
  }

}

sub process_change_pkg {

  my $results = '';

  $results ||= change_pkg (
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) }
        qw( pkgpart pkgnum )
  );


  if ( $results->{'error'} ) {
    $action = 'customer_change_pkg';
    return {
      $cgi->Vars,
      %{customer_change_pkg()},
      'error' => '<FONT COLOR="#FF0000">'. $results->{'error'}. '</FONT>',
    };
  } else {
    return $results;
  }

}

sub process_order_recharge {

  my $results = '';

  $results ||= order_recharge (
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) }
        qw( svcnum )
  );


  if ( $results->{'error'} ) {
    $action = 'view_usage';
    if ($results->{'error'} eq '_decline') {
      $results->{'error'} = "There has been an error processing your account.  Please contact customer support."
    }
    return {
      $cgi->Vars,
      %{view_usage()},
      'error' => '<FONT COLOR="#FF0000">'. $results->{'error'}. '</FONT>',
    };
  } else {
    return $results;
  }

}

sub make_payment {
  payment_info( 'session_id' => $session_id );
}

sub payment_results {

  use Business::CreditCard;

  #we should only do basic checking here for DoS attacks and things
  #that couldn't be constructed by the web form...  let process_payment() do
  #the rest, it gives better error messages

  $cgi->param('amount') =~ /^\s*(\d+(\.\d{2})?)\s*$/
    or die "Illegal amount: ". $cgi->param('amount'); #!!!
  my $amount = $1;

  my $payinfo = $cgi->param('payinfo');
  $payinfo =~ s/\D//g;
  $payinfo =~ /^(\d{13,16})$/
    #or $error ||= $init_data->{msgcat}{invalid_card}; #. $self->payinfo;
    or die "illegal card"; #!!!
  $payinfo = $1;
  validate($payinfo)
    #or $error ||= $init_data->{msgcat}{invalid_card}; #. $self->payinfo;
    or die "invalid card"; #!!!

  if ( $cgi->param('card_type') ) {
    cardtype($payinfo) eq $cgi->param('card_type')
      #or $error ||= $init_data->{msgcat}{not_a}. $cgi->param('CARD_type');
      or die "not a ". $cgi->param('card_type');
  }

  $cgi->param('paycvv') =~ /^\s*(.{0,4})\s*$/ or die "illegal CVV2";
  my $paycvv = $1;

  $cgi->param('month') =~ /^(\d{2})$/ or die "illegal month";
  my $month = $1;
  $cgi->param('year') =~ /^(\d{4})$/ or die "illegal year";
  my $year = $1;

  $cgi->param('payname') =~ /^(.{0,80})$/ or die "illegal payname";
  my $payname = $1;

  $cgi->param('address1') =~ /^(.{0,80})$/ or die "illegal address1";
  my $address1 = $1;

  $cgi->param('address2') =~ /^(.{0,80})$/ or die "illegal address2";
  my $address2 = $1;

  $cgi->param('city') =~ /^(.{0,80})$/ or die "illegal city";
  my $city = $1;

  $cgi->param('state') =~ /^(.{2})$/ or die "illegal state";
  my $state = $1;

  $cgi->param('zip') =~ /^(.{0,10})$/ or die "illegal zip";
  my $zip = $1;

  my $save = 0;
  $save = 1 if $cgi->param('save');

  my $auto = 0;
  $auto = 1 if $cgi->param('auto');

  $cgi->param('paybatch') =~ /^([\w\-\.]+)$/ or die "illegal paybatch";
  my $paybatch = $1;

  process_payment(
    'session_id' => $session_id,
    'payby'      => 'CARD',
    'amount'     => $amount,
    'payinfo'    => $payinfo,
    'paycvv'     => $paycvv,
    'month'      => $month,
    'year'       => $year,
    'payname'    => $payname,
    'address1'   => $address1,
    'address2'   => $address2,
    'city'       => $city,
    'state'      => $state,
    'zip'        => $zip,
    'save'       => $save,
    'auto'       => $auto,
    'paybatch'   => $paybatch,
  );

}

sub make_ach_payment {
  payment_info( 'session_id' => $session_id );
}

sub ach_payment_results {

  #we should only do basic checking here for DoS attacks and things
  #that couldn't be constructed by the web form...  let process_payment() do
  #the rest, it gives better error messages

  $cgi->param('amount') =~ /^\s*(\d+(\.\d{2})?)\s*$/
    or die "illegal amount"; #!!!
  my $amount = $1;

  my $payinfo1 = $cgi->param('payinfo1');
  $payinfo1=~ /^(\d+)$/
    or die "illegal account"; #!!!
  $payinfo1= $1;

  my $payinfo2 = $cgi->param('payinfo2');
  $payinfo2=~ /^(\d+)$/
    or die "illegal ABA/routing code"; #!!!
  $payinfo2= $1;

  $cgi->param('payname') =~ /^(.{0,80})$/ or die "illegal payname";
  my $payname = $1;

  $cgi->param('paystate') =~ /^(.{0,2})$/ or die "illegal paystate";
  my $paystate = $1;

  $cgi->param('paytype') =~ /^(.{0,80})$/ or die "illegal paytype";
  my $paytype = $1;

  $cgi->param('ss') =~ /^(.{0,80})$/ or die "illegal ss";
  my $ss = $1;

  $cgi->param('stateid') =~ /^(.{0,80})$/ or die "illegal stateid";
  my $stateid = $1;

  $cgi->param('stateid_state') =~ /^(.{0,2})$/ or die "illegal stateid_state";
  my $stateid_state = $1;

  my $save = 0;
  $save = 1 if $cgi->param('save');

  my $auto = 0;
  $auto = 1 if $cgi->param('auto');

  $cgi->param('paybatch') =~ /^([\w\-\.]+)$/ or die "illegal paybatch";
  my $paybatch = $1;

  process_payment(
    'session_id' => $session_id,
    'payby'      => 'CHEK',
    'amount'     => $amount,
    'payinfo1'   => $payinfo1,
    'payinfo2'   => $payinfo2,
    'month'      => '12',
    'year'       => '2037',
    'payname'    => $payname,
    'paytype'    => $paytype,
    'paystate'   => $paystate,
    'ss'         => $ss,
    'stateid'    => $stateid,
    'stateid_state' => $stateid_state,
    'save'       => $save,
    'auto'       => $auto,
    'paybatch'   => $paybatch,
  );

}

sub recharge_prepay {
  customer_info( 'session_id' => $session_id );
}

sub recharge_results {

  my $prepaid_cardnum = $cgi->param('prepaid_cardnum');
  $prepaid_cardnum =~ s/\W//g;
  $prepaid_cardnum =~ /^(\w*)$/ or die "illegal prepaid card number";
  $prepaid_cardnum = $1;

  process_prepay ( 'session_id'     => $session_id,
                   'prepaid_cardnum' => $prepaid_cardnum,
                 );
}

sub logout {
  FS::SelfService::logout( 'session_id' => $session_id );
}

sub provision {
  my $result = list_pkgs( 'session_id' => $session_id );
  die $result->{'error'} if exists $result->{'error'} && $result->{'error'};
  $result;
}

sub provision_svc {

  my $result = part_svc_info(
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) } qw( pkgnum svcpart ),
  );
  die $result->{'error'} if exists $result->{'error'} && $result->{'error'};

  $result->{'svcdb'} =~ /^svc_(.*)$/
    #or return { 'error' => 'Unknown svcdb '. $result->{'svcdb'} };
    or die 'Unknown svcdb '. $result->{'svcdb'};
  $action .= "_$1";

  $result;
}

sub process_svc_acct {

  my $result = provision_acct (
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) } qw(
      pkgnum svcpart username _password _password2 sec_phrase popnum )
  );

  if ( exists $result->{'error'} && $result->{'error'} ) { 
    #warn "$result $result->{'error'}"; 
    $action = 'provision_svc_acct';
    return {
      $cgi->Vars,
      %{ part_svc_info( 'session_id' => $session_id,
                        map { $_ => $cgi->param($_) } qw( pkgnum svcpart )
                      )
      },
      'error' => $result->{'error'},
    };
  } else {
    #warn "$result $result->{'error'}"; 
    return $result;
  }

}

sub process_svc_external {
  provision_external (
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) } qw( pkgnum svcpart )
  );
}

sub delete_svc {
  unprovision_svc(
    'session_id' => $session_id,
    'svcnum'     => $cgi->param('svcnum'),
  );
}

sub view_usage {
  list_svcs(
    'session_id'  => $session_id,
    'svcdb'       => 'svc_acct',
    'ncancelled'  => 1,
  );
}

sub view_usage_details {
  list_svc_usage(
    'session_id'  => $session_id,
    'svcnum'      => $cgi->param('svcnum'),
    'beginning'   => $cgi->param('beginning') || '',
    'ending'      => $cgi->param('ending') || '',
  );
}

sub change_password {
  list_svcs(
    'session_id' => $session_id,
    'svcdb'      => 'svc_acct',
  );
};

sub process_change_password {

  my $result = myaccount_passwd(
    'session_id'    => $session_id,
    map { $_ => $cgi->param($_) } qw( svcnum new_password new_password2 )
  );

  if ( exists $result->{'error'} && $result->{'error'} ) { 

    $action = 'change_password';
    return {
      $cgi->Vars,
      %{ list_svcs( 'session_id' => $session_id,
                    'svcdb'      => 'svc_acct',
                  )
       },
      #'svcnum' => $cgi->param('svcnum'),
      'error'  => $result->{'error'}
    };

 } else {

   return $result;

 }

}

#--

sub do_template {
  my $name = shift;
  my $fill_in = shift;

  $cgi->delete_all();
  $fill_in->{'selfurl'} = $cgi->self_url;
  $fill_in->{'cgi'} = \$cgi;

  my $template = new Text::Template( TYPE    => 'FILE',
                                     SOURCE  => "$template_dir/$name.html",
                                     DELIMITERS => [ '<%=', '%>' ],
                                     UNTAINT => 1,                    )
    or die $Text::Template::ERROR;

  print $cgi->header( '-expires' => 'now' ),
        $template->fill_in( PACKAGE => 'FS::SelfService::_selfservicecgi',
                            HASH    => $fill_in
                          );
}

#*FS::SelfService::_selfservicecgi::include = \&Text::Template::fill_in_file;

package FS::SelfService::_selfservicecgi;

#use FS::SelfService qw(regionselector expselect popselector);
use HTML::Entities;
use FS::SelfService qw(popselector);

#false laziness w/agent.cgi
sub include {
  my $name = shift;
  my $template = new Text::Template( TYPE   => 'FILE',
                                     SOURCE => "$main::template_dir/$name.html",
                                     DELIMITERS => [ '<%=', '%>' ],
                                     UNTAINT => 1,                   
                                   )
    or die $Text::Template::ERROR;

  $template->fill_in( PACKAGE => 'FS::SelfService::_selfservicecgi',
                      #HASH    => $fill_in
                    );

}

