package Imager;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS %formats $DEBUG %filters %DSOs $ERRSTR $fontstate %OPCODES $I2P $FORMATGUESS);
use IO::File;

use Imager::Color;
use Imager::Font;

@EXPORT_OK = qw(
		init
		init_log
		DSO_open
		DSO_close
		DSO_funclist
		DSO_call

		load_plugin
		unload_plugin

		i_list_formats
		i_has_format

		i_color_new
		i_color_set
		i_color_info

		i_img_empty
		i_img_empty_ch
		i_img_exorcise
		i_img_destroy

		i_img_info

		i_img_setmask
		i_img_getmask

		i_draw
		i_line_aa
		i_box
		i_box_filled
		i_arc
		i_circle_aa

		i_bezier_multi
		i_poly_aa
		i_poly_aa_cfill

		i_copyto
		i_rubthru
		i_scaleaxis
		i_scale_nn
		i_haar
		i_count_colors

		i_gaussian
		i_conv

		i_convert
		i_map

		i_img_diff

		i_init_fonts
		i_t1_new
		i_t1_destroy
		i_t1_set_aa
		i_t1_cp
		i_t1_text
		i_t1_bbox

		i_tt_set_aa
		i_tt_cp
		i_tt_text
		i_tt_bbox

		i_readjpeg_wiol
		i_writejpeg_wiol

		i_readtiff_wiol
		i_writetiff_wiol
		i_writetiff_wiol_faxable

		i_readpng_wiol
		i_writepng_wiol

		i_readgif
		i_readgif_wiol
		i_readgif_callback
		i_writegif
		i_writegifmc
		i_writegif_gen
		i_writegif_callback

		i_readpnm_wiol
		i_writeppm_wiol

		i_readraw_wiol
		i_writeraw_wiol

		i_contrast
		i_hardinvert
		i_noise
		i_bumpmap
		i_postlevels
		i_mosaic
		i_watermark

		malloc_state

		list_formats

		i_gifquant

		newfont
		newcolor
		newcolour
		NC
		NF
);

@EXPORT=qw(
	   init_log
	   i_list_formats
	   i_has_format
	   malloc_state
	   i_color_new

	   i_img_empty
	   i_img_empty_ch
	  );

%EXPORT_TAGS=
  (handy => [qw(
		newfont
		newcolor
		NF
		NC
	       )],
   all => [@EXPORT_OK],
   default => [qw(
		  load_plugin
		  unload_plugin
		 )]);

BEGIN {
  require Exporter;
  require DynaLoader;

  $VERSION = '0.39';
  @ISA = qw(Exporter DynaLoader);
  bootstrap Imager $VERSION;
}

BEGIN {
  i_init_fonts(); # Initialize font engines
  Imager::Font::__init();
  for(i_list_formats()) { $formats{$_}++; }

  if ($formats{'t1'}) {
    i_t1_set_aa(1);
  }

  if (!$formats{'t1'} and !$formats{'tt'} 
      && !$formats{'ft2'} && !$formats{'w32'}) {
    $fontstate='no font support';
  }

  %OPCODES=(Add=>[0],Sub=>[1],Mult=>[2],Div=>[3],Parm=>[4],'sin'=>[5],'cos'=>[6],'x'=>[4,0],'y'=>[4,1]);

  $DEBUG=0;

  # the members of the subhashes under %filters are:
  #  callseq - a list of the parameters to the underlying filter in the
  #            order they are passed
  #  callsub - a code ref that takes a named parameter list and calls the
  #            underlying filter
  #  defaults - a hash of default values
  #  names - defines names for value of given parameters so if the names 
  #          field is foo=> { bar=>1 }, and the user supplies "bar" as the
  #          foo parameter, the filter will receive 1 for the foo
  #          parameter
  $filters{contrast}={
		      callseq => ['image','intensity'],
		      callsub => sub { my %hsh=@_; i_contrast($hsh{image},$hsh{intensity}); } 
		     };

  $filters{noise} ={
		    callseq => ['image', 'amount', 'subtype'],
		    defaults => { amount=>3,subtype=>0 },
		    callsub => sub { my %hsh=@_; i_noise($hsh{image},$hsh{amount},$hsh{subtype}); }
		   };

  $filters{hardinvert} ={
			 callseq => ['image'],
			 defaults => { },
			 callsub => sub { my %hsh=@_; i_hardinvert($hsh{image}); }
			};

  $filters{autolevels} ={
			 callseq => ['image','lsat','usat','skew'],
			 defaults => { lsat=>0.1,usat=>0.1,skew=>0.0 },
			 callsub => sub { my %hsh=@_; i_autolevels($hsh{image},$hsh{lsat},$hsh{usat},$hsh{skew}); }
			};

  $filters{turbnoise} ={
			callseq => ['image'],
			defaults => { xo=>0.0,yo=>0.0,scale=>10.0 },
			callsub => sub { my %hsh=@_; i_turbnoise($hsh{image},$hsh{xo},$hsh{yo},$hsh{scale}); }
		       };

  $filters{radnoise} ={
		       callseq => ['image'],
		       defaults => { xo=>100,yo=>100,ascale=>17.0,rscale=>0.02 },
		       callsub => sub { my %hsh=@_; i_radnoise($hsh{image},$hsh{xo},$hsh{yo},$hsh{rscale},$hsh{ascale}); }
		      };

  $filters{conv} ={
		       callseq => ['image', 'coef'],
		       defaults => { },
		       callsub => sub { my %hsh=@_; i_conv($hsh{image},$hsh{coef}); }
		      };

  $filters{gradgen} ={
		       callseq => ['image', 'xo', 'yo', 'colors', 'dist'],
		       defaults => { },
		       callsub => sub { my %hsh=@_; i_gradgen($hsh{image}, $hsh{xo}, $hsh{yo}, $hsh{colors}, $hsh{dist}); }
		      };

  $filters{nearest_color} ={
			    callseq => ['image', 'xo', 'yo', 'colors', 'dist'],
			    defaults => { },
			    callsub => sub { my %hsh=@_; i_nearest_color($hsh{image}, $hsh{xo}, $hsh{yo}, $hsh{colors}, $hsh{dist}); }
			   };
  $filters{gaussian} = {
                        callseq => [ 'image', 'stddev' ],
                        defaults => { },
                        callsub => sub { my %hsh = @_; i_gaussian($hsh{image}, $hsh{stddev}); },
                       };
  $filters{mosaic} =
    {
     callseq => [ qw(image size) ],
     defaults => { size => 20 },
     callsub => sub { my %hsh = @_; i_mosaic($hsh{image}, $hsh{size}) },
    };
  $filters{bumpmap} =
    {
     callseq => [ qw(image bump elevation lightx lighty st) ],
     defaults => { elevation=>0, st=> 2 },
     callsub => sub {
       my %hsh = @_;
       i_bumpmap($hsh{image}, $hsh{bump}{IMG}, $hsh{elevation},
                 $hsh{lightx}, $hsh{lighty}, $hsh{st});
     },
    };
  $filters{bumpmap_complex} =
    {
     callseq => [ qw(image bump channel tx ty Lx Ly Lz cd cs n Ia Il Is) ],
     defaults => {
		  channel => 0,
		  tx => 0,
		  ty => 0,
		  Lx => 0.2,
		  Ly => 0.4,
		  Lz => -1.0,
		  cd => 1.0,
		  cs => 40,
		  n => 1.3,
		  Ia => Imager::Color->new(rgb=>[0,0,0]),
		  Il => Imager::Color->new(rgb=>[255,255,255]),
		  Is => Imager::Color->new(rgb=>[255,255,255]),
		 },
     callsub => sub {
       my %hsh = @_;
       i_bumpmap_complex($hsh{image}, $hsh{bump}{IMG}, $hsh{channel},
                 $hsh{tx}, $hsh{ty}, $hsh{Lx}, $hsh{Ly}, $hsh{Lz},
		 $hsh{cd}, $hsh{cs}, $hsh{n}, $hsh{Ia}, $hsh{Il},
		 $hsh{Is});
     },
    };
  $filters{postlevels} =
    {
     callseq  => [ qw(image levels) ],
     defaults => { levels => 10 },
     callsub  => sub { my %hsh = @_; i_postlevels($hsh{image}, $hsh{levels}); },
    };
  $filters{watermark} =
    {
     callseq  => [ qw(image wmark tx ty pixdiff) ],
     defaults => { pixdiff=>10, tx=>0, ty=>0 },
     callsub  => 
     sub { 
       my %hsh = @_; 
       i_watermark($hsh{image}, $hsh{wmark}{IMG}, $hsh{tx}, $hsh{ty}, 
                   $hsh{pixdiff}); 
     },
    };
  $filters{fountain} =
    {
     callseq  => [ qw(image xa ya xb yb ftype repeat combine super_sample ssample_param segments) ],
     names    => {
                  ftype => { linear         => 0,
                             bilinear       => 1,
                             radial         => 2,
                             radial_square  => 3,
                             revolution     => 4,
                             conical        => 5 },
                  repeat => { none      => 0,
                              sawtooth  => 1,
                              triangle  => 2,
                              saw_both  => 3,
                              tri_both  => 4,
                            },
                  super_sample => {
                                   none    => 0,
                                   grid    => 1,
                                   random  => 2,
                                   circle  => 3,
                                  },
                  combine => {
                              none      => 0,
                              normal    => 1,
                              multiply  => 2, mult => 2,
                              dissolve  => 3,
                              add       => 4,
                              subtract  => 5, 'sub' => 5,
                              diff      => 6,
                              lighten   => 7,
                              darken    => 8,
                              hue       => 9,
                              sat       => 10,
                              value     => 11,
                              color     => 12,
                             },
                 },
     defaults => { ftype => 0, repeat => 0, combine => 0,
                   super_sample => 0, ssample_param => 4,
                   segments=>[ 
                              [ 0, 0.5, 1,
                                Imager::Color->new(0,0,0),
                                Imager::Color->new(255, 255, 255),
                                0, 0,
                              ],
                             ],
                 },
     callsub  => 
     sub {
       my %hsh = @_;
       i_fountain($hsh{image}, $hsh{xa}, $hsh{ya}, $hsh{xb}, $hsh{yb},
                  $hsh{ftype}, $hsh{repeat}, $hsh{combine}, $hsh{super_sample},
                  $hsh{ssample_param}, $hsh{segments});
     },
    };
  $filters{unsharpmask} =
    {
     callseq => [ qw(image stddev scale) ],
     defaults => { stddev=>2.0, scale=>1.0 },
     callsub => 
     sub { 
       my %hsh = @_;
       i_unsharp_mask($hsh{image}, $hsh{stddev}, $hsh{scale});
     },
    };

  $FORMATGUESS=\&def_guess_type;
}

#
# Non methods
#

# initlize Imager
# NOTE: this might be moved to an import override later on

#sub import {
#  my $pack = shift;
#  (look through @_ for special tags, process, and remove them);   
#  use Data::Dumper;
#  print Dumper($pack);
#  print Dumper(@_);
#}

sub init {
  my %parms=(loglevel=>1,@_);
  if ($parms{'log'}) {
    init_log($parms{'log'},$parms{'loglevel'});
  }

#    if ($parms{T1LIB_CONFIG}) { $ENV{T1LIB_CONFIG}=$parms{T1LIB_CONFIG}; }
#    if ( $ENV{T1LIB_CONFIG} and ( $fontstate eq 'missing conf' )) {
#	i_init_fonts();
#	$fontstate='ok';
#    }
}

END {
  if ($DEBUG) {
    print "shutdown code\n";
    #	for(keys %instances) { $instances{$_}->DESTROY(); }
    malloc_state(); # how do decide if this should be used? -- store something from the import
    print "Imager exiting\n";
  }
}

# Load a filter plugin 

