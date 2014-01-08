package FS::payinfo_Mixin;

use strict;
use Business::CreditCard;
use FS::payby;
use FS::Record qw(qsearch);

use vars qw($ignore_masked_payinfo);

=head1 NAME

FS::payinfo_Mixin - Mixin class for records in tables that contain payinfo.  

=head1 SYNOPSIS

package FS::some_table;
use vars qw(@ISA);
@ISA = qw( FS::payinfo_Mixin FS::Record );

=head1 DESCRIPTION

This is a mixin class for records that contain payinfo. 

=head1 FIELDS

=over 4

=item payby

The following payment types (payby) are supported:

For Customers (cust_main):
'CARD' (credit card - automatic), 'DCRD' (credit card - on-demand),
'CHEK' (electronic check - automatic), 'DCHK' (electronic check - on-demand),
'LECB' (Phone bill billing), 'BILL' (billing), 'COMP' (free), or
'PREPAY' (special billing type: applies a credit and sets billing type to I<BILL> - see L<FS::prepay_credit>)

For Refunds (cust_refund):
'CARD' (credit cards), 'CHEK' (electronic check/ACH),
'LECB' (Phone bill billing), 'BILL' (billing), 'CASH' (cash),
'WEST' (Western Union), 'MCRD' (Manual credit card), 'CBAK' Chargeback, or 'COMP' (free)


For Payments (cust_pay):
'CARD' (credit cards), 'CHEK' (electronic check/ACH),
'LECB' (phone bill billing), 'BILL' (billing), 'PREP' (prepaid card),
'CASH' (cash), 'WEST' (Western Union), 'MCRD' (Manual credit card),
'PPAL' (PayPal)
'COMP' (free) is depricated as a payment type in cust_pay

=cut 

=item payinfo

Payment information (payinfo) can be one of the following types:

Card Number, P.O., comp issuer (4-8 lowercase alphanumerics; think username) 
prepayment identifier (see L<FS::prepay_credit>), PayPal transaction ID

=cut

sub payinfo {
  my($self,$payinfo) = @_;

  if ( defined($payinfo) ) {
    $self->setfield('payinfo', $payinfo);
    $self->paymask($self->mask_payinfo) unless $payinfo =~ /^(99\d{14}|card_token:.+)$/; #token
  } else {
    if ($self->{'decrypted'}->{'payinfo'}) {
      $self->getfield('payinfo');
    } else {
      $self->{'decrypted'}->{'payinfo'} = 1;
      $self->setfield('payinfo',$self->decrypt($self->getfield('payinfo')));
    }
  }
}

=item paycvv

Card Verification Value, "CVV2" (also known as CVC2 or CID), the 3 or 4 digit number on the back (or front, for American Express) of the credit card

=cut

#this prevents encrypting empty values on insert?
sub paycvv {
  my($self,$paycvv) = @_;
  # This is only allowed in cust_payby (formerly cust_main)
  #  It shouldn't be stored longer than necessary to run the first transaction
  if ( defined($paycvv) ) {
    $self->setfield('paycvv', $paycvv);
  } else {
    if ($self->{'decrypted'}->{'paycvv'}) {
      $self->getfield('paycvv');
    } else {
      $self->{'decrypted'}->{'paycvv'} = 1;
      $self->setfield('paycvv',$self->decrypt($self->getfield('paycvv')));
    }
  }
}

=item paymask

=cut

sub paymask {
  my($self, $paymask) = @_;

  if ( defined($paymask) ) {
    $self->setfield('paymask', $paymask);
  } else {
    $self->getfield('paymask') || $self->mask_payinfo;
  }
}

=back

=head1 METHODS

=over 4

=item mask_payinfo [ PAYBY, PAYINFO ]

This method converts the payment info (credit card, bank account, etc.) into a
masked string.

Optionally, an arbitrary payby and payinfo can be passed.

=cut

sub mask_payinfo {
  my $self = shift;
  my $payby   = scalar(@_) ? shift : $self->payby;
  my $payinfo = scalar(@_) ? shift : $self->payinfo;

  # Check to see if it's encrypted...
  if ( ref($self) && $self->is_encrypted($payinfo) ) {
    return 'N/A';
  } elsif ( $payinfo =~ /^99\d{14}$/ || $payinfo eq 'N/A' ) { #token
    return 'N/A (tokenized)'; #?
  } else { # if not, mask it...

    if ($payby eq 'CARD' || $payby eq 'DCRD' || $payby eq 'MCRD') {

      # Credit Cards

      # special handling for Local Isracards: always show last 4 
      if ( $payinfo =~ /^(\d{8,9})$/ ) {

        return 'x'x(length($payinfo)-4).
               substr($payinfo,(length($payinfo)-4));

      }

      my $conf = new FS::Conf;
      my $mask_method = $conf->config('card_masking_method') || 'first6last4';
      $mask_method =~ /^first(\d+)last(\d+)$/
        or die "can't parse card_masking_method $mask_method";
      my($first, $last) = ($1, $2);

      return substr($payinfo,0,$first).
             'x'x(length($payinfo)-$first-$last).
             substr($payinfo,(length($payinfo)-$last));

    } elsif ($payby eq 'CHEK' || $payby eq 'DCHK' ) {

      # Checks (Show last 2 @ bank)
      my( $account, $aba ) = split('@', $payinfo );
      return 'x'x(length($account)-2).
             substr($account,(length($account)-2)).
             ( length($aba) ? "@".$aba : '');

    } else { # Tie up loose ends
      return $payinfo;
    }
  }
  #die "shouldn't be reached";
}

=item payinfo_check

Checks payby and payinfo.

