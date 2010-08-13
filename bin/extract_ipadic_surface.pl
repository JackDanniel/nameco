#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use FindBin;
use Encode;
use YAML;

use Path::Class;

my $ipadic_dir = $ARGV[0];

my $dir = dir($ipadic_dir);

while (my $fileinfo = $dir->next()) {
    my $filename = $fileinfo->{file};
    if (($filename) && ($filename =~ m|.+¥.cvs$|)) {
        my ($in);
        open ($in, "< $ipadic_dir/$filename");
        
        while (my $l = <$in>) {
            $l = Encode::decode('euc-jp', $l);
            my @arr = split /¥,/, $l;
            my $surface = $arr[0];
            $surface = Encode::encode_utf8($surface) if utf8::is_utf8($surface);
            print $surface."¥n";
        }
        
        close($in);
    }
}