sub load_plugin {
  my ($filename)=@_;
  my $i;
  my ($DSO_handle,$str)=DSO_open($filename);
  if (!defined($DSO_handle)) { $Imager::ERRSTR="Couldn't load plugin '$filename'\n"; return undef; }
  my %funcs=DSO_funclist($DSO_handle);
  if ($DEBUG) { print "loading module $filename\n"; $i=0; for(keys %funcs) { printf("  %2d: %s\n",$i++,$_); } }
  $i=0;
  for(keys %funcs) { if ($filters{$_}) { $ERRSTR="filter '$_' already exists\n"; DSO_close($DSO_handle); return undef; } }

  $DSOs{$filename}=[$DSO_handle,\%funcs];

  for(keys %funcs) { 
    my $evstr="\$filters{'".$_."'}={".$funcs{$_}.'};';
    $DEBUG && print "eval string:\n",$evstr,"\n";
    eval $evstr;
    print $@ if $@;
  }
  return 1;
}

# Unload a plugin

sub unload_plugin {
  my ($filename)=@_;

  if (!$DSOs{$filename}) { $ERRSTR="plugin '$filename' not loaded."; return undef; }
  my ($DSO_handle,$funcref)=@{$DSOs{$filename}};
  for(keys %{$funcref}) {
    delete $filters{$_};
    $DEBUG && print "unloading: $_\n";
  }
  my $rc=DSO_close($DSO_handle);
  if (!defined($rc)) { $ERRSTR="unable to unload plugin '$filename'."; return undef; }
  return 1;
}

# take the results of i_error() and make a message out of it
sub _error_as_msg {
  return join(": ", map $_->[0], i_errors());
}

# this function tries to DWIM for color parameters
#  color objects are used as is
#  simple scalars are simply treated as single parameters to Imager::Color->new
#  hashrefs are treated as named argument lists to Imager::Color->new
#  arrayrefs are treated as list arguments to Imager::Color->new iff any
#    parameter is > 1
#  other arrayrefs are treated as list arguments to Imager::Color::Float