For Customers (cust_main):
'CARD' (credit card - automatic), 'DCRD' (credit card - on-demand),
'CHEK' (electronic check - automatic), 'DCHK' (electronic check - on-demand),
'LECB' (Phone bill billing), 'BILL' (billing), 'COMP' (free), or
'PREPAY' (special billing type: applies a credit - see L<FS::prepay_credit> and sets billing type to I<BILL>)

For Refunds (cust_refund):
'CARD' (credit cards), 'CHEK' (electronic check/ACH),
'LECB' (Phone bill billing), 'BILL' (billing), 'CASH' (cash),
'WEST' (Western Union), 'MCRD' (Manual credit card), 'CBAK' (Chargeback),  or 'COMP' (free)

For Payments (cust_pay):
'CARD' (credit cards), 'CHEK' (electronic check/ACH),
'LECB' (phone bill billing), 'BILL' (billing), 'PREP' (prepaid card),
'CASH' (cash), 'WEST' (Western Union), or 'MCRD' (Manual credit card)
'COMP' (free) is depricated as a payment type in cust_pay

=cut

sub payinfo_check {
  my $self = shift;

  FS::payby->can_payby($self->table, $self->payby)
    or return "Illegal payby: ". $self->payby;

  if ( $self->payby eq 'CARD' && ! $self->is_encrypted($self->payinfo) ) {
    my $payinfo = $self->payinfo;
    if ( $ignore_masked_payinfo and $self->mask_payinfo eq $self->payinfo ) {
      # allow it
    } elsif ( $payinfo =~ /^card_token:./) {
      # allow it
    } else {
      $payinfo =~ s/\D//g;
      $self->payinfo($payinfo);
      if ( $self->payinfo ) {
        $self->payinfo =~ /^(\d{13,16}|\d{8,9})$/
          or return "Illegal (mistyped?) credit card number (payinfo)";
        $self->payinfo($1);
        validate($self->payinfo) or return "Illegal credit card number";
        return "Unknown card type" if $self->payinfo !~ /^99\d{14}$/ #token
                                   && cardtype($self->payinfo) eq "Unknown";
      } else {
        $self->payinfo('N/A'); #???
      }
    }
  } else {
    if ( $self->is_encrypted($self->payinfo) ) {
      #something better?  all it would cause is a decryption error anyway?
      my $error = $self->ut_anything('payinfo');
      return $error if $error;
    } else {
      my $error = $self->ut_textn('payinfo');
      return $error if $error;
    }
  }

}

=item payby_payinfo_pretty [ LOCALE ]

Returns payment method and information (suitably masked, if applicable) as
a human-readable string, such as:

  Card #54xxxxxxxxxxxx32

or

  Check #119006

=cut

sub payby_payinfo_pretty {
  my $self = shift;
  my $locale = shift;
  my $lh = FS::L10N->get_handle($locale);
  if ( $self->payby eq 'CARD' ) {
    $lh->maketext('Card #') . $self->paymask;
  } elsif ( $self->payby eq 'CHEK' ) {

    #false laziness w/view/cust_main/payment_history.html::translate_payinfo
    my( $account, $aba ) = split('@', $self->paymask );

    if ( $aba =~ /^(\d{5})\.(\d{3})$/ ) { #blame canada
      my($branch, $routing) = ($1, $2);
      $lh->maketext("Routing [_1], Branch [_2], Acct [_3]",
                     $routing, $branch, $account);
    } else {
      $lh->maketext("Routing [_1], Acct [_2]", $aba, $account);
    }

  } elsif ( $self->payby eq 'BILL' ) {
    $lh->maketext('Check #') . $self->payinfo;
  } elsif ( $self->payby eq 'PREP' ) {
    $lh->maketext('Prepaid card #') . $self->payinfo;
  } elsif ( $self->payby eq 'CASH' ) {
    $lh->maketext('Cash') . ' ' . $self->payinfo;
  } elsif ( $self->payby eq 'WEST' ) {
    # does Western Union localize their name?
    $lh->maketext('Western Union');
  } elsif ( $self->payby eq 'MCRD' ) {
    $lh->maketext('Manual credit card');
  } elsif ( $self->payby eq 'PPAL' ) {
    $lh->maketext('PayPal transaction#') . $self->order_number;
  } else {
    $self->payby. ' '. $self->payinfo;
  }
}

=item payinfo_used [ PAYINFO ]

Returns 1 if there's an existing payment using this payinfo.  This can be 
used to set the 'recurring payment' flag required by some processors.

=cut

sub payinfo_used {
  my $self = shift;
  my $payinfo = shift || $self->payinfo;
  my %hash = (
    'custnum' => $self->custnum,
    'payby'   => 'CARD',
  );

  return 1
  if qsearch('cust_pay', { %hash, 'payinfo' => $payinfo } )
  || qsearch('cust_pay', 
    { %hash, 'paymask' => $self->mask_payinfo('CARD', $payinfo) }  )
  ;

  return 0;
}

=item display_status

For transactions that have both 'status' and 'failure_status', shows the
status in a single, display-friendly string.

=cut

sub display_status {
  my $self = shift;
  my %status = (
    'done'        => 'Approved',
    'expired'     => 'Card Expired',
    'stolen'      => 'Lost/Stolen',
    'pickup'      => 'Pick Up Card',
    'nsf'         => 'Insufficient Funds',
    'inactive'    => 'Inactive Account',
    'blacklisted' => 'Blacklisted',
    'declined'    => 'Declined',
    'approved'    => 'Approved',
  );
  if ( $self->failure_status ) {
    return $status{$self->failure_status};
  } else {
    return $status{$self->status};
  }
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::payby>, L<FS::Record>

=cut

1;

