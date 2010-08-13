#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use FindBin;
use Encode;
use YAML;

use Path::Class;
use App::Options(
                 option => {
                            boundary  => "type=string; default=\t;",
                            t_col   => "type=integer; default=-1",
                            b_col => "type=integer; default=-1",
                           },
                );

my $basic_file = $ARGV[0];
my $target_file = $ARGV[1];
my $boundary = $App::options{boundary};
my $t_col = $App::options{t_col};
my $b_col = $App::options{b_col};

my ($b_in, $t_in);

open ($b_in, "< $basic_file");

my %hash = ();

while (my $l = <$b_in>) {
    if ($b_col >= 0) {
        my @arr = split /$boundary/, $l;
        $l = $arr[$b_col];
    }

    $l = Encode::decode_utf8($l) unless utf8::is_utf8($l);
    chomp $l;
    if (exists $hash{$l}) {
    }
    else {
        $hash{$l} = 1;
    }
}

close ($b_in);

open ($t_in, "< $basic_file");

while (my $l = <$t_in>) {
    if ($t_col >= 0) {
        my @arr = split /$boundary/, $l;
        $l = $arr[$t_col];
    }

    $l = Encode::decode_utf8($l) unless utf8::is_utf8($l);
    chomp $l;
    if (exists $hash{$l}) {
    }
    else {
        $l = Encode::encode_utf8($l) if utf8::is_utf8($l);
        print $l."促n";
    }
}

close ($t_in);