sub _color {
  my $arg = shift;
  my $result;

  if (ref $arg) {
    if (UNIVERSAL::isa($arg, "Imager::Color")
        || UNIVERSAL::isa($arg, "Imager::Color::Float")) {
      $result = $arg;
    }
    else {
      if ($arg =~ /^HASH\(/) {
        $result = Imager::Color->new(%$arg);
      }
      elsif ($arg =~ /^ARRAY\(/) {
        if (grep $_ > 1, @$arg) {
          $result = Imager::Color->new(@$arg);
        }
        else {
          $result = Imager::Color::Float->new(@$arg);
        }
      }
      else {
        $Imager::ERRSTR = "Not a color";
      }
    }
  }
  else {
    # assume Imager::Color::new knows how to handle it
    $result = Imager::Color->new($arg);
  }

  return $result;
}


#
# Methods to be called on objects.
#

# Create a new Imager object takes very few parameters.
# usually you call this method and then call open from
# the resulting object

sub new {
  my $class = shift;
  my $self ={};
  my %hsh=@_;
  bless $self,$class;
  $self->{IMG}=undef;    # Just to indicate what exists
  $self->{ERRSTR}=undef; #
  $self->{DEBUG}=$DEBUG;
  $self->{DEBUG} && print "Initialized Imager\n";
  if ($hsh{xsize} && $hsh{ysize}) { $self->img_set(%hsh); }
  return $self;
}

# Copy an entire image with no changes 
# - if an image has magic the copy of it will not be magical

sub copy {
  my $self = shift;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  my $newcopy=Imager->new();
  $newcopy->{IMG}=i_img_new();
  i_copy($newcopy->{IMG},$self->{IMG});
  return $newcopy;
}

# Paste a region

sub paste {
  my $self = shift;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  my %input=(left=>0, top=>0, @_);
  unless($input{img}) {
    $self->{ERRSTR}="no source image";
    return;
  }
  $input{left}=0 if $input{left} <= 0;
  $input{top}=0 if $input{top} <= 0;
  my $src=$input{img};
  my($r,$b)=i_img_info($src->{IMG});

  i_copyto($self->{IMG}, $src->{IMG}, 
	   0,0, $r, $b, $input{left}, $input{top});
  return $self;  # What should go here??
}

# Crop an image - i.e. return a new image that is smaller

sub crop {
  my $self=shift;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  my %hsh=(left=>0,right=>0,top=>0,bottom=>0,@_);

  my ($w,$h,$l,$r,$b,$t)=($self->getwidth(),$self->getheight(),
				@hsh{qw(left right bottom top)});
  $l=0 if not defined $l;
  $t=0 if not defined $t;

  $r||=$l+delete $hsh{'width'}    if defined $l and exists $hsh{'width'};
  $b||=$t+delete $hsh{'height'}   if defined $t and exists $hsh{'height'};
  $l||=$r-delete $hsh{'width'}    if defined $r and exists $hsh{'width'};
  $t||=$b-delete $hsh{'height'}   if defined $b and exists $hsh{'height'};

  $r=$self->getwidth if not defined $r;
  $b=$self->getheight if not defined $b;

  ($l,$r)=($r,$l) if $l>$r;
  ($t,$b)=($b,$t) if $t>$b;

  if ($hsh{'width'}) {
    $l=int(0.5+($w-$hsh{'width'})/2);
    $r=$l+$hsh{'width'};
  } else {
    $hsh{'width'}=$r-$l;
  }
  if ($hsh{'height'}) {
    $b=int(0.5+($h-$hsh{'height'})/2);
    $t=$h+$hsh{'height'};
  } else {
    $hsh{'height'}=$b-$t;
  }

#    print "l=$l, r=$r, h=$hsh{'width'}\n";
#    print "t=$t, b=$b, w=$hsh{'height'}\n";

  my $dst=Imager->new(xsize=>$hsh{'width'}, ysize=>$hsh{'height'}, channels=>$self->getchannels());

  i_copyto($dst->{IMG},$self->{IMG},$l,$t,$r,$b,0,0);
  return $dst;
}

# Sets an image to a certain size and channel number
# if there was previously data in the image it is discarded

sub img_set {
  my $self=shift;

  my %hsh=(xsize=>100, ysize=>100, channels=>3, bits=>8, type=>'direct', @_);

  if (defined($self->{IMG})) {
    # let IIM_DESTROY destroy it, it's possible this image is
    # referenced from a virtual image (like masked)
    #i_img_destroy($self->{IMG});
    undef($self->{IMG});
  }

  if ($hsh{type} eq 'paletted' || $hsh{type} eq 'pseudo') {
    $self->{IMG} = i_img_pal_new($hsh{xsize}, $hsh{ysize}, $hsh{channels},
                                 $hsh{maxcolors} || 256);
  }
  elsif ($hsh{bits} eq 'double') {
    $self->{IMG} = i_img_double_new($hsh{xsize}, $hsh{ysize}, $hsh{channels});
  }
  elsif ($hsh{bits} == 16) {
    $self->{IMG} = i_img_16_new($hsh{xsize}, $hsh{ysize}, $hsh{channels});
  }
  else {
    $self->{IMG}=Imager::ImgRaw::new($hsh{'xsize'}, $hsh{'ysize'},
                                     $hsh{'channels'});
  }
}

# created a masked version of the current image
sub masked {
  my $self = shift;

  $self or return undef;
  my %opts = (left    => 0, 
              top     => 0, 
              right   => $self->getwidth, 
              bottom  => $self->getheight,
              @_);
  my $mask = $opts{mask} ? $opts{mask}{IMG} : undef;

  my $result = Imager->new;
  $result->{IMG} = i_img_masked_new($self->{IMG}, $mask, $opts{left}, 
                                    $opts{top}, $opts{right} - $opts{left},
                                    $opts{bottom} - $opts{top});
  # keep references to the mask and base images so they don't
  # disappear on us
  $result->{DEPENDS} = [ $self->{IMG}, $mask ];

  $result;
}

# convert an RGB image into a paletted image
sub to_paletted {
  my $self = shift;
  my $opts;
  if (@_ != 1 && !ref $_[0]) {
    $opts = { @_ };
  }
  else {
    $opts = shift;
  }

  my $result = Imager->new;
  $result->{IMG} = i_img_to_pal($self->{IMG}, $opts);

  #print "Type ", i_img_type($result->{IMG}), "\n";

  $result->{IMG} or undef $result;

  return $result;
}

# convert a paletted (or any image) to an 8-bit/channel RGB images
sub to_rgb8 {
  my $self = shift;
  my $result;

  if ($self->{IMG}) {
    $result = Imager->new;
    $result->{IMG} = i_img_to_rgb($self->{IMG})
      or undef $result;
  }

  return $result;
}

sub addcolors {
  my $self = shift;
  my %opts = (colors=>[], @_);

  @{$opts{colors}} or return undef;

  $self->{IMG} and i_addcolors($self->{IMG}, @{$opts{colors}});
}

sub setcolors {
  my $self = shift;
  my %opts = (start=>0, colors=>[], @_);
  @{$opts{colors}} or return undef;

  $self->{IMG} and i_setcolors($self->{IMG}, $opts{start}, @{$opts{colors}});
}

sub getcolors {
  my $self = shift;
  my %opts = @_;
  if (!exists $opts{start} && !exists $opts{count}) {
    # get them all
    $opts{start} = 0;
    $opts{count} = $self->colorcount;
  }
  elsif (!exists $opts{count}) {
    $opts{count} = 1;
  }
  elsif (!exists $opts{start}) {
    $opts{start} = 0;
  }
  
  $self->{IMG} and 
    return i_getcolors($self->{IMG}, $opts{start}, $opts{count});
}

sub colorcount {
  i_colorcount($_[0]{IMG});
}

sub maxcolors {
  i_maxcolors($_[0]{IMG});
}

sub findcolor {
  my $self = shift;
  my %opts = @_;
  $opts{color} or return undef;

  $self->{IMG} and i_findcolor($self->{IMG}, $opts{color});
}

sub bits {
  my $self = shift;
  my $bits = $self->{IMG} && i_img_bits($self->{IMG});
  if ($bits && $bits == length(pack("d", 1)) * 8) {
    $bits = 'double';
  }
  $bits;
}

sub type {
  my $self = shift;
  if ($self->{IMG}) {
    return i_img_type($self->{IMG}) ? "paletted" : "direct";
  }
}

sub virtual {
  my $self = shift;
  $self->{IMG} and i_img_virtual($self->{IMG});
}

sub tags {
  my ($self, %opts) = @_;

  $self->{IMG} or return;

  if (defined $opts{name}) {
    my @result;
    my $start = 0;
    my $found;
    while (defined($found = i_tags_find($self->{IMG}, $opts{name}, $start))) {
      push @result, (i_tags_get($self->{IMG}, $found))[1];
      $start = $found+1;
    }
    return wantarray ? @result : $result[0];
  }
  elsif (defined $opts{code}) {
    my @result;
    my $start = 0;
    my $found;
    while (defined($found = i_tags_findn($self->{IMG}, $opts{code}, $start))) {
      push @result, (i_tags_get($self->{IMG}, $found))[1];
      $start = $found+1;
    }
    return @result;
  }
  else {
    if (wantarray) {
      return map { [ i_tags_get($self->{IMG}, $_) ] } 0.. i_tags_count($self->{IMG})-1;
    }
    else {
      return i_tags_count($self->{IMG});
    }
  }
}

sub addtag {
  my $self = shift;
  my %opts = @_;

  return -1 unless $self->{IMG};
  if ($opts{name}) {
    if (defined $opts{value}) {
      if ($opts{value} =~ /^\d+$/) {
        # add as a number
        return i_tags_addn($self->{IMG}, $opts{name}, 0, $opts{value});
      }
      else {
        return i_tags_add($self->{IMG}, $opts{name}, 0, $opts{value}, 0);
      }
    }
    elsif (defined $opts{data}) {
      # force addition as a string
      return i_tags_add($self->{IMG}, $opts{name}, 0, $opts{data}, 0);
    }
    else {
      $self->{ERRSTR} = "No value supplied";
      return undef;
    }
  }
  elsif ($opts{code}) {
    if (defined $opts{value}) {
      if ($opts{value} =~ /^\d+$/) {
        # add as a number
        return i_tags_addn($self->{IMG}, $opts{code}, 0, $opts{value});
      }
      else {
        return i_tags_add($self->{IMG}, $opts{code}, 0, $opts{value}, 0);
      }
    }
    elsif (defined $opts{data}) {
      # force addition as a string
      return i_tags_add($self->{IMG}, $opts{code}, 0, $opts{data}, 0);
    }
    else {
      $self->{ERRSTR} = "No value supplied";
      return undef;
    }
  }
  else {
    return undef;
  }
}

sub deltag {
  my $self = shift;
  my %opts = @_;

  return 0 unless $self->{IMG};

  if (defined $opts{'index'}) {
    return i_tags_delete($self->{IMG}, $opts{'index'});
  }
  elsif (defined $opts{name}) {
    return i_tags_delbyname($self->{IMG}, $opts{name});
  }
  elsif (defined $opts{code}) {
    return i_tags_delbycode($self->{IMG}, $opts{code});
  }
  else {
    $self->{ERRSTR} = "Need to supply index, name, or code parameter";
    return 0;
  }
}

my @needseekcb = qw/tiff/;
my %needseekcb = map { $_, $_ } @needseekcb;


sub _get_reader_io {
  my ($self, $input, $type) = @_;

  if ($input->{fd}) {
    return io_new_fd($input->{fd});
  }
  elsif ($input->{fh}) {
    my $fd = fileno($input->{fh});
    unless ($fd) {
      $self->_set_error("Handle in fh option not opened");
      return;
    }
    return io_new_fd($fd);
  }
  elsif ($input->{file}) {
    my $file = IO::File->new($input->{file}, "r");
    unless ($file) {
      $self->_set_error("Could not open $input->{file}: $!");
      return;
    }
    binmode $file;
    return (io_new_fd(fileno($file)), $file);
  }
  elsif ($input->{data}) {
    return io_new_buffer($input->{data});
  }
  elsif ($input->{callback} || $input->{readcb}) {
    if ($needseekcb{$type} && !$input->{seekcb}) {
      $self->_set_error("Format $type needs a seekcb parameter");
    }
    if ($input->{maxbuffer}) {
      return io_new_cb($input->{writecb},
                       $input->{callback} || $input->{readcb},
                       $input->{seekcb}, $input->{closecb},
                       $input->{maxbuffer});
    }
    else {
      return io_new_cb($input->{writecb},
                       $input->{callback} || $input->{readcb},
                       $input->{seekcb}, $input->{closecb});
    }
  }
  else {
    $self->_set_error("file/fd/fh/data/callback parameter missing");
    return;
  }
}

sub _get_writer_io {
  my ($self, $input, $type) = @_;

  if ($input->{fd}) {
    return io_new_fd($input->{fd});
  }
  elsif ($input->{fh}) {
    my $fd = fileno($input->{fh});
    unless ($fd) {
      $self->_set_error("Handle in fh option not opened");
      return;
    }
    return io_new_fd($fd);
  }
  elsif ($input->{file}) {
    my $fh = new IO::File($input->{file},"w+");
    unless ($fh) { 
      $self->_set_error("Could not open file $input->{file}: $!");
      return;
    }
    binmode($fh) or die;
    return (io_new_fd(fileno($fh)), $fh);
  }
  elsif ($input->{data}) {
    return io_new_bufchain();
  }
  elsif ($input->{callback} || $input->{writecb}) {
    if ($input->{maxbuffer}) {
      return io_new_cb($input->{callback} || $input->{writecb},
                       $input->{readcb},
                       $input->{seekcb}, $input->{closecb},
                       $input->{maxbuffer});
    }
    else {
      return io_new_cb($input->{callback} || $input->{writecb},
                       $input->{readcb},
                       $input->{seekcb}, $input->{closecb});
    }
  }
  else {
    $self->_set_error("file/fd/fh/data/callback parameter missing");
    return;
  }
}

# Read an image from file

sub read {
  my $self = shift;
  my %input=@_;

  if (defined($self->{IMG})) {
    # let IIM_DESTROY do the destruction, since the image may be
    # referenced from elsewhere
    #i_img_destroy($self->{IMG});
    undef($self->{IMG});
  }

  # FIXME: Find the format here if not specified
  # yes the code isn't here yet - next week maybe?
  # Next week?  Are you high or something?  That comment
  # has been there for half a year dude.
  # Look, i just work here, ok?

  if (!$input{'type'} and $input{file}) {
    $input{'type'}=$FORMATGUESS->($input{file});
  }
  unless ($input{'type'}) {
    $self->_set_error('type parameter missing and not possible to guess from extension'); 
    return undef;
  }
  if (!$formats{$input{'type'}}) {
    $self->{ERRSTR}='format not supported'; return undef;
  }

  my %iolready=(jpeg=>1, png=>1, tiff=>1, pnm=>1, raw=>1, bmp=>1, tga=>1, rgb=>1, gif=>1);

  if ($iolready{$input{'type'}}) {
    # Setup data source
    my ($IO, $fh) = $self->_get_reader_io(\%input, $input{'type'})
      or return;

    if ( $input{'type'} eq 'jpeg' ) {
      ($self->{IMG},$self->{IPTCRAW})=i_readjpeg_wiol( $IO );
      if ( !defined($self->{IMG}) ) {
	$self->{ERRSTR}='unable to read jpeg image'; return undef;
      }
      $self->{DEBUG} && print "loading a jpeg file\n";
      return $self;
    }

    if ( $input{'type'} eq 'tiff' ) {
      $self->{IMG}=i_readtiff_wiol( $IO, -1 ); # Fixme, check if that length parameter is ever needed
      if ( !defined($self->{IMG}) ) {
	$self->{ERRSTR}=$self->_error_as_msg(); return undef;
      }
      $self->{DEBUG} && print "loading a tiff file\n";
      return $self;
    }

    if ( $input{'type'} eq 'pnm' ) {
      $self->{IMG}=i_readpnm_wiol( $IO, -1 ); # Fixme, check if that length parameter is ever needed
      if ( !defined($self->{IMG}) ) {
	$self->{ERRSTR}='unable to read pnm image: '._error_as_msg(); return undef;
      }
      $self->{DEBUG} && print "loading a pnm file\n";
      return $self;
    }

    if ( $input{'type'} eq 'png' ) {
      $self->{IMG}=i_readpng_wiol( $IO, -1 ); # Fixme, check if that length parameter is ever needed
      if ( !defined($self->{IMG}) ) {
	$self->{ERRSTR}='unable to read png image';
	return undef;
      }
      $self->{DEBUG} && print "loading a png file\n";
    }

    if ( $input{'type'} eq 'bmp' ) {
      $self->{IMG}=i_readbmp_wiol( $IO );
      if ( !defined($self->{IMG}) ) {
	$self->{ERRSTR}=$self->_error_as_msg();
	return undef;
      }
      $self->{DEBUG} && print "loading a bmp file\n";
    }

    if ( $input{'type'} eq 'gif' ) {
      if ($input{colors} && !ref($input{colors})) {
	# must be a reference to a scalar that accepts the colour map
	$self->{ERRSTR} = "option 'colors' must be a scalar reference";
	return undef;
      }
      if ($input{colors}) {
        my $colors;
        ($self->{IMG}, $colors) =i_readgif_wiol( $IO );
        if ($colors) {
          ${ $input{colors} } = [ map { NC(@$_) } @$colors ];
        }
      }
      else {
        $self->{IMG} =i_readgif_wiol( $IO );
      }
      if ( !defined($self->{IMG}) ) {
	$self->{ERRSTR}=$self->_error_as_msg();
	return undef;
      }
      $self->{DEBUG} && print "loading a gif file\n";
    }

    if ( $input{'type'} eq 'tga' ) {
      $self->{IMG}=i_readtga_wiol( $IO, -1 ); # Fixme, check if that length parameter is ever needed
      if ( !defined($self->{IMG}) ) {
	$self->{ERRSTR}=$self->_error_as_msg();
	return undef;
      }
      $self->{DEBUG} && print "loading a tga file\n";
    }

    if ( $input{'type'} eq 'rgb' ) {
      $self->{IMG}=i_readrgb_wiol( $IO, -1 ); # Fixme, check if that length parameter is ever needed
      if ( !defined($self->{IMG}) ) {
	$self->{ERRSTR}=$self->_error_as_msg();
	return undef;
      }
      $self->{DEBUG} && print "loading a tga file\n";
    }


    if ( $input{'type'} eq 'raw' ) {
      my %params=(datachannels=>3,storechannels=>3,interleave=>1,%input);

      if ( !($params{xsize} && $params{ysize}) ) {
	$self->{ERRSTR}='missing xsize or ysize parameter for raw';
	return undef;
      }

      $self->{IMG} = i_readraw_wiol( $IO,
				     $params{xsize},
				     $params{ysize},
				     $params{datachannels},
				     $params{storechannels},
				     $params{interleave});
      if ( !defined($self->{IMG}) ) {
	$self->{ERRSTR}='unable to read raw image';
	return undef;
      }
      $self->{DEBUG} && print "loading a raw file\n";
    }

  } else {

    # Old code for reference while changing the new stuff

    if (!$input{'type'} and $input{file}) {
      $input{'type'}=$FORMATGUESS->($input{file});
    }

    if (!$input{'type'}) {
      $self->{ERRSTR}='type parameter missing and not possible to guess from extension'; return undef;
    }

    if (!$formats{$input{'type'}}) {
      $self->{ERRSTR}='format not supported';
      return undef;
    }

    my ($fh, $fd);
    if ($input{file}) {
      $fh = new IO::File($input{file},"r");
      if (!defined $fh) {
	$self->{ERRSTR}='Could not open file';
	return undef;
      }
      binmode($fh);
      $fd = $fh->fileno();
    }

    if ($input{fd}) {
      $fd=$input{fd};
    }

    if ( $input{'type'} eq 'gif' ) {
      my $colors;
      if ($input{colors} && !ref($input{colors})) {
	# must be a reference to a scalar that accepts the colour map
	$self->{ERRSTR} = "option 'colors' must be a scalar reference";
	return undef;
      }
      if (exists $input{data}) {
	if ($input{colors}) {
	  ($self->{IMG}, $colors) = i_readgif_scalar($input{data});
	} else {
	  $self->{IMG}=i_readgif_scalar($input{data});
	}
      } else {
	if ($input{colors}) {
	  ($self->{IMG}, $colors) = i_readgif( $fd );
	} else {
	  $self->{IMG} = i_readgif( $fd )
	}
      }
      if ($colors) {
	# we may or may not change i_readgif to return blessed objects...
	${ $input{colors} } = [ map { NC(@$_) } @$colors ];
      }
      if ( !defined($self->{IMG}) ) {
	$self->{ERRSTR}= 'reading GIF:'._error_as_msg();
	return undef;
      }
      $self->{DEBUG} && print "loading a gif file\n";
    }
  }
  return $self;
}

# Write an image to file
sub write {
  my $self = shift;
  my %input=(jpegquality=>75, 
	     gifquant=>'mc', 
	     lmdither=>6.0, 
	     lmfixed=>[],
	     idstring=>"",
	     compress=>1,
	     wierdpack=>0,
	     fax_fine=>1, @_);
  my $rc;

  my %iolready=( tiff=>1, raw=>1, png=>1, pnm=>1, bmp=>1, jpeg=>1, tga=>1, 
                 gif=>1 ); # this will be SO MUCH BETTER once they are all in there

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  if (!$input{'type'} and $input{file}) { 
    $input{'type'}=$FORMATGUESS->($input{file});
  }
  if (!$input{'type'}) { 
    $self->{ERRSTR}='type parameter missing and not possible to guess from extension';
    return undef;
  }

  if (!$formats{$input{'type'}}) { $self->{ERRSTR}='format not supported'; return undef; }

  my ($IO, $fh) = $self->_get_writer_io(\%input, $input{'type'})
    or return undef;

  # this conditional is probably obsolete
  if ($iolready{$input{'type'}}) {

    if ($input{'type'} eq 'tiff') {
      if (defined $input{class} && $input{class} eq 'fax') {
	if (!i_writetiff_wiol_faxable($self->{IMG}, $IO, $input{fax_fine})) {
	  $self->{ERRSTR}='Could not write to buffer';
	  return undef;
	}
      } else {
	if (!i_writetiff_wiol($self->{IMG}, $IO)) {
	  $self->{ERRSTR}='Could not write to buffer';
	  return undef;
	}
      }
    } elsif ( $input{'type'} eq 'pnm' ) {
      if ( ! i_writeppm_wiol($self->{IMG},$IO) ) {
	$self->{ERRSTR}='unable to write pnm image';
	return undef;
      }
      $self->{DEBUG} && print "writing a pnm file\n";
    } elsif ( $input{'type'} eq 'raw' ) {
      if ( !i_writeraw_wiol($self->{IMG},$IO) ) {
	$self->{ERRSTR}='unable to write raw image';
	return undef;
      }
      $self->{DEBUG} && print "writing a raw file\n";
    } elsif ( $input{'type'} eq 'png' ) {
      if ( !i_writepng_wiol($self->{IMG}, $IO) ) {
	$self->{ERRSTR}='unable to write png image';
	return undef;
      }
      $self->{DEBUG} && print "writing a png file\n";
    } elsif ( $input{'type'} eq 'jpeg' ) {
      if ( !i_writejpeg_wiol($self->{IMG}, $IO, $input{jpegquality})) {
        $self->{ERRSTR} = $self->_error_as_msg();
	return undef;
      }
      $self->{DEBUG} && print "writing a jpeg file\n";
    } elsif ( $input{'type'} eq 'bmp' ) {
      if ( !i_writebmp_wiol($self->{IMG}, $IO) ) {
	$self->{ERRSTR}='unable to write bmp image';
	return undef;
      }
      $self->{DEBUG} && print "writing a bmp file\n";
    } elsif ( $input{'type'} eq 'tga' ) {

      if ( !i_writetga_wiol($self->{IMG}, $IO, $input{wierdpack}, $input{compress}, $input{idstring}) ) {
	$self->{ERRSTR}=$self->_error_as_msg();
	return undef;
      }
      $self->{DEBUG} && print "writing a tga file\n";
    } elsif ( $input{'type'} eq 'gif' ) {
      # compatibility with the old interfaces
      if ($input{gifquant} eq 'lm') {
        $input{make_colors} = 'addi';
        $input{translate} = 'perturb';
        $input{perturb} = $input{lmdither};
      } elsif ($input{gifquant} eq 'gen') {
        # just pass options through
      } else {
        $input{make_colors} = 'webmap'; # ignored
        $input{translate} = 'giflib';
      }
      $rc = i_writegif_wiol($IO, \%input, $self->{IMG});
    }

    if (exists $input{'data'}) {
      my $data = io_slurp($IO);
      if (!$data) {
	$self->{ERRSTR}='Could not slurp from buffer';
	return undef;
      }
      ${$input{data}} = $data;
    }
    return $self;
  }

  return $self;
}

sub write_multi {
  my ($class, $opts, @images) = @_;

  if (!$opts->{'type'} && $opts->{'file'}) {
    $opts->{'type'} = $FORMATGUESS->($opts->{'file'});
  }
  unless ($opts->{'type'}) {
    $class->_set_error('type parameter missing and not possible to guess from extension');
    return;
  }
  # translate to ImgRaw
  if (grep !UNIVERSAL::isa($_, 'Imager') || !$_->{IMG}, @images) {
    $class->_set_error('Usage: Imager->write_multi({ options }, @images)');
    return 0;
  }
  my @work = map $_->{IMG}, @images;
  my ($IO, $file) = $class->_get_writer_io($opts, $opts->{'type'})
    or return undef;
  if ($opts->{'type'} eq 'gif') {
    my $gif_delays = $opts->{gif_delays};
    local $opts->{gif_delays} = $gif_delays;
    if ($opts->{gif_delays} && !ref $opts->{gif_delays}) {
      # assume the caller wants the same delay for each frame
      $opts->{gif_delays} = [ ($gif_delays) x @images ];
    }
    my $res = i_writegif_wiol($IO, $opts, @work);
    $res or $class->_set_error($class->_error_as_msg());
    return $res;
  }
  elsif ($opts->{'type'} eq 'tiff') {
    my $res;
    $opts->{fax_fine} = 1 unless exists $opts->{fax_fine};
    if ($opts->{'class'} && $opts->{'class'} eq 'fax') {
      $res = i_writetiff_multi_wiol_faxable($IO, $opts->{fax_fine}, @work);
    }
    else {
      $res = i_writetiff_multi_wiol($IO, @work);
    }
    $res or $class->_set_error($class->_error_as_msg());
    return $res;
  }
  else {
    $ERRSTR = "Sorry, write_multi doesn't support $opts->{'type'} yet";
    return 0;
  }
}

# read multiple images from a file
sub read_multi {
  my ($class, %opts) = @_;

  if ($opts{file} && !exists $opts{'type'}) {
    # guess the type 
    my $type = $FORMATGUESS->($opts{file});
    $opts{'type'} = $type;
  }
  unless ($opts{'type'}) {
    $ERRSTR = "No type parameter supplied and it couldn't be guessed";
    return;
  }

  my ($IO, $file) = $class->_get_reader_io(\%opts, $opts{'type'})
    or return;
  if ($opts{'type'} eq 'gif') {
    my @imgs;
    @imgs = i_readgif_multi_wiol($IO);
    if (@imgs) {
      return map { 
        bless { IMG=>$_, DEBUG=>$DEBUG, ERRSTR=>undef }, 'Imager' 
      } @imgs;
    }
    else {
      $ERRSTR = _error_as_msg();
      return;
    }
  }
  elsif ($opts{'type'} eq 'tiff') {
    my @imgs = i_readtiff_multi_wiol($IO, -1);
    if (@imgs) {
      return map { 
        bless { IMG=>$_, DEBUG=>$DEBUG, ERRSTR=>undef }, 'Imager' 
      } @imgs;
    }
    else {
      $ERRSTR = _error_as_msg();
      return;
    }
  }

  $ERRSTR = "Cannot read multiple images from $opts{'type'} files";
  return;
}

# Destroy an Imager object

sub DESTROY {
  my $self=shift;
  #    delete $instances{$self};
  if (defined($self->{IMG})) {
    # the following is now handled by the XS DESTROY method for
    # Imager::ImgRaw object
    # Re-enabling this will break virtual images
    # tested for in t/t020masked.t
    # i_img_destroy($self->{IMG});
    undef($self->{IMG});
  } else {
#    print "Destroy Called on an empty image!\n"; # why did I put this here??
  }
}

# Perform an inplace filter of an image
# that is the image will be overwritten with the data

sub filter {
  my $self=shift;
  my %input=@_;
  my %hsh;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  if (!$input{'type'}) { $self->{ERRSTR}='type parameter missing'; return undef; }

  if ( (grep { $_ eq $input{'type'} } keys %filters) != 1) {
    $self->{ERRSTR}='type parameter not matching any filter'; return undef;
  }

  if ($filters{$input{'type'}}{names}) {
    my $names = $filters{$input{'type'}}{names};
    for my $name (keys %$names) {
      if (defined $input{$name} && exists $names->{$name}{$input{$name}}) {
        $input{$name} = $names->{$name}{$input{$name}};
      }
    }
  }
  if (defined($filters{$input{'type'}}{defaults})) {
    %hsh=('image',$self->{IMG},%{$filters{$input{'type'}}{defaults}},%input);
  } else {
    %hsh=('image',$self->{IMG},%input);
  }

  my @cs=@{$filters{$input{'type'}}{callseq}};

  for(@cs) {
    if (!defined($hsh{$_})) {
      $self->{ERRSTR}="missing parameter '$_' for filter ".$input{'type'}; return undef;
    }
  }

  &{$filters{$input{'type'}}{callsub}}(%hsh);

  my @b=keys %hsh;

  $self->{DEBUG} && print "callseq is: @cs\n";
  $self->{DEBUG} && print "matching callseq is: @b\n";

  return $self;
}

# Scale an image to requested size and return the scaled version

sub scale {
  my $self=shift;
  my %opts=(scalefactor=>0.5,'type'=>'max',qtype=>'normal',@_);
  my $img = Imager->new();
  my $tmp = Imager->new();

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  if ($opts{xpixels} and $opts{ypixels} and $opts{'type'}) {
    my ($xpix,$ypix)=( $opts{xpixels}/$self->getwidth() , $opts{ypixels}/$self->getheight() );
    if ($opts{'type'} eq 'min') { $opts{scalefactor}=min($xpix,$ypix); }
    if ($opts{'type'} eq 'max') { $opts{scalefactor}=max($xpix,$ypix); }
  } elsif ($opts{xpixels}) { $opts{scalefactor}=$opts{xpixels}/$self->getwidth(); }
  elsif ($opts{ypixels}) { $opts{scalefactor}=$opts{ypixels}/$self->getheight(); }

  if ($opts{qtype} eq 'normal') {
    $tmp->{IMG}=i_scaleaxis($self->{IMG},$opts{scalefactor},0);
    if ( !defined($tmp->{IMG}) ) { $self->{ERRSTR}='unable to scale image'; return undef; }
    $img->{IMG}=i_scaleaxis($tmp->{IMG},$opts{scalefactor},1);
    if ( !defined($img->{IMG}) ) { $self->{ERRSTR}='unable to scale image'; return undef; }
    return $img;
  }
  if ($opts{'qtype'} eq 'preview') {
    $img->{IMG}=i_scale_nn($self->{IMG},$opts{'scalefactor'},$opts{'scalefactor'}); 
    if ( !defined($img->{IMG}) ) { $self->{ERRSTR}='unable to scale image'; return undef; }
    return $img;
  }
  $self->{ERRSTR}='scale: invalid value for qtype'; return undef;
}

# Scales only along the X axis

sub scaleX {
  my $self=shift;
  my %opts=(scalefactor=>0.5,@_);

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  my $img = Imager->new();

  if ($opts{pixels}) { $opts{scalefactor}=$opts{pixels}/$self->getwidth(); }

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  $img->{IMG}=i_scaleaxis($self->{IMG},$opts{scalefactor},0);

  if ( !defined($img->{IMG}) ) { $self->{ERRSTR}='unable to scale image'; return undef; }
  return $img;
}

# Scales only along the Y axis

sub scaleY {
  my $self=shift;
  my %opts=(scalefactor=>0.5,@_);

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  my $img = Imager->new();

  if ($opts{pixels}) { $opts{scalefactor}=$opts{pixels}/$self->getheight(); }

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  $img->{IMG}=i_scaleaxis($self->{IMG},$opts{scalefactor},1);

  if ( !defined($img->{IMG}) ) { $self->{ERRSTR}='unable to scale image'; return undef; }
  return $img;
}


# Transform returns a spatial transformation of the input image
# this moves pixels to a new location in the returned image.
# NOTE - should make a utility function to check transforms for
# stack overruns

sub transform {
  my $self=shift;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  my %opts=@_;
  my (@op,@ropx,@ropy,$iop,$or,@parm,$expr,@xt,@yt,@pt,$numre);

#  print Dumper(\%opts);
#  xopcopdes

  if ( $opts{'xexpr'} and $opts{'yexpr'} ) {
    if (!$I2P) {
      eval ("use Affix::Infix2Postfix;");
      print $@;
      if ( $@ ) {
	$self->{ERRSTR}='transform: expr given and Affix::Infix2Postfix is not avaliable.'; 
	return undef;
      }
      $I2P=Affix::Infix2Postfix->new('ops'=>[{op=>'+',trans=>'Add'},
					     {op=>'-',trans=>'Sub'},
					     {op=>'*',trans=>'Mult'},
					     {op=>'/',trans=>'Div'},
					     {op=>'-','type'=>'unary',trans=>'u-'},
					     {op=>'**'},
					     {op=>'func','type'=>'unary'}],
				     'grouping'=>[qw( \( \) )],
				     'func'=>[qw( sin cos )],
				     'vars'=>[qw( x y )]
				    );
    }

    @xt=$I2P->translate($opts{'xexpr'});
    @yt=$I2P->translate($opts{'yexpr'});

    $numre=$I2P->{'numre'};
    @pt=(0,0);

    for(@xt) { if (/$numre/) { push(@pt,$_); push(@{$opts{'xopcodes'}},'Parm',$#pt); } else { push(@{$opts{'xopcodes'}},$_); } }
    for(@yt) { if (/$numre/) { push(@pt,$_); push(@{$opts{'yopcodes'}},'Parm',$#pt); } else { push(@{$opts{'yopcodes'}},$_); } }
    @{$opts{'parm'}}=@pt;
  }

#  print Dumper(\%opts);

  if ( !exists $opts{'xopcodes'} or @{$opts{'xopcodes'}}==0) {
    $self->{ERRSTR}='transform: no xopcodes given.';
    return undef;
  }

  @op=@{$opts{'xopcodes'}};
  for $iop (@op) { 
    if (!defined ($OPCODES{$iop}) and ($iop !~ /^\d+$/) ) {
      $self->{ERRSTR}="transform: illegal opcode '$_'.";
      return undef;
    }
    push(@ropx,(exists $OPCODES{$iop}) ? @{$OPCODES{$iop}} : $iop );
  }


# yopcopdes

  if ( !exists $opts{'yopcodes'} or @{$opts{'yopcodes'}}==0) {
    $self->{ERRSTR}='transform: no yopcodes given.';
    return undef;
  }

  @op=@{$opts{'yopcodes'}};
  for $iop (@op) { 
    if (!defined ($OPCODES{$iop}) and ($iop !~ /^\d+$/) ) {
      $self->{ERRSTR}="transform: illegal opcode '$_'.";
      return undef;
    }
    push(@ropy,(exists $OPCODES{$iop}) ? @{$OPCODES{$iop}} : $iop );
  }

#parameters

  if ( !exists $opts{'parm'}) {
    $self->{ERRSTR}='transform: no parameter arg given.';
    return undef;
  }

#  print Dumper(\@ropx);
#  print Dumper(\@ropy);
#  print Dumper(\@ropy);

  my $img = Imager->new();
  $img->{IMG}=i_transform($self->{IMG},\@ropx,\@ropy,$opts{'parm'});
  if ( !defined($img->{IMG}) ) { $self->{ERRSTR}='transform: failed'; return undef; }
  return $img;
}


sub transform2 {
  my ($opts, @imgs) = @_;
  
  require "Imager/Expr.pm";

  $opts->{variables} = [ qw(x y) ];
  my ($width, $height) = @{$opts}{qw(width height)};
  if (@imgs) {
    $width ||= $imgs[0]->getwidth();
    $height ||= $imgs[0]->getheight();
    my $img_num = 1;
    for my $img (@imgs) {
      $opts->{constants}{"w$img_num"} = $img->getwidth();
      $opts->{constants}{"h$img_num"} = $img->getheight();
      $opts->{constants}{"cx$img_num"} = $img->getwidth()/2;
      $opts->{constants}{"cy$img_num"} = $img->getheight()/2;
      ++$img_num;
    }
  }
  if ($width) {
    $opts->{constants}{w} = $width;
    $opts->{constants}{cx} = $width/2;
  }
  else {
    $Imager::ERRSTR = "No width supplied";
    return;
  }
  if ($height) {
    $opts->{constants}{h} = $height;
    $opts->{constants}{cy} = $height/2;
  }
  else {
    $Imager::ERRSTR = "No height supplied";
    return;
  }
  my $code = Imager::Expr->new($opts);
  if (!$code) {
    $Imager::ERRSTR = Imager::Expr::error();
    return;
  }

  my $img = Imager->new();
  $img->{IMG} = i_transform2($opts->{width}, $opts->{height}, $code->code(),
                             $code->nregs(), $code->cregs(),
                             [ map { $_->{IMG} } @imgs ]);
  if (!defined $img->{IMG}) {
    $Imager::ERRSTR = Imager->_error_as_msg();
    return;
  }

  return $img;
}

sub rubthrough {
  my $self=shift;
  my %opts=(tx=>0,ty=>0,@_);

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  unless ($opts{src} && $opts{src}->{IMG}) { $self->{ERRSTR}='empty input image for source'; return undef; }

  unless (i_rubthru($self->{IMG}, $opts{src}->{IMG}, $opts{tx},$opts{ty})) {
    $self->{ERRSTR} = $self->_error_as_msg();
    return undef;
  }
  return $self;
}


sub flip {
  my $self  = shift;
  my %opts  = @_;
  my %xlate = (h=>0, v=>1, hv=>2, vh=>2);
  my $dir;
  return () unless defined $opts{'dir'} and defined $xlate{$opts{'dir'}};
  $dir = $xlate{$opts{'dir'}};
  return $self if i_flipxy($self->{IMG}, $dir);
  return ();
}

sub rotate {
  my $self = shift;
  my %opts = @_;
  if (defined $opts{right}) {
    my $degrees = $opts{right};
    if ($degrees < 0) {
      $degrees += 360 * int(((-$degrees)+360)/360);
    }
    $degrees = $degrees % 360;
    if ($degrees == 0) {
      return $self->copy();
    }
    elsif ($degrees == 90 || $degrees == 180 || $degrees == 270) {
      my $result = Imager->new();
      if ($result->{IMG} = i_rotate90($self->{IMG}, $degrees)) {
        return $result;
      }
      else {
        $self->{ERRSTR} = $self->_error_as_msg();
        return undef;
      }
    }
    else {
      $self->{ERRSTR} = "Parameter 'right' must be a multiple of 90 degrees";
      return undef;
    }
  }
  elsif (defined $opts{radians} || defined $opts{degrees}) {
    my $amount = $opts{radians} || $opts{degrees} * 3.1415926535 / 180;

    my $result = Imager->new;
    if ($result->{IMG} = i_rotate_exact($self->{IMG}, $amount)) {
      return $result;
    }
    else {
      $self->{ERRSTR} = $self->_error_as_msg();
      return undef;
    }
  }
  else {
    $self->{ERRSTR} = "Only the 'right' parameter is available";
    return undef;
  }
}

sub matrix_transform {
  my $self = shift;
  my %opts = @_;

  if ($opts{matrix}) {
    my $xsize = $opts{xsize} || $self->getwidth;
    my $ysize = $opts{ysize} || $self->getheight;

    my $result = Imager->new;
    $result->{IMG} = i_matrix_transform($self->{IMG}, $xsize, $ysize, 
                                        $opts{matrix})
      or return undef;

    return $result;
  }
  else {
    $self->{ERRSTR} = "matrix parameter required";
    return undef;
  }
}

# blame Leolo :)
*yatf = \&matrix_transform;

# These two are supported for legacy code only

sub i_color_new {
  return Imager::Color->new(@_);
}

sub i_color_set {
  return Imager::Color::set(@_);
}

# Draws a box between the specified corner points.
sub box {
  my $self=shift;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  my $dflcl=i_color_new(255,255,255,255);
  my %opts=(color=>$dflcl,xmin=>0,ymin=>0,xmax=>$self->getwidth()-1,ymax=>$self->getheight()-1,@_);

  if (exists $opts{'box'}) { 
    $opts{'xmin'} = min($opts{'box'}->[0],$opts{'box'}->[2]);
    $opts{'xmax'} = max($opts{'box'}->[0],$opts{'box'}->[2]);
    $opts{'ymin'} = min($opts{'box'}->[1],$opts{'box'}->[3]);
    $opts{'ymax'} = max($opts{'box'}->[1],$opts{'box'}->[3]);
  }

  if ($opts{filled}) { 
    my $color = _color($opts{'color'});
    unless ($color) { 
      $self->{ERRSTR} = $Imager::ERRSTR; 
      return; 
    }
    i_box_filled($self->{IMG},$opts{xmin},$opts{ymin},$opts{xmax},
                 $opts{ymax}, $color); 
  }
  elsif ($opts{fill}) {
    unless (UNIVERSAL::isa($opts{fill}, 'Imager::Fill')) {
      # assume it's a hash ref
      require 'Imager/Fill.pm';
      unless ($opts{fill} = Imager::Fill->new(%{$opts{fill}})) {
        $self->{ERRSTR} = $Imager::ERRSTR;
        return undef;
      }
    }
    i_box_cfill($self->{IMG},$opts{xmin},$opts{ymin},$opts{xmax},
                $opts{ymax},$opts{fill}{fill});
  }
  else {
    my $color = _color($opts{'color'});
    unless ($color) { 
      $self->{ERRSTR} = $Imager::ERRSTR;
      return;
    }
    i_box($self->{IMG},$opts{xmin},$opts{ymin},$opts{xmax},$opts{ymax},
          $color);
  }
  return $self;
}

# Draws an arc - this routine SUCKS and is buggy - it sometimes doesn't work when the arc is a convex polygon

sub arc {
  my $self=shift;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  my $dflcl=i_color_new(255,255,255,255);
  my %opts=(color=>$dflcl,
	    'r'=>min($self->getwidth(),$self->getheight())/3,
	    'x'=>$self->getwidth()/2,
	    'y'=>$self->getheight()/2,
	    'd1'=>0, 'd2'=>361, @_);
  if ($opts{fill}) {
    unless (UNIVERSAL::isa($opts{fill}, 'Imager::Fill')) {
      # assume it's a hash ref
      require 'Imager/Fill.pm';
      unless ($opts{fill} = Imager::Fill->new(%{$opts{fill}})) {
        $self->{ERRSTR} = $Imager::ERRSTR;
        return;
      }
    }
    i_arc_cfill($self->{IMG},$opts{'x'},$opts{'y'},$opts{'r'},$opts{'d1'},
                $opts{'d2'}, $opts{fill}{fill});
  }
  else {
    my $color = _color($opts{'color'});
    unless ($color) { 
      $self->{ERRSTR} = $Imager::ERRSTR; 
      return; 
    }
    if ($opts{d1} == 0 && $opts{d2} == 361 && $opts{aa}) {
      i_circle_aa($self->{IMG}, $opts{'x'}, $opts{'y'}, $opts{'r'}, 
                  $color);
    }
    else {
      if ($opts{'d1'} <= $opts{'d2'}) { 
        i_arc($self->{IMG},$opts{'x'},$opts{'y'},$opts{'r'},
              $opts{'d1'}, $opts{'d2'}, $color); 
      }
      else {
        i_arc($self->{IMG},$opts{'x'},$opts{'y'},$opts{'r'},
              $opts{'d1'}, 361,         $color);
        i_arc($self->{IMG},$opts{'x'},$opts{'y'},$opts{'r'},
              0,           $opts{'d2'}, $color); 
      }
    }
  }

  return $self;
}

# Draws a line from one point to (but not including) the destination point

sub line {
  my $self=shift;
  my $dflcl=i_color_new(0,0,0,0);
  my %opts=(color=>$dflcl,@_);
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  unless (exists $opts{x1} and exists $opts{y1}) { $self->{ERRSTR}='missing begining coord'; return undef; }
  unless (exists $opts{x2} and exists $opts{y2}) { $self->{ERRSTR}='missing ending coord'; return undef; }

  my $color = _color($opts{'color'});
  unless ($color) { 
    $self->{ERRSTR} = $Imager::ERRSTR; 
    return; 
  }
  $opts{antialias} = $opts{aa} if defined $opts{aa};
  if ($opts{antialias}) {
    i_line_aa($self->{IMG},$opts{x1}, $opts{y1}, $opts{x2}, $opts{y2}, 
              $color);
  } else {
    i_draw($self->{IMG},$opts{x1}, $opts{y1}, $opts{x2}, $opts{y2}, 
           $color);
  }
  return $self;
}

# Draws a line between an ordered set of points - It more or less just transforms this
# into a list of lines.

sub polyline {
  my $self=shift;
  my ($pt,$ls,@points);
  my $dflcl=i_color_new(0,0,0,0);
  my %opts=(color=>$dflcl,@_);

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  if (exists($opts{points})) { @points=@{$opts{points}}; }
  if (!exists($opts{points}) and exists($opts{'x'}) and exists($opts{'y'}) ) {
    @points=map { [ $opts{'x'}->[$_],$opts{'y'}->[$_] ] } (0..(scalar @{$opts{'x'}}-1));
    }

#  print Dumper(\@points);

  my $color = _color($opts{'color'});
  unless ($color) { 
    $self->{ERRSTR} = $Imager::ERRSTR; 
    return; 
  }
  $opts{antialias} = $opts{aa} if defined $opts{aa};
  if ($opts{antialias}) {
    for $pt(@points) {
      if (defined($ls)) { 
        i_line_aa($self->{IMG},$ls->[0],$ls->[1],$pt->[0],$pt->[1],$color);
      }
      $ls=$pt;
    }
  } else {
    for $pt(@points) {
      if (defined($ls)) { 
        i_draw($self->{IMG},$ls->[0],$ls->[1],$pt->[0],$pt->[1],$color);
      }
      $ls=$pt;
    }
  }
  return $self;
}

sub polygon {
  my $self = shift;
  my ($pt,$ls,@points);
  my $dflcl = i_color_new(0,0,0,0);
  my %opts = (color=>$dflcl, @_);

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  if (exists($opts{points})) {
    $opts{'x'} = [ map { $_->[0] } @{$opts{points}} ];
    $opts{'y'} = [ map { $_->[1] } @{$opts{points}} ];
  }

  if (!exists $opts{'x'} or !exists $opts{'y'})  {
    $self->{ERRSTR} = 'no points array, or x and y arrays.'; return undef;
  }

  if ($opts{'fill'}) {
    unless (UNIVERSAL::isa($opts{'fill'}, 'Imager::Fill')) {
      # assume it's a hash ref
      require 'Imager/Fill.pm';
      unless ($opts{'fill'} = Imager::Fill->new(%{$opts{'fill'}})) {
        $self->{ERRSTR} = $Imager::ERRSTR;
        return undef;
      }
    }
    i_poly_aa_cfill($self->{IMG}, $opts{'x'}, $opts{'y'}, 
                    $opts{'fill'}{'fill'});
  }
  else {
    my $color = _color($opts{'color'});
    unless ($color) { 
      $self->{ERRSTR} = $Imager::ERRSTR; 
      return; 
    }
    i_poly_aa($self->{IMG}, $opts{'x'}, $opts{'y'}, $color);
  }

  return $self;
}


# this the multipoint bezier curve
# this is here more for testing that actual usage since
# this is not a good algorithm.  Usually the curve would be
# broken into smaller segments and each done individually.

sub polybezier {
  my $self=shift;
  my ($pt,$ls,@points);
  my $dflcl=i_color_new(0,0,0,0);
  my %opts=(color=>$dflcl,@_);

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  if (exists $opts{points}) {
    $opts{'x'}=map { $_->[0]; } @{$opts{'points'}};
    $opts{'y'}=map { $_->[1]; } @{$opts{'points'}};
  }

  unless ( @{$opts{'x'}} and @{$opts{'x'}} == @{$opts{'y'}} ) {
    $self->{ERRSTR}='Missing or invalid points.';
    return;
  }

  my $color = _color($opts{'color'});
  unless ($color) { 
    $self->{ERRSTR} = $Imager::ERRSTR; 
    return; 
  }
  i_bezier_multi($self->{IMG},$opts{'x'},$opts{'y'},$color);
  return $self;
}

sub flood_fill {
  my $self = shift;
  my %opts = ( color=>Imager::Color->new(255, 255, 255), @_ );

  unless (exists $opts{'x'} && exists $opts{'y'}) {
    $self->{ERRSTR} = "missing seed x and y parameters";
    return undef;
  }

  if ($opts{fill}) {
    unless (UNIVERSAL::isa($opts{fill}, 'Imager::Fill')) {
      # assume it's a hash ref
      require 'Imager/Fill.pm';
      unless ($opts{fill} = Imager::Fill->new(%{$opts{fill}})) {
        $self->{ERRSTR} = $Imager::ERRSTR;
        return;
      }
    }
    i_flood_cfill($self->{IMG}, $opts{'x'}, $opts{'y'}, $opts{fill}{fill});
  }
  else {
    my $color = _color($opts{'color'});
    unless ($color) { 
      $self->{ERRSTR} = $Imager::ERRSTR; 
      return; 
    }
    i_flood_fill($self->{IMG}, $opts{'x'}, $opts{'y'}, $color);
  }

  $self;
}

# make an identity matrix of the given size
sub _identity {
  my ($size) = @_;

  my $matrix = [ map { [ (0) x $size ] } 1..$size ];
  for my $c (0 .. ($size-1)) {
    $matrix->[$c][$c] = 1;
  }
  return $matrix;
}

# general function to convert an image
sub convert {
  my ($self, %opts) = @_;
  my $matrix;

  # the user can either specify a matrix or preset
  # the matrix overrides the preset
  if (!exists($opts{matrix})) {
    unless (exists($opts{preset})) {
      $self->{ERRSTR} = "convert() needs a matrix or preset";
      return;
    }
    else {
      if ($opts{preset} eq 'gray' || $opts{preset} eq 'grey') {
	# convert to greyscale, keeping the alpha channel if any
	if ($self->getchannels == 3) {
	  $matrix = [ [ 0.222, 0.707, 0.071 ] ];
	}
	elsif ($self->getchannels == 4) {
	  # preserve the alpha channel
	  $matrix = [ [ 0.222, 0.707, 0.071, 0 ],
		      [ 0,     0,     0,     1 ] ];
	}
	else {
	  # an identity
	  $matrix = _identity($self->getchannels);
	}
      }
      elsif ($opts{preset} eq 'noalpha') {
	# strip the alpha channel
	if ($self->getchannels == 2 or $self->getchannels == 4) {
	  $matrix = _identity($self->getchannels);
	  pop(@$matrix); # lose the alpha entry
	}
	else {
	  $matrix = _identity($self->getchannels);
	}
      }
      elsif ($opts{preset} eq 'red' || $opts{preset} eq 'channel0') {
	# extract channel 0
	$matrix = [ [ 1 ] ];
      }
      elsif ($opts{preset} eq 'green' || $opts{preset} eq 'channel1') {
	$matrix = [ [ 0, 1 ] ];
      }
      elsif ($opts{preset} eq 'blue' || $opts{preset} eq 'channel2') {
	$matrix = [ [ 0, 0, 1 ] ];
      }
      elsif ($opts{preset} eq 'alpha') {
	if ($self->getchannels == 2 or $self->getchannels == 4) {
	  $matrix = [ [ (0) x ($self->getchannels-1), 1 ] ];
	}
	else {
	  # the alpha is just 1 <shrug>
	  $matrix = [ [ (0) x $self->getchannels, 1 ] ];
	}
      }
      elsif ($opts{preset} eq 'rgb') {
	if ($self->getchannels == 1) {
	  $matrix = [ [ 1 ], [ 1 ], [ 1 ] ];
	}
	elsif ($self->getchannels == 2) {
	  # preserve the alpha channel
	  $matrix = [ [ 1, 0 ], [ 1, 0 ], [ 1, 0 ], [ 0, 1 ] ];
	}
	else {
	  $matrix = _identity($self->getchannels);
	}
      }
      elsif ($opts{preset} eq 'addalpha') {
	if ($self->getchannels == 1) {
	  $matrix = _identity(2);
	}
	elsif ($self->getchannels == 3) {
	  $matrix = _identity(4);
	}
	else {
	  $matrix = _identity($self->getchannels);
	}
      }
      else {
	$self->{ERRSTR} = "Unknown convert preset $opts{preset}";
	return undef;
      }
    }
  }
  else {
    $matrix = $opts{matrix};
  }

  my $new = Imager->new();
  $new->{IMG} = i_img_new();
  unless (i_convert($new->{IMG}, $self->{IMG}, $matrix)) {
    # most likely a bad matrix
    $self->{ERRSTR} = _error_as_msg();
    return undef;
  }
  return $new;
}


# general function to map an image through lookup tables

sub map {
  my ($self, %opts) = @_;
  my @chlist = qw( red green blue alpha );

  if (!exists($opts{'maps'})) {
    # make maps from channel maps
    my $chnum;
    for $chnum (0..$#chlist) {
      if (exists $opts{$chlist[$chnum]}) {
	$opts{'maps'}[$chnum] = $opts{$chlist[$chnum]};
      } elsif (exists $opts{'all'}) {
	$opts{'maps'}[$chnum] = $opts{'all'};
      }
    }
  }
  if ($opts{'maps'} and $self->{IMG}) {
    i_map($self->{IMG}, $opts{'maps'} );
  }
  return $self;
}

# destructive border - image is shrunk by one pixel all around

sub border {
  my ($self,%opts)=@_;
  my($tx,$ty)=($self->getwidth()-1,$self->getheight()-1);
  $self->polyline('x'=>[0,$tx,$tx,0,0],'y'=>[0,0,$ty,$ty,0],%opts);
}


# Get the width of an image

sub getwidth {
  my $self = shift;
  if (!defined($self->{IMG})) { $self->{ERRSTR} = 'image is empty'; return undef; }
  return (i_img_info($self->{IMG}))[0];
}

# Get the height of an image

sub getheight {
  my $self = shift;
  if (!defined($self->{IMG})) { $self->{ERRSTR} = 'image is empty'; return undef; }
  return (i_img_info($self->{IMG}))[1];
}

# Get number of channels in an image

sub getchannels {
  my $self = shift;
  if (!defined($self->{IMG})) { $self->{ERRSTR} = 'image is empty'; return undef; }
  return i_img_getchannels($self->{IMG});
}

# Get channel mask

sub getmask {
  my $self = shift;
  if (!defined($self->{IMG})) { $self->{ERRSTR} = 'image is empty'; return undef; }
  return i_img_getmask($self->{IMG});
}

# Set channel mask

sub setmask {
  my $self = shift;
  my %opts = @_;
  if (!defined($self->{IMG})) { $self->{ERRSTR} = 'image is empty'; return undef; }
  i_img_setmask( $self->{IMG} , $opts{mask} );
}

# Get number of colors in an image

sub getcolorcount {
  my $self=shift;
  my %opts=('maxcolors'=>2**30,@_);
  if (!defined($self->{IMG})) { $self->{ERRSTR}='image is empty'; return undef; }
  my $rc=i_count_colors($self->{IMG},$opts{'maxcolors'});
  return ($rc==-1? undef : $rc);
}

# draw string to an image

sub string {
  my $self = shift;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  my %input=('x'=>0, 'y'=>0, @_);
  $input{string}||=$input{text};

  unless(exists $input{string}) {
    $self->{ERRSTR}="missing required parameter 'string'";
    return;
  }

  unless($input{font}) {
    $self->{ERRSTR}="missing required parameter 'font'";
    return;
  }

  unless ($input{font}->draw(image=>$self, %input)) {
    $self->{ERRSTR} = $self->_error_as_msg();
    return;
  }

  return $self;
}

# Shortcuts that can be exported

sub newcolor { Imager::Color->new(@_); }
sub newfont  { Imager::Font->new(@_); }

*NC=*newcolour=*newcolor;
*NF=*newfont;

*open=\&read;
*circle=\&arc;


#### Utility routines

sub errstr { 
  ref $_[0] ? $_[0]->{ERRSTR} : $ERRSTR
}

sub _set_error {
  my ($self, $msg) = @_;

  if (ref $self) {
    $self->{ERRSTR} = $msg;
  }
  else {
    $ERRSTR = $msg;
  }
}

# Default guess for the type of an image from extension

sub def_guess_type {
  my $name=lc(shift);
  my $ext;
  $ext=($name =~ m/\.([^\.]+)$/)[0];
  return 'tiff' if ($ext =~ m/^tiff?$/);
  return 'jpeg' if ($ext =~ m/^jpe?g$/);
  return 'pnm'  if ($ext =~ m/^p[pgb]m$/);
  return 'png'  if ($ext eq "png");
  return 'bmp'  if ($ext eq "bmp" || $ext eq "dib");
  return 'tga'  if ($ext eq "tga");
  return 'rgb'  if ($ext eq "rgb");
  return 'gif'  if ($ext eq "gif");
  return 'raw'  if ($ext eq "raw");
  return ();
}

# get the minimum of a list

sub min {
  my $mx=shift;
  for(@_) { if ($_<$mx) { $mx=$_; }}
  return $mx;
}

# get the maximum of a list

sub max {
  my $mx=shift;
  for(@_) { if ($_>$mx) { $mx=$_; }}
  return $mx;
}

# string stuff for iptc headers

sub clean {
  my($str)=$_[0];
  $str = substr($str,3);
  $str =~ s/[\n\r]//g;
  $str =~ s/\s+/ /g;
  $str =~ s/^\s//;
  $str =~ s/\s$//;
  return $str;
}

# A little hack to parse iptc headers.

sub parseiptc {
  my $self=shift;
  my(@sar,$item,@ar);
  my($caption,$photogr,$headln,$credit);

  my $str=$self->{IPTCRAW};

  #print $str;

  @ar=split(/8BIM/,$str);

  my $i=0;
  foreach (@ar) {
    if (/^\004\004/) {
      @sar=split(/\034\002/);
      foreach $item (@sar) {
	if ($item =~ m/^x/) {
	  $caption=&clean($item);
	  $i++;
	}
	if ($item =~ m/^P/) {
	  $photogr=&clean($item);
	  $i++;
	}
	if ($item =~ m/^i/) {
	  $headln=&clean($item);
	  $i++;
	}
	if ($item =~ m/^n/) {
	  $credit=&clean($item);
	  $i++;
	}
      }
    }
  }
  return (caption=>$caption,photogr=>$photogr,headln=>$headln,credit=>$credit);
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Imager - Perl extension for Generating 24 bit Images

=head1 SYNOPSIS

  use Imager;

  $img = Imager->new();
  $img->open(file=>'image.ppm',type=>'pnm')
    || print "failed: ",$img->{ERRSTR},"\n";
  $scaled=$img->scale(xpixels=>400,ypixels=>400);
  $scaled->write(file=>'sc_image.ppm',type=>'pnm')
    || print "failed: ",$scaled->{ERRSTR},"\n";

=head1 DESCRIPTION

Imager is a module for creating and altering images - It is not meant
as a replacement or a competitor to ImageMagick or GD. Both are
excellent packages and well supported.

=head2 Overview of documentation

=over

=item Imager

This document - Table of Contents, Example and Overview

=item Imager::ImageTypes

Direct type/virtual images, RGB(A)/paletted images, 8/16/double
bits/channel, image tags, and channel masks.

=item Imager::Files

IO interaction, reading/writing images, format specific tags.

=item Imager::Draw

Drawing Primitives, lines boxes, circles, flood fill.

=item Imager::Color

Color specification.

=item Imager::Font

General font rendering.

=item Imager::Transformations

Copying, scaling, cropping, flipping, blending, pasting, [convert and map.]

=item Imager::Engines

transform2 and matrix_transform.

=item Imager::Filters

Filters, sharpen, blur, noise, convolve etc. and plugins.

=item Imager::Expr

Expressions for evaluation engine used by transform2().

=item Imager::Matrix2d

Helper class for affine transformations.

=item Imager::Fountain

Helper for making gradient profiles.

=back








Almost all functions take the parameters in the hash fashion.
Example:

  $img->open(file=>'lena.png',type=>'png');

or just:

  $img->open(file=>'lena.png');

=head2 Basic concept

An Image object is created with C<$img = Imager-E<gt>new()> Should
this fail for some reason an explanation can be found in
C<$Imager::ERRSTR> usually error messages are stored in
C<$img-E<gt>{ERRSTR}>, but since no object is created this is the only
way to give back errors.  C<$Imager::ERRSTR> is also used to report
all errors not directly associated with an image object. Examples:

  $img=Imager->new(); # This is an empty image (size is 0 by 0)
  $img->open(file=>'lena.png',type=>'png'); # initializes from file

or if you want to create an empty image:

  $img=Imager->new(xsize=>400,ysize=>300,channels=>4);

This example creates a completely black image of width 400 and
height 300 and 4 channels.

If you have an existing image, use img_set() to change it's dimensions
- this will destroy any existing image data:

  $img->img_set(xsize=>500, ysize=>500, channels=>4);

To create paletted images, set the 'type' parameter to 'paletted':

  $img = Imager->new(xsize=>200, ysize=>200, channels=>3, type=>'paletted');

which creates an image with a maxiumum of 256 colors, which you can
change by supplying the C<maxcolors> parameter.

You can create a new paletted image from an existing image using the
to_paletted() method:

 $palimg = $img->to_paletted(\%opts)

where %opts contains the options specified under L<Quantization options>.

You can convert a paletted image (or any image) to an 8-bit/channel
RGB image with:

  $rgbimg = $img->to_rgb8;

Warning: if you draw on a paletted image with colors that aren't in
the palette, the image will be internally converted to a normal image.

For improved color precision you can use the bits parameter to specify
16 bit per channel:

  $img = Imager->new(xsize=>200, ysize=>200, channels=>3, bits=>16);

or for even more precision:

  $img = Imager->new(xsize=>200, ysize=>200, channels=>3, bits=>'double');

to get an image that uses a double for each channel.

Note that as of this writing all functions should work on images with
more than 8-bits/channel, but many will only work at only
8-bit/channel precision.

Currently only 8-bit, 16-bit, and double per channel image types are
available, this may change later.

Color objects are created by calling the Imager::Color->new()
method:

  $color = Imager::Color->new($red, $green, $blue);
  $color = Imager::Color->new($red, $green, $blue, $alpha);
  $color = Imager::Color->new("#C0C0FF"); # html color specification

This object can then be passed to functions that require a color parameter.

Coordinates in Imager have the origin in the upper left corner.  The
horizontal coordinate increases to the right and the vertical
downwards.

=head2 Reading and writing images

You can read and write a variety of images formats, assuming you have
the appropriate libraries, and images can be read or written to/from
files, file handles, file descriptors, scalars, or through callbacks.

To see which image formats Imager is compiled to support the following
code snippet is sufficient:

  use Imager;
  print join " ", keys %Imager::formats;

This will include some other information identifying libraries rather
than file formats.

Reading writing to and from files is simple, use the C<read()>
method to read an image:

  my $img = Imager->new;
  $img->read(file=>$filename, type=>$type)
    or die "Cannot read $filename: ", $img->errstr;

and the C<write()> method to write an image:

  $img->write(file=>$filename, type=>$type)
    or die "Cannot write $filename: ", $img->errstr;

If the I<filename> includes an extension that Imager recognizes, then
you don't need the I<type>, but you may want to provide one anyway.
Imager currently does not check the files magic to determine the
format.  It is possible to override the method for determining the 
filetype from the filename.  If the data is given in another form than
a file name a 

When you read an image, Imager may set some tags, possibly including
information about the spatial resolution, textual information, and
animation information.  See L</Tags> for specifics.

When reading or writing you can specify one of a variety of sources or
targets:

=over

=item file

The C<file> parameter is the name of the image file to be written to
or read from.  If Imager recognizes the extension of the file you do
not need to supply a C<type>.

=item fh

C<fh> is a file handle, typically either returned from
C<<IO::File->new()>>, or a glob from an C<open> call.  You should call
C<binmode> on the handle before passing it to Imager.

=item fd

C<fd> is a file descriptor.  You can get this by calling the
C<fileno()> function on a file handle, or by using one of the standard
file descriptor numbers.

=item data

When reading data, C<data> is a scalar containing the image file data,
when writing, C<data> is a reference to the scalar to save the image
file data too.  For GIF images you will need giflib 4 or higher, and
you may need to patch giflib to use this option for writing.

=item callback

Imager will make calls back to your supplied coderefs to read, write
and seek from/to/through the image file.

When reading from a file you can use either C<callback> or C<readcb>
to supply the read callback, and when writing C<callback> or
C<writecb> to supply the write callback.

When writing you can also supply the C<maxbuffer> option to set the
maximum amount of data that will be buffered before your write
callback is called.  Note: the amount of data supplied to your
callback can be smaller or larger than this size.

The read callback is called with 2 parameters, the minimum amount of
data required, and the maximum amount that Imager will store in it's C
level buffer.  You may want to return the minimum if you have a slow
data source, or the maximum if you have a fast source and want to
prevent many calls to your perl callback.  The read data should be
returned as a scalar.

Your write callback takes exactly one parameter, a scalar containing
the data to be written.  Return true for success.

The seek callback takes 2 parameters, a I<POSITION>, and a I<WHENCE>,
defined in the same way as perl's seek function.

You can also supply a C<closecb> which is called with no parameters
when there is no more data to be written.  This could be used to flush
buffered data.

=back

C<$img-E<gt>read()> generally takes two parameters, 'file' and 'type'.
If the type of the file can be determined from the suffix of the file
it can be omitted.  Format dependant parameters are: For images of
type 'raw' two extra parameters are needed 'xsize' and 'ysize', if the
'channel' parameter is omitted for type 'raw' it is assumed to be 3.
gif and png images might have a palette are converted to truecolor bit
when read.  Alpha channel is preserved for png images irregardless of
them being in RGB or gray colorspace.  Similarly grayscale jpegs are
one channel images after reading them.  For jpeg images the iptc
header information (stored in the APP13 header) is avaliable to some
degree. You can get the raw header with C<$img-E<gt>{IPTCRAW}>, but
you can also retrieve the most basic information with
C<%hsh=$img-E<gt>parseiptc()> as always patches are welcome.  pnm has no 
extra options. Examples:

  $img = Imager->new();
  $img->read(file=>"cover.jpg") or die $img->errstr; # gets type from name

  $img = Imager->new();
  { local(*FH,$/); open(FH,"file.gif") or die $!; $a=<FH>; }
  $img->read(data=>$a,type=>'gif') or die $img->errstr;

The second example shows how to read an image from a scalar, this is
usefull if your data originates from somewhere else than a filesystem
such as a database over a DBI connection.

When writing to a tiff image file you can also specify the 'class'
parameter, which can currently take a single value, "fax".  If class
is set to fax then a tiff image which should be suitable for faxing
will be written.  For the best results start with a grayscale image.
By default the image is written at fine resolution you can override
this by setting the "fax_fine" parameter to 0.

If you are reading from a gif image file, you can supply a 'colors'
parameter which must be a reference to a scalar.  The referenced
scalar will receive an array reference which contains the colors, each
represented as an Imager::Color object.

If you already have an open file handle, for example a socket or a
pipe, you can specify the 'fd' parameter instead of supplying a
filename.  Please be aware that you need to use fileno() to retrieve
the file descriptor for the file:

  $img->read(fd=>fileno(FILE), type=>'gif') or die $img->errstr;

For writing using the 'fd' option you will probably want to set $| for
that descriptor, since the writes to the file descriptor bypass Perl's
(or the C libraries) buffering.  Setting $| should avoid out of order
output.  For example a common idiom when writing a CGI script is:

  # the $| _must_ come before you send the content-type
  $| = 1;
  print "Content-Type: image/jpeg\n\n";
  $img->write(fd=>fileno(STDOUT), type=>'jpeg') or die $img->errstr;

*Note that load() is now an alias for read but will be removed later*

C<$img-E<gt>write> has the same interface as C<read()>.  The earlier
comments on C<read()> for autodetecting filetypes apply.  For jpegs
quality can be adjusted via the 'jpegquality' parameter (0-100).  The
number of colorplanes in gifs are set with 'gifplanes' and should be
between 1 (2 color) and 8 (256 colors).  It is also possible to choose
between two quantizing methods with the parameter 'gifquant'. If set
to mc it uses the mediancut algorithm from either giflibrary. If set
to lm it uses a local means algorithm. It is then possible to give
some extra settings. lmdither is the dither deviation amount in pixels
(manhattan distance).  lmfixed can be an array ref who holds an array
of Imager::Color objects.  Note that the local means algorithm needs
much more cpu time but also gives considerable better results than the
median cut algorithm.

When storing targa images rle compression can be activated with the
'compress' parameter, the 'idstring' parameter can be used to set the
targa comment field and the 'wierdpack' option can be used to use the
15 and 16 bit targa formats for rgb and rgba data.  The 15 bit format
has 5 of each red, green and blue.  The 16 bit format in addition
allows 1 bit of alpha.  The most significant bits are used for each
channel.

Currently just for gif files, you can specify various options for the
conversion from Imager's internal RGB format to the target's indexed
file format.  If you set the gifquant option to 'gen', you can use the
options specified under L<Quantization options>.

To see what Imager is compiled to support the following code snippet
is sufficient:

  use Imager;
  print "@{[keys %Imager::formats]}";

When reading raw images you need to supply the width and height of the
image in the xsize and ysize options:

  $img->read(file=>'foo.raw', xsize=>100, ysize=>100)
    or die "Cannot read raw image\n";

If your input file has more channels than you want, or (as is common),
junk in the fourth channel, you can use the datachannels and
storechannels options to control the number of channels in your input
file and the resulting channels in your image.  For example, if your
input image uses 32-bits per pixel with red, green, blue and junk
values for each pixel you could do:

  $img->read(file=>'foo.raw', xsize=>100, ysize=>100, datachannels=>4,
	     storechannels=>3)
    or die "Cannot read raw image\n";

Normally the raw image is expected to have the value for channel 1
immediately following channel 0 and channel 2 immediately following
channel 1 for each pixel.  If your input image has all the channel 0
values for the first line of the image, followed by all the channel 1
values for the first line and so on, you can use the interleave option:

  $img->read(file=>'foo.raw', xsize=100, ysize=>100, interleave=>1)
    or die "Cannot read raw image\n";

=head2 Multi-image files

Currently just for gif files, you can create files that contain more
than one image.

To do this:

  Imager->write_multi(\%opts, @images)

Where %opts describes 4 possible types of outputs:

=over 5

=item type

This is C<gif> for gif animations.

=item callback

A code reference which is called with a single parameter, the data to
be written.  You can also specify $opts{maxbuffer} which is the
maximum amount of data buffered.  Note that there can be larger writes
than this if the file library writes larger blocks.  A smaller value
maybe useful for writing to a socket for incremental display.

=item fd

The file descriptor to save the images to.

=item file

The name of the file to write to.

%opts may also include the keys from L<Gif options> and L<Quantization
options>.

=back

You must also specify the file format using the 'type' option.

The current aim is to support other multiple image formats in the
future, such as TIFF, and to support reading multiple images from a
single file.

A simple example:

    my @images;
    # ... code to put images in @images
    Imager->write_multi({type=>'gif',
			 file=>'anim.gif',
			 gif_delays=>[ (10) x @images ] },
			@images)
    or die "Oh dear!";

You can read multi-image files (currently only GIF files) using the
read_multi() method:

  my @imgs = Imager->read_multi(file=>'foo.gif')
    or die "Cannot read images: ",Imager->errstr;

The possible parameters for read_multi() are:

=over

=item file

The name of the file to read in.

=item fh

A filehandle to read in.  This can be the name of a filehandle, but it
will need the package name, no attempt is currently made to adjust
this to the caller's package.

=item fd

The numeric file descriptor of an open file (or socket).

=item callback

A function to be called to read in data, eg. reading a blob from a
database incrementally.

=item data

The data of the input file in memory.

=item type

The type of file.  If the file is parameter is given and provides
enough information to guess the type, then this parameter is optional.

=back

Note: you cannot use the callback or data parameter with giflib
versions before 4.0.

When reading from a GIF file with read_multi() the images are returned
as paletted images.

=head2 Gif options

These options can be specified when calling write_multi() for gif
files, when writing a single image with the gifquant option set to
'gen', or for direct calls to i_writegif_gen and i_writegif_callback.

Note that some viewers will ignore some of these options
(gif_user_input in particular).

=over 4

=item gif_each_palette

Each image in the gif file has it's own palette if this is non-zero.
All but the first image has a local colour table (the first uses the
global colour table.

=item interlace

The images are written interlaced if this is non-zero.

=item gif_delays

A reference to an array containing the delays between images, in 1/100
seconds.

If you want the same delay for every frame you can simply set this to
the delay in 1/100 seconds.

=item gif_user_input

A reference to an array contains user input flags.  If the given flag
is non-zero the image viewer should wait for input before displaying
the next image.

=item gif_disposal

A reference to an array of image disposal methods.  These define what
should be done to the image before displaying the next one.  These are
integers, where 0 means unspecified, 1 means the image should be left
in place, 2 means restore to background colour and 3 means restore to
the previous value.

=item gif_tran_color

A reference to an Imager::Color object, which is the colour to use for
the palette entry used to represent transparency in the palette.  You
need to set the transp option (see L<Quantization options>) for this
value to be used.

=item gif_positions

A reference to an array of references to arrays which represent screen
positions for each image.

=item gif_loop_count

If this is non-zero the Netscape loop extension block is generated,
which makes the animation of the images repeat.

This is currently unimplemented due to some limitations in giflib.

=item gif_eliminate_unused

If this is true, when you write a paletted image any unused colors
will be eliminated from its palette.  This is set by default.

=back

=head2 Quantization options

These options can be specified when calling write_multi() for gif
files, when writing a single image with the gifquant option set to
'gen', or for direct calls to i_writegif_gen and i_writegif_callback.

=over 4

=item colors

A arrayref of colors that are fixed.  Note that some color generators
will ignore this.

=item transp

The type of transparency processing to perform for images with an
alpha channel where the output format does not have a proper alpha
channel (eg. gif).  This can be any of:

=over 4

=item none

No transparency processing is done. (default)

=item threshold

Pixels more transparent that tr_threshold are rendered as transparent.

=item errdiff

An error diffusion dither is done on the alpha channel.  Note that
this is independent of the translation performed on the colour
channels, so some combinations may cause undesired artifacts.

=item ordered

The ordered dither specified by tr_orddith is performed on the alpha
channel.

=back

This will only be used if the image has an alpha channel, and if there
is space in the palette for a transparency colour.

=item tr_threshold

The highest alpha value at which a pixel will be made transparent when
transp is 'threshold'. (0-255, default 127)

=item tr_errdiff

The type of error diffusion to perform on the alpha channel when
transp is 'errdiff'.  This can be any defined error diffusion type
except for custom (see errdiff below).

=item tr_orddith

The type of ordered dither to perform on the alpha channel when transp
is 'ordered'.  Possible values are:

=over 4

=item random

A semi-random map is used.  The map is the same each time.

=item dot8

8x8 dot dither.

=item dot4

4x4 dot dither

=item hline

horizontal line dither.

=item vline

vertical line dither.

=item "/line"

=item slashline

diagonal line dither

=item '\line'

=item backline

diagonal line dither

=item tiny

dot matrix dither (currently the default).  This is probably the best
for displays (like web pages).

=item custom

A custom dither matrix is used - see tr_map

=back

=item tr_map

When tr_orddith is custom this defines an 8 x 8 matrix of integers
representing the transparency threshold for pixels corresponding to
each position.  This should be a 64 element array where the first 8
entries correspond to the first row of the matrix.  Values should be
betweern 0 and 255.

=item make_colors

Defines how the quantization engine will build the palette(s).
Currently this is ignored if 'translate' is 'giflib', but that may
change.  Possible values are:

=over 4

=item none

Only colors supplied in 'colors' are used.

=item webmap

The web color map is used (need url here.)

=item addi

The original code for generating the color map (Addi's code) is used.

=back

Other methods may be added in the future.

=item colors

A arrayref containing Imager::Color objects, which represents the
starting set of colors to use in translating the images.  webmap will
ignore this.  The final colors used are copied back into this array
(which is expanded if necessary.)

=item max_colors

The maximum number of colors to use in the image.

=item translate

The method used to translate the RGB values in the source image into
the colors selected by make_colors.  Note that make_colors is ignored
whene translate is 'giflib'.

Possible values are:

=over 4

=item giflib

The giflib native quantization function is used.

=item closest

The closest color available is used.

=item perturb

The pixel color is modified by perturb, and the closest color is chosen.

=item errdiff

An error diffusion dither is performed.

=back

It's possible other transate values will be added.

=item errdiff

The type of error diffusion dither to perform.  These values (except
for custom) can also be used in tr_errdif.

=over 4

=item floyd

Floyd-Steinberg dither

=item jarvis

Jarvis, Judice and Ninke dither

=item stucki

Stucki dither

=item custom

Custom.  If you use this you must also set errdiff_width,
errdiff_height and errdiff_map.

=back

=item errdiff_width

=item errdiff_height

=item errdiff_orig

=item errdiff_map

When translate is 'errdiff' and errdiff is 'custom' these define a
custom error diffusion map.  errdiff_width and errdiff_height define
the size of the map in the arrayref in errdiff_map.  errdiff_orig is
an integer which indicates the current pixel position in the top row
of the map.

=item perturb

When translate is 'perturb' this is the magnitude of the random bias
applied to each channel of the pixel before it is looked up in the
color table.

=back







=head1 BUGS

box, arc, circle do not support antialiasing yet.  arc, is only filled
as of yet.  Some routines do not return $self where they should.  This
affects code like this, C<$img-E<gt>box()-E<gt>arc()> where an object
is expected.

When saving Gif images the program does NOT try to shave of extra
colors if it is possible.  If you specify 128 colors and there are
only 2 colors used - it will have a 128 colortable anyway.

=head1 AUTHOR

Arnar M. Hrafnkelsson, addi@umich.edu, and recently lots of assistance
from Tony Cook.  See the README for a complete list.

=head1 SEE ALSO

perl(1), Imager::Color(3), Imager::Font(3), Imager::Matrix2d(3),
Affix::Infix2Postfix(3), Parse::RecDescent(3) 
http://www.eecs.umich.edu/~addi/perl/Imager/

=cut