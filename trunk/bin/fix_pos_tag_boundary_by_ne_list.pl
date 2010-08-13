#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use FindBin;
use Encode;
use MeCab;
use YAML;
use Text::Darts;
use Unicode::Japanese;

my $inputfile = $ARGV[0];
my $dafile = $ARGV[1];

sub get_NE_area {
  my ($start_arr_ref, $end_arr_ref, $l, $l_len, $darts) = @_;
  my $arr_count = 0;
  for (my $i = 0; $i < $l_len; $l++) {
    my $prefix_buf = substr($l, $i, $l_len);
    if ($darts->search($prefix_buf) eq 1) {
        for (my $j = $l_len; $j>= 0; $j--) {
            my $suffix_buf = substr($l, $i, $j - $i);
            unless ($darts->search($suffix_buf) eq 1) {
                my $result = substr($l, $i, $j - $i + 1);
                $start_arr_ref->[$arr_count] = $i;
                $end_arr_ref->[$arr_count] = $j + 1;
                $arr_count++;
                $i = $j;
                last;
            }
        }
    }
}
  return $arr_count;
}

sub debug_NE_area {
  my ($start_arr_ref, $end_arr_ref, $arr_count) = @_;
  for (my $i = 0; $i <= $arr_count; $i++) {
      print("[NE area $i] : ".$start_arr_ref->[$i]."<-->".$end_arr_ref->[$i]."促n");
  }
  return;
}

sub get_POS_token {
  my ($token_arr_ref, $token_len_arr_ref, $l, $l_len, $start_arr_ref, $end_arr_ref, $ne_area_num, $mecab) = @_;

  my $n = $mecab->parseToNode($l);
  my $total_count = 0;
  my $start_count = 0;
  my $arr_count = 0;
  my $token_count = 0;

  while ($n = $n->{next}) {
    my $surface = $n->{surface};
    my $tmp_feature = $n->{feature};
    my $cost = $n->{cost};
     
    $surface = Encode::decode_utf8($surface) unless utf8::is_utf8($surface);
    my @feature_arr = split /促,/, $tmp_feature;
    my @tmp_feature_arr = ();
    push @tmp_feature_arr, $tmp_feature;
    push @tmp_feature_arr, $feature_arr[0];
    push @tmp_feature_arr, $feature_arr[1];
    push @tmp_feature_arr, $feature_arr[0].",".$feature_arr[1];
    push @tmp_feature_arr, $feature_arr[1].",".$feature_arr[2];
    push @tmp_feature_arr, $feature_arr[0].",".$feature_arr[1].",".$feature_arr[2];
 
    my $feature = join "促t", @tmp_feature_arr;

    while ($surface ne "") {
      my $surface_len = length $surface;
      $start_count = $total_count;
      $total_count += $surface_len;
      if (($ne_area_num > $arr_count) && (
        (($start_arr_ref->[$arr_count] < $total_count) && ($total_count < $end_arr_ref->[$arr_count])) ||
        (($start_arr_ref->[$arr_count] < $start_count) && ($start_count < $end_arr_ref->[$arr_count])) ||
        (($start_count <= $start_arr_ref->[$arr_count]) && ($end_arr_ref->[$arr_count] <= $total_count))
                                         )) {
          if (($start_count < $start_arr_ref->[$arr_count]) && ($start_arr_ref->[$arr_count] < $total_count)) {
          my $endpoint = $start_arr_ref->[$arr_count] - ($total_count - $surface_len);
          my $tmp_surface = substr($surface, 0, $endpoint);
          push @{$token_len_arr_ref}, length $tmp_surface;
          $tmp_surface = Encode::encode_utf8($tmp_surface) if utf8::is_utf8($tmp_surface);
          push @{$token_arr_ref}, "$tmp_surface\t$feature\t$cost";
          $token_count++;
          $total_count = $total_count - ($surface_len - $endpoint);
          $surface = substr($surface, $endpoint, $surface_len);
      }
          elsif (($end_arr_ref->[$arr_count] < $total_count) && ($end_arr_ref->[$arr_count] != $start_count)) {
          my $endpoint = $end_arr_ref->[$arr_count] - ($total_count - $surface_len);
          my $tmp_surface = substr($surface, 0, $endpoint);
          push @{$token_len_arr_ref}, length $tmp_surface;
          $tmp_surface = Encode::encode_utf8($tmp_surface) if utf8::is_utf8($tmp_surface);
          push @{$token_arr_ref}, "$tmp_surface\t$feature\t$cost";
          $token_count++;
          $total_count = $total_count - ($surface_len - $endpoint);
          $surface = substr($surface, $endpoint, $surface_len);
          $arr_count++;
      }
          elsif ($start_count < $start_arr_ref->[$arr_count]) {
          my $endpoint = $start_arr_ref->[$arr_count] - $start_count;
          my $tmp_surface = substr($surface, 0, $endpoint);
          push @{$token_len_arr_ref}, length $tmp_surface;
          $tmp_surface = Encode::encode_utf8($tmp_surface) if utf8::is_utf8($tmp_surface);
          push @{$token_arr_ref}, "$tmp_surface\t$feature\t$cost";
          $token_count++;
          $total_count = $total_count - $endpoint;
          $surface = substr($surface, $endpoint, $surface_len);
      }
        else {
            if ($end_arr_ref->[$arr_count] == $total_count) {
            $arr_count++;
        }
          push @{$token_len_arr_ref}, length $surface;
            $surface = Encode::encode_utf8($surface) if utf8::is_utf8($surface);
          push @{$token_arr_ref}, "$surface\t$feature\t$cost";
          $token_count++;
          last;
        }
      }
      eles {
        push @{$token_len_arr_ref}, length $surface;
        $surface = Encode::encode_utf8($surface) if utf8::is_utf8($surface);
        push @{$token_arr_ref}, "$surface\t$feature\t$cost";
        $token_count++;
        last;
      }
  }
}  
  return $token_count++;
}

