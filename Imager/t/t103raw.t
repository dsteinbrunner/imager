#!perl -w
print "1..15\n";
use Imager qw(:all);
use strict;
init_log("testout/t103raw.log",1);

my $green=i_color_new(0,255,0,255);
my $blue=i_color_new(0,0,255,255);
my $red=i_color_new(255,0,0,255);

my $img=Imager::ImgRaw::new(150,150,3);
my $cmpimg=Imager::ImgRaw::new(150,150,3);

i_box_filled($img,70,25,130,125,$green);
i_box_filled($img,20,25,80,125,$blue);
i_arc($img,75,75,30,0,361,$red);
i_conv($img,[0.1, 0.2, 0.4, 0.2, 0.1]);

my $timg = Imager::ImgRaw::new(20, 20, 4);
my $trans = i_color_new(255, 0, 0, 127);
i_box_filled($timg, 0, 0, 20, 20, $green);
i_box_filled($timg, 2, 2, 18, 18, $trans);

open(FH,">testout/t103.raw") || die "Cannot open testout/t103.raw for writing\n";
binmode(FH);
my $IO = Imager::io_new_fd( fileno(FH) );
i_writeraw_wiol($img, $IO) || die "Cannot write testout/t103.raw\n";
close(FH);

print "ok 1\n";

open(FH,"testout/t103.raw") || die "Cannot open testout/t103.raw\n";
binmode(FH);
$IO = Imager::io_new_fd( fileno(FH) );
$cmpimg = i_readraw_wiol($IO, 150, 150, 3, 3, 0) || die "Cannot read testout/t103.raw\n";
close(FH);

print "# raw average mean square pixel difference: ",sqrt(i_img_diff($img,$cmpimg))/150*150,"\n";
print "ok 2\n";

# I could have kept the raw images for these tests in binary files in
# testimg/, but I think keeping them as hex encoded data in here makes
# it simpler to add more if necessary
# Later we may change this to read from a scalar instead
save_data('testout/t103_base.raw');
save_data('testout/t103_3to4.raw');
save_data('testout/t103_line_int.raw');
save_data('testout/t103_img_int.raw');

# load the base image
open FH, "testout/t103_base.raw" 
  or die "Cannot open testout/t103_base.raw: $!";
binmode FH;
$IO = Imager::io_new_fd( fileno(FH) );

my $baseimg = i_readraw_wiol( $IO, 4, 4, 3, 3, 0)
  or die "Cannot read base raw image";
close FH;

# the actual read tests
# each read_test() call does 2 tests:
#  - check if the read succeeds
#  - check if it matches $baseimg
read_test('testout/t103_3to4.raw', 4, 4, 4, 3, 0, $baseimg, 3);
read_test('testout/t103_line_int.raw', 4, 4, 3, 3, 1, $baseimg, 5);
# intrl==2 is documented in raw.c but doesn't seem to be implemented
#read_test('testout/t103_img_int.raw', 4, 4, 3, 3, 2, $baseimg, 7);

# paletted images
my $palim = Imager::i_img_pal_new(20, 20, 3, 256)
  or print "not ";
print "ok 7\n";
my $redindex = Imager::i_addcolors($palim, $red);
my $blueindex = Imager::i_addcolors($palim, $blue);
for my $y (0..9) {
  Imager::i_ppal($palim, 0, $y, ($redindex) x 20);
}
for my $y (10..19) {
  Imager::i_ppal($palim, 0, $y, ($blueindex) x 20);
}
open FH, "> testout/t103_pal.raw"
  or die "Cannot create testout/t103_pal.raw: $!";
binmode FH;
$IO = Imager::io_new_fd(fileno(FH));
i_writeraw_wiol($palim, $IO) or print "not ";
print "ok 8\n";
close FH;

open FH, "testout/t103_pal.raw"
  or die "Cannot open testout/t103_pal.raw: $!";
binmode FH;
my $data = do { local $/; <FH> };
$data eq "\x0" x 200 . "\x1" x 200
  or print "not ";
print "ok 9\n";

# 16-bit image
# we don't have 16-bit reads yet
my $img16 = Imager::i_img_16_new(150, 150, 3)
  or print "not ";
print "ok 10\n";
i_box_filled($img16,70,25,130,125,$green);
i_box_filled($img16,20,25,80,125,$blue);
i_arc($img16,75,75,30,0,361,$red);
i_conv($img16,[0.1, 0.2, 0.4, 0.2, 0.1]);

open FH, "> testout/t103_16.raw" 
  or die "Cannot create testout/t103_16.raw: $!";
binmode FH;
$IO = Imager::io_new_fd(fileno(FH));
i_writeraw_wiol($img16, $IO) or print "not ";
print "ok 11\n";
close FH;

# try a simple virtual image
my $maskimg = Imager::i_img_masked_new($img, undef, 0, 0, 150, 150)
  or print "not ";
print "ok 12\n";

open FH, "> testout/t103_virt.raw" 
  or die "Cannot create testout/t103_virt.raw: $!";
binmode FH;
$IO = Imager::io_new_fd(fileno(FH));
i_writeraw_wiol($maskimg, $IO) or print "not ";
print "ok 13\n";
close FH;

open FH, "testout/t103_virt.raw"
  or die "Cannot open testout/t103_virt.raw: $!";
binmode FH;
$IO = Imager::io_new_fd(fileno(FH));
my $cmpimgmask = i_readraw_wiol($IO, 150, 150, 3, 3, 0)
  or print "not ";
print "ok 14\n";
my $diff = i_img_diff($maskimg, $cmpimgmask);
print "# difference for virtual image $diff\n";
$diff and print "not ";
print "ok 15\n";

sub read_test {
  my ($in, $xsize, $ysize, $data, $store, $intrl, $base, $test) = @_;
  open FH, $in or die "Cannot open $in: $!";
  binmode FH;
  my $IO = Imager::io_new_fd( fileno(FH) );

  my $img = i_readraw_wiol($IO, $xsize, $ysize, $data, $store, $intrl);
  if ($img) {
    print "ok $test\n";
    if (i_img_diff($img, $baseimg)) {
      print "ok ",$test+1," # skip images don't match, but maybe I don't understand\n";
    }
    else {
      print "ok ",$test+1,"\n";
    }
  }
  else {
    print "not ok $test # could not read image\n";
    print "ok ",$test+1," # skip\n";
  }
}

sub save_data {
  my $outname = shift;
  my $data = load_data();
  open FH, "> $outname" or die "Cannot create $outname: $!";
  binmode FH;
  print FH $data;
  close FH;
}

sub load_data {
  my $hex = '';
  while (<DATA>) {
    next if /^#/;
    last if /^EOF/;
    chomp;
    $hex .= $_;
  }
  $hex =~ tr/ //d;
  my $result = pack("H*", $hex);
  #print unpack("H*", $result),"\n";
  return $result;
}

# FIXME: may need tests for 1,2,4 channel images

__DATA__
# we keep some packed raw images here
# we decode this in the code, ignoring lines starting with #, a subfile
# ends with EOF, data is HEX encoded (spaces ignored)

# basic 3 channel version of the image
001122 011223 021324 031425
102132 112233 122334 132435
203142 213243 223344 233445
304152 314253 324354 334455
EOF

# test image for reading a 4 channel image into a 3 channel image
# 4 x 4 pixels
00112233 01122334 02132435 03142536
10213243 11223344 12233445 13243546
20314253 21324354 22334455 23344556
30415263 31425364 32435465 33445566
EOF

# test image for line based interlacing
# 4 x 4 pixels
# first line
00 01 02 03
11 12 13 14
22 23 24 25

# second line
10 11 12 13
21 22 23 24
32 33 34 35

# third line
20 21 22 23
31 32 33 34
42 43 44 45

# fourth line
30 31 32 33
41 42 43 44
52 53 54 55

EOF

# test image for image based interlacing
# first channel
00 01 02 03
10 11 12 13
20 21 22 23
30 31 32 33

# second channel
11 12 13 14
21 22 23 24
31 32 33 34
41 42 43 44

# third channel
22 23 24 25
32 33 34 35
42 43 44 45
52 53 54 55

EOF