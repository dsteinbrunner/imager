# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..6\n"; }
END {print "not ok 1\n" unless $loaded;}
use Imager qw(:all);

sub PI () { 3.14159265358979323846 }

$loaded = 1;
print "ok 1\n";

init_log("testout/t75aapolyaa.log",1);

$red   = Imager::Color->new(255,0,0);
$green = Imager::Color->new(0,255,0);
$blue  = Imager::Color->new(0,0,255);
$white = Imager::Color->new(255,255,255);


$img = Imager->new(xsize=>20, ysize=>10);
@data = translate(5.5,5,
		  rotate(0,
			 scale(5, 5,
			       get_polygon(n_gon => 5)
			      )
			)
		 );


my ($x, $y) = array_to_refpair(@data);
i_poly_aa($img->{IMG}, $x, $y, $white);




print "ok 2\n";

$img->write(file=>"testout/t75.ppm") or die $img->errstr;
print "ok 3\n";


$zoom = make_zoom($img, 8, \@data, $red);
$zoom->write(file=>"testout/t75zoom.ppm") or die $zoom->errstr;

print "ok 4\n";

$img = Imager->new(xsize=>300, ysize=>100);

for $n (0..55) {
  @data = translate(20+20*($n%14),18+20*int($n/14),
		    rotate(15*$n/PI,
			   scale(15, 15,
				 get_polygon('box')
				)
			  )
		   );
  my ($x, $y) = array_to_refpair(@data);
  i_poly_aa($img->{IMG}, $x, $y, NC(rand(255), rand(255), rand(255)));
}

$img->write(file=>"testout/t75big.ppm") or die $img->errstr;

print "ok 5\n";

$img = Imager->new(xsize => 200, ysize => 200);

$img -> polygon(color=>$blue,
		points => [
			   translate(100,100,
				     scale(10,10,
					   get_polygon('wavycircle', 32*4, sub { 8+0.5*cos(12*$_) })))
			  ],
	       ) or die $img->errstr();

$img->write(file=>"testout/t75wave.ppm") or die $img->errstr;

print "ok 6\n";

malloc_state();














sub get_polygon {
  my $name = shift;
  if (exists $primitives{$name}) {
    return @{$primitives{$name}};
  }

  if (exists $polygens{$name}) {
    return $polygens{$name}->(@_);
  }

  die "polygon spec: $name unknown\n";
}


sub make_zoom {
  my ($img, $sc, $polydata, $linecolor) = @_;

  # scale with nearest neighboor sampling
  my $timg = $img->scale(scalefactor=>$sc, qtype=>'preview');

  # draw the grid
  for($lx=0; $lx<$timg->getwidth(); $lx+=$sc) {
    $timg->line(color=>$green, x1=>$lx, x2=>$lx, y1=>0, y2=>$timg->getheight(), antialias=>0);
  }

  for($ly=0; $ly<$timg->getheight(); $ly+=$sc) {
    $timg->line(color=>$green, y1=>$ly, y2=>$ly, x1=>0, x2=>$timg->getwidth(), antialias=>0);
  }
  my @data = scale($sc, $sc, @$polydata);
  push(@data, $data[0]);
  my ($x, $y) = array_to_refpair(@data);

  $timg->polyline(color=>$linecolor, 'x'=>$x, 'y'=>$y, antialias=>0);
  return $timg;
}

# utility functions to manipulate point data

sub scale {
  my ($x, $y, @data) = @_;
  return map { [ $_->[0]*$x , $_->[1]*$y ] } @data;
}

sub translate {
  my ($x, $y, @data) = @_;
  map { [ $_->[0]+$x , $_->[1]+$y ] } @data;
}

sub rotate {
  my ($rad, @data) = @_;
  map { [ $_->[0]*cos($rad)+$_->[1]*sin($rad) , $_->[1]*cos($rad)-$_->[0]*sin($rad) ] } @data;
}

sub array_to_refpair {
  my (@x, @y);
  for (@_) {
    push(@x, $_->[0]);
    push(@y, $_->[1]);
  }
  return \@x, \@y;
}



BEGIN {
%primitives = (
	       box => [ [-0.5,-0.5], [0.5,-0.5], [0.5,0.5], [-0.5,0.5] ],
	       triangle => [ [0,0], [1,0], [1,1] ],
	      );

%polygens = (
	     wavycircle => sub {
	       my $numv = shift;
	       my $radfunc = shift;
	       my @radians = map { $_*2*PI/$numv } 0..$numv-1;
	       my @radius  = map { $radfunc->($_) } @radians;
	       map {
		 [ $radius[$_] * cos($radians[$_]), $radius[$_] * sin($radians[$_]) ]
	       } 0..$#radians;
	     },
	     n_gon => sub {
	       my $N = shift;
	       map {
		 [ cos($_*2*PI/$N), sin($_*2*PI/$N) ]
	       } 0..$N-1;
	     },
);
}