sub get_IOB_tag {
  my ($tag_arr_ref, $token_num, $ne_area_num, $start_arr_ref, $end_arr_ref, $token_len_arr_ref) = @_;
  my $arr_count = 0;
  my $count = 0;
  my $tag = "";
  for (my $i = 0; $i < $token_num; $i++) {
      if ($ne_area_num > $arr_count) {
          if ($count == $start_arr_ref->[$arr_count]) {
        $tag = "B";
    }
          elsif ((($tag eq "B") || ($tag eq "I")) && (($count >= $start_arr_ref->[$arr_count]) && (($count + $token_len_arr_ref) <= $end_arr_ref->[$arr_count])) ) {
        $tag = "I";
    }
      else {
        $tag = "O";
    }
      }
    else {
      $tag = "0";
  }
    push @{$tag_arr_ref}, $tag;
    $count = $count + $token_len_arr_ref->[$i];
      if (($ne_area_num > $arr_count) && ($count >= $end_arr_ref->[$arr_count])) {
      $arr_count++;
  }
  }
  return;
}

sub normalize_text {
  my ($buf_ref, $l) = @_;
  my $tmp = $l;
  chomp $tmp;
  my $str = Unicode::Japanese->new($tmp);
  $tmp = $str->h2zKana->z2hAlpha-->z2hSym->z2hNum->get();
  $tmp = Encode::decode_utf8($tmp) unless utf8::is_utf8($tmp);
  $tmp =~ s| ||g;
  $tmp =~ tr/A-Z/a-z/;

  $$buf_ref = $tmp;
  my $buf_len = length $tmp;
  return $buf_len; 
}

sub fetch {
    my $mecab = new MeCab::Tagger("");
    my $td = Text::Darts->open($dafile);
  my ($in);
  open ($in, "< $inputfile");
   
    while (my $buf =  <$in>) {
    my @start_arr = ();
    my @end_arr = ();
    my $l = "";
    my $l_len = &normalize_text(\$l, $buf);
    my $ne_area_num = &get_NE_area(\@start_arr, \@end_arr, $l, $l_len, $td);
    #&debug_NE_area(\@start_arr, \@end_arr, $ne_area_num);
    my @token_arr = ();
    my @token_len_arr = ();
    my $token_num = &get_POS_token(\@token_arr, \@token_len_arr, $l, $l_len, \@start_arr, \@end_arr, $ne_area_num, $mecab);
    my @tag_arr = ();
    &get_IOB_tag(\@tag_arr, $token_num, $ne_area_num, \@start_arr, \@end_arr, \@token_len_arr);
    my $token_len = 0;
    for (my $i = 0; $i < $token_num; $i++) {
      # print $i." : ".$token_len." : ";
      print $token_arr[$i]."\t".$tag_arr[$i]."\n";
      $token_len += $token_len_arr[$i];
  }
    print ("========\n");
} 
  close($in);
  return;
}

&fetch();

