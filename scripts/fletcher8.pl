#!/usr/bin/perl
use v5.14;
use warnings;


sub fletcher8
{
    my (@data) = @_;

    my $ck_a = 0;
    my $ck_b = 0;

    foreach (@data) {
        $ck_a = ($ck_a + $_) & 0xFF;
        $ck_b = ($ck_b + $ck_a) & 0xFF;
    }

    return ($ck_a, $ck_b);
}


my @result = fletcher8( 0x03, 0x00, 0x00, 0x01, 0x0a, 0x0b );
say "$result[0] $result[1]";
