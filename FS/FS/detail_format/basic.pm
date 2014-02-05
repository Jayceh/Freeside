package FS::detail_format::basic;

use strict;
use base qw(FS::detail_format);

sub name { 'Basic' }

sub header_detail { 'Date/Time,Called Number,Min/Sec,Price' }

sub columns {
  my $self = shift;
  my $cdr = shift;
  (
    $self->time2str_local('%d %b - %I:%M %p', $cdr->startdate),
    $cdr->dst,
    $self->duration($cdr),
    $self->price($cdr),
  )
}

1;
