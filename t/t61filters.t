#!perl -w
use strict;
use Imager qw(:handy);

# meant for testing the filters themselves
my $imbase = Imager->new;
$imbase->open(file=>'testout/t104.ppm') or die;
my $im_other = Imager->new(xsize=>150, ysize=>150);
$im_other->box(xmin=>30, ymin=>60, xmax=>120, ymax=>90, filled=>1);

print "1..26\n";

test($imbase, 1, {type=>'autolevels'}, 'testout/t61_autolev.ppm');

test($imbase, 3, {type=>'contrast', intensity=>0.5}, 
     'testout/t61_contrast.ppm');

# this one's kind of cool
test($imbase, 5, {type=>'conv', coef=>[ -0.5, 1, -0.5, ], },
     'testout/t61_conv.ppm');

test($imbase, 7, {type=>'gaussian', stddev=>5 },
     'testout/t61_gaussian.ppm');

test($imbase, 9, { type=>'gradgen', dist=>1,
                   xo=>[ 10,  10, 120 ],
                   yo=>[ 10, 140,  60 ],
                   colors=> [ NC('#FF0000'), NC('#FFFF00'), NC('#00FFFF') ]},
     'testout/t61_gradgen.ppm');

test($imbase, 11, {type=>'mosaic', size=>8}, 'testout/t61_mosaic.ppm');

test($imbase, 13, {type=>'hardinvert'}, 'testout/t61_hardinvert.ppm');

test($imbase, 15, {type=>'noise'}, 'testout/t61_noise.ppm');

test($imbase, 17, {type=>'radnoise'}, 'testout/t61_radnoise.ppm');

test($imbase, 19, {type=>'turbnoise'}, 'testout/t61_turbnoise.ppm');

test($imbase, 21, {type=>'bumpmap', bump=>$im_other, lightx=>30, lighty=>30},
     'testout/t61_bumpmap.ppm');

test($imbase, 23, {type=>'postlevels', levels=>3}, 'testout/t61_postlevels.ppm');

test($imbase, 25, {type=>'watermark', wmark=>$im_other },
     'testout/t61_watermark.ppm');

sub test {
  my ($in, $num, $params, $out) = @_;
  
  my $copy = $in->copy;
  if ($copy->filter(%$params)) {
    print "ok $num\n";
    if ($copy->write(file=>$out)) {
      print "ok ",$num+1,"\n";
    }
    else {
      print "not ok ",$num+1," # ",$copy->errstr,"\n";
    }
  }
  else {
    print "not ok $num # ",$copy->errstr,"\n";
    print "ok ",$num+1," # skipped\n";
  }
}
