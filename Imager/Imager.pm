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

=head2 API

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

=head2 Obtaining/setting attributes of images

To get the size of an image in pixels the C<$img-E<gt>getwidth()> and
C<$img-E<gt>getheight()> are used.

To get the number of channels in
an image C<$img-E<gt>getchannels()> is used.  $img-E<gt>getmask() and
$img-E<gt>setmask() are used to get/set the channel mask of the image.

  $mask=$img->getmask();
  $img->setmask(mask=>1+2); # modify red and green only
  $img->setmask(mask=>8); # modify alpha only
  $img->setmask(mask=>$mask); # restore previous mask

The mask of an image describes which channels are updated when some
operation is performed on an image.  Naturally it is not possible to
apply masks to operations like scaling that alter the dimensions of
images.

It is possible to have Imager find the number of colors in an image
by using C<$img-E<gt>getcolorcount()>. It requires memory proportionally
to the number of colors in the image so it is possible to have it
stop sooner if you only need to know if there are more than a certain number
of colors in the image.  If there are more colors than asked for
the function return undef.  Examples:

  if (!defined($img->getcolorcount(maxcolors=>512)) {
    print "Less than 512 colors in image\n";
  }

The bits() method retrieves the number of bits used to represent each
channel in a pixel, 8 for a normal image, 16 for 16-bit image and
'double' for a double/channel image.  The type() method returns either
'direct' for truecolor images or 'paletted' for paletted images.  The
virtual() method returns non-zero if the image contains no actual
pixels, for example masked images.

=head2 Paletted Images

In general you can work with paletted images in the same way as RGB
images, except that if you attempt to draw to a paletted image with a
color that is not in the image's palette, the image will be converted
to an RGB image.  This means that drawing on a paletted image with
anti-aliasing enabled will almost certainly convert the image to RGB.

You can add colors to a paletted image with the addcolors() method:

   my @colors = ( Imager::Color->new(255, 0, 0), 
                  Imager::Color->new(0, 255, 0) );
   my $index = $img->addcolors(colors=>\@colors);

The return value is the index of the first color added, or undef if
adding the colors would overflow the palette.

Once you have colors in the palette you can overwrite them with the
setcolors() method:

  $img->setcolors(start=>$start, colors=>\@colors);

Returns true on success.

To retrieve existing colors from the palette use the getcolors() method:

  # get the whole palette
  my @colors = $img->getcolors();
  # get a single color
  my $color = $img->getcolors(start=>$index);
  # get a range of colors
  my @colors = $img->getcolors(start=>$index, count=>$count);

To quickly find a color in the palette use findcolor():

  my $index = $img->findcolor(color=>$color);

which returns undef on failure, or the index of the color.

You can get the current palette size with $img->colorcount, and the
maximum size of the palette with $img->maxcolors.

=head2 Drawing Methods

IMPLEMENTATION MORE OR LESS DONE CHECK THE TESTS
DOCUMENTATION OF THIS SECTION OUT OF SYNC

It is possible to draw with graphics primitives onto images.  Such
primitives include boxes, arcs, circles, polygons and lines.  A
reference oriented list follows.

Box:
  $img->box(color=>$blue,xmin=>10,ymin=>30,xmax=>200,ymax=>300,filled=>1);

The above example calls the C<box> method for the image and the box
covers the pixels with in the rectangle specified.  If C<filled> is
ommited it is drawn as an outline.  If any of the edges of the box are
ommited it will snap to the outer edge of the image in that direction.
Also if a color is omitted a color with (255,255,255,255) is used
instead.

Arc:
  $img->arc(color=>$red, r=20, x=>200, y=>100, d1=>10, d2=>20 );

This creates a filled red arc with a 'center' at (200, 100) and spans
10 degrees and the slice has a radius of 20. SEE section on BUGS.

Circle:
  $img->circle(color=>$green, r=50, x=>200, y=>100);

This creates a green circle with its center at (200, 100) and has a
radius of 20.

Line:
  $img->line(color=>$green, x1=>10, x2=>100,
                            y1=>20, y2=>50, aa=>1 );

That draws an antialiased line from (10,100) to (20,50).

The I<antialias> parameter is still available for backwards compatibility.

Polyline:
  $img->polyline(points=>[[$x0,$y0],[$x1,$y1],[$x2,$y2]],color=>$red);
  $img->polyline(x=>[$x0,$x1,$x2], y=>[$y0,$y1,$y2], aa=>1);

Polyline is used to draw multilple lines between a series of points.
The point set can either be specified as an arrayref to an array of
array references (where each such array represents a point).  The
other way is to specify two array references.

The I<antialias> parameter is still available for backwards compatibility.

Polygon:
  $img->polygon(points=>[[$x0,$y0],[$x1,$y1],[$x2,$y2]],color=>$red);
  $img->polygon(x=>[$x0,$x1,$x2], y=>[$y0,$y1,$y2]);

Polygon is used to draw a filled polygon.  Currently the polygon is
always drawn antialiased, although that will change in the future.
Like other antialiased drawing functions its coordinates can be
specified with floating point values.

Flood Fill:

You can fill a region that all has the same color using the
flood_fill() method, for example:

  $img->flood_fill(x=>50, y=>50, color=>$color);

will fill all regions the same color connected to the point (50, 50).

The arc(), box(), polygon() and flood_fill() methods can take a
C<fill> parameter which can either be an Imager::Fill object, or a
reference to a hash containing the parameters used to create the fill:

  $img->box(xmin=>10, ymin=>30, xmax=>150, ymax=>60,
            fill => { hatch=>'cross2' });
  use Imager::Fill;
  my $fill = Imager::Fill->new(hatch=>'stipple');
  $img->box(fill=>$fill);

Currently you can create opaque or transparent plain color fills,
hatched fills, image based fills and fountain fills.  See
L<Imager::Fill> for more information.

The C<color> parameter for any of the drawing methods can be an
L<Imager::Color> object, a simple scalar that Imager::Color can
understand, a hashref of parameters that Imager::Color->new
understands, or an arrayref of red, green, blue values.

=head2 Text rendering

Text rendering is described in the Imager::Font manpage.

=head2 Image resizing

To scale an image so porportions are maintained use the
C<$img-E<gt>scale()> method.  if you give either a xpixels or ypixels
parameter they will determine the width or height respectively.  If
both are given the one resulting in a larger image is used.  example:
C<$img> is 700 pixels wide and 500 pixels tall.

  $newimg = $img->scale(xpixels=>400); # 400x285
  $newimg = $img->scale(ypixels=>400); # 560x400

  $newimg = $img->scale(xpixels=>400,ypixels=>400); # 560x400
  $newimg = $img->scale(xpixels=>400,ypixels=>400,type=>min); # 400x285

  $newimg = $img->scale(scalefactor=>0.25); 175x125 
  $newimg = $img->scale(); # 350x250

if you want to create low quality previews of images you can pass
C<qtype=E<gt>'preview'> to scale and it will use nearest neighbor
sampling instead of filtering. It is much faster but also generates
worse looking images - especially if the original has a lot of sharp
variations and the scaled image is by more than 3-5 times smaller than
the original.

If you need to scale images per axis it is best to do it simply by
calling scaleX and scaleY.  You can pass either 'scalefactor' or
'pixels' to both functions.

Another way to resize an image size is to crop it.  The parameters
to crop are the edges of the area that you want in the returned image.
If a parameter is omited a default is used instead.

  $newimg = $img->crop(left=>50, right=>100, top=>10, bottom=>100); 
  $newimg = $img->crop(left=>50, top=>10, width=>50, height=>90);
  $newimg = $img->crop(left=>50, right=>100); # top 

You can also specify width and height parameters which will produce a
new image cropped from the center of the input image, with the given
width and height.

  $newimg = $img->crop(width=>50, height=>50);

The width and height parameters take precedence over the left/right
and top/bottom parameters respectively.

=head2 Copying images

To create a copy of an image use the C<copy()> method.  This is usefull
if you want to keep an original after doing something that changes the image
inplace like writing text.

  $img=$orig->copy();

To copy an image to onto another image use the C<paste()> method.

  $dest->paste(left=>40,top=>20,img=>$logo);

That copies the entire C<$logo> image onto the C<$dest> image so that the
upper left corner of the C<$logo> image is at (40,20).


=head2 Flipping images

An inplace horizontal or vertical flip is possible by calling the
C<flip()> method.  If the original is to be preserved it's possible to
make a copy first.  The only parameter it takes is the C<dir>
parameter which can take the values C<h>, C<v>, C<vh> and C<hv>.

  $img->flip(dir=>"h");       # horizontal flip
  $img->flip(dir=>"vh");      # vertical and horizontal flip
  $nimg = $img->copy->flip(dir=>"v"); # make a copy and flip it vertically

=head2 Rotating images

Use the rotate() method to rotate an image.  This method will return a
new, rotated image.

To rotate by an exact amount in degrees or radians, use the 'degrees'
or 'radians' parameter:

  my $rot20 = $img->rotate(degrees=>20);
  my $rotpi4 = $img->rotate(radians=>3.14159265/4);

Exact image rotation uses the same underlying transformation engine as
the matrix_transform() method.

To rotate in steps of 90 degrees, use the 'right' parameter:

  my $rotated = $img->rotate(right=>270);

Rotations are clockwise for positive values.

=head2 Blending Images

To put an image or a part of an image directly
into another it is best to call the C<paste()> method on the image you
want to add to.

  $img->paste(img=>$srcimage,left=>30,top=>50);

That will take paste C<$srcimage> into C<$img> with the upper
left corner at (30,50).  If no values are given for C<left>
or C<top> they will default to 0.

A more complicated way of blending images is where one image is
put 'over' the other with a certain amount of opaqueness.  The
method that does this is rubthrough.

  $img->rubthrough(src=>$srcimage,tx=>30,ty=>50);

That will take the image C<$srcimage> and overlay it with the upper
left corner at (30,50).  You can rub 2 or 4 channel images onto a 3
channel image, or a 2 channel image onto a 1 channel image.  The last
channel is used as an alpha channel.


=head2 Filters

A special image method is the filter method. An example is:

  $img->filter(type=>'autolevels');

This will call the autolevels filter.  Here is a list of the filters
that are always avaliable in Imager.  This list can be obtained by
running the C<filterlist.perl> script that comes with the module
source.

  Filter          Arguments
  autolevels      lsat(0.1) usat(0.1) skew(0)
  bumpmap         bump elevation(0) lightx lighty st(2)
  bumpmap_complex bump channel(0) tx(0) ty(0) Lx(0.2) Ly(0.4)
                  Lz(-1) cd(1.0) cs(40.0) n(1.3) Ia(0 0 0) Il(255 255 255)
                  Is(255 255 255)
  contrast        intensity
  conv            coef
  fountain        xa ya xb yb ftype(linear) repeat(none) combine(none)
                  super_sample(none) ssample_param(4) segments(see below)
  gaussian        stddev
  gradgen         xo yo colors dist
  hardinvert
  mosaic          size(20)
  noise           amount(3) subtype(0)
  postlevels      levels(10)
  radnoise        xo(100) yo(100) ascale(17.0) rscale(0.02)
  turbnoise       xo(0.0) yo(0.0) scale(10.0)
  unsharpmask     stddev(2.0) scale(1.0)
  watermark       wmark pixdiff(10) tx(0) ty(0)

The default values are in parenthesis.  All parameters must have some
value but if a parameter has a default value it may be omitted when
calling the filter function.

The filters are:

=over

=item autolevels

scales the value of each channel so that the values in the image will
cover the whole possible range for the channel.  I<lsat> and I<usat>
truncate the range by the specified fraction at the top and bottom of
the range respectivly..

=item bumpmap

uses the channel I<elevation> image I<bump> as a bumpmap on your
image, with the light at (I<lightx>, I<lightty>), with a shadow length
of I<st>.

=item bumpmap_complex

uses the channel I<channel> image I<bump> as a bumpmap on your image.
If Lz<0 the three L parameters are considered to be the direction of
the light.  If Lz>0 the L parameters are considered to be the light
position.  I<Ia> is the ambient colour, I<Il> is the light colour,
I<Is> is the color of specular highlights.  I<cd> is the diffuse
coefficient and I<cs> is the specular coefficient.  I<n> is the
shininess of the surface.

=item contrast

scales each channel by I<intensity>.  Values of I<intensity> < 1.0
will reduce the contrast.

=item conv

performs 2 1-dimensional convolutions on the image using the values
from I<coef>.  I<coef> should be have an odd length.

=item fountain

renders a fountain fill, similar to the gradient tool in most paint
software.  The default fill is a linear fill from opaque black to
opaque white.  The points A(xa, ya) and B(xb, yb) control the way the
fill is performed, depending on the ftype parameter:

=over

=item linear

the fill ramps from A through to B.

=item bilinear

the fill ramps in both directions from A, where AB defines the length
of the gradient.

=item radial

A is the center of a circle, and B is a point on it's circumference.
The fill ramps from the center out to the circumference.

=item radial_square

A is the center of a square and B is the center of one of it's sides.
This can be used to rotate the square.  The fill ramps out to the
edges of the square.

=item revolution

A is the centre of a circle and B is a point on it's circumference.  B
marks the 0 and 360 point on the circle, with the fill ramping
clockwise.

=item conical

A is the center of a circle and B is a point on it's circumference.  B
marks the 0 and point on the circle, with the fill ramping in both
directions to meet opposite.

=back

The I<repeat> option controls how the fill is repeated for some
I<ftype>s after it leaves the AB range:

=over

=item none

no repeats, points outside of each range are treated as if they were
on the extreme end of that range.

=item sawtooth

the fill simply repeats in the positive direction

=item triangle

the fill repeats in reverse and then forward and so on, in the
positive direction

=item saw_both

the fill repeats in both the positive and negative directions (only
meaningful for a linear fill).

=item tri_both

as for triangle, but in the negative direction too (only meaningful
for a linear fill).

=back

By default the fill simply overwrites the whole image (unless you have
parts of the range 0 through 1 that aren't covered by a segment), if
any segments of your fill have any transparency, you can set the
I<combine> option to 'normal' to have the fill combined with the
existing pixels.  See the description of I<combine> in L<Imager/Fill>.

If your fill has sharp edges, for example between steps if you use
repeat set to 'triangle', you may see some aliased or ragged edges.
You can enable super-sampling which will take extra samples within the
pixel in an attempt anti-alias the fill.

The possible values for the super_sample option are:

=over

=item none

no super-sampling is done

=item grid

a square grid of points are sampled.  The number of points sampled is
the square of ceil(0.5 + sqrt(ssample_param)).

=item random

a random set of points within the pixel are sampled.  This looks
pretty bad for low ssample_param values.  

=item circle

the points on the radius of a circle within the pixel are sampled.
This seems to produce the best results, but is fairly slow (for now).

=back

You can control the level of sampling by setting the ssample_param
option.  This is roughly the number of points sampled, but depends on
the type of sampling.

The segments option is an arrayref of segments.  You really should use
the Imager::Fountain class to build your fountain fill.  Each segment
is an array ref containing:

=over

=item start

a floating point number between 0 and 1, the start of the range of fill parameters covered by this segment.

=item middle

a floating point number between start and end which can be used to
push the color range towards one end of the segment.

=item end

a floating point number between 0 and 1, the end of the range of fill
parameters covered by this segment.  This should be greater than
start.

=item c0 

=item c1

The colors at each end of the segment.  These can be either
Imager::Color or Imager::Color::Float objects.

=item segment type

The type of segment, this controls the way the fill parameter varies
over the segment. 0 for linear, 1 for curved (unimplemented), 2 for
sine, 3 for sphere increasing, 4 for sphere decreasing.

=item color type

The way the color varies within the segment, 0 for simple RGB, 1 for
hue increasing and 2 for hue decreasing.

=back

Don't forgot to use Imager::Fountain instead of building your own.
Really.  It even loads GIMP gradient files.

=item gaussian

performs a gaussian blur of the image, using I<stddev> as the standard
deviation of the curve used to combine pixels, larger values give
bigger blurs.  For a definition of Gaussian Blur, see:

  http://www.maths.abdn.ac.uk/~igc/tch/mx4002/notes/node99.html

=item gradgen

renders a gradient, with the given I<colors> at the corresponding
points (x,y) in I<xo> and I<yo>.  You can specify the way distance is
measured for color blendeing by setting I<dist> to 0 for Euclidean, 1
for Euclidean squared, and 2 for Manhattan distance.

=item hardinvert

inverts the image, black to white, white to black.  All channels are
inverted, including the alpha channel if any.

=item mosaic

produces averaged tiles of the given I<size>.

=item noise

adds noise of the given I<amount> to the image.  If I<subtype> is
zero, the noise is even to each channel, otherwise noise is added to
each channel independently.

=item radnoise

renders radiant Perlin turbulent noise.  The centre of the noise is at
(I<xo>, I<yo>), I<ascale> controls the angular scale of the noise ,
and I<rscale> the radial scale, higher numbers give more detail.

=item postlevels

alters the image to have only I<levels> distinct level in each
channel.

=item turbnoise

renders Perlin turbulent noise.  (I<xo>, I<yo>) controls the origin of
the noise, and I<scale> the scale of the noise, with lower numbers
giving more detail.

=item unsharpmask

performs an unsharp mask on the image.  This is the result of
subtracting a gaussian blurred version of the image from the original.
I<stddev> controls the stddev parameter of the gaussian blur.  Each
output pixel is: in + I<scale> * (in - blurred).

=item watermark

applies I<wmark> as a watermark on the image with strength I<pixdiff>,
with an origin at (I<tx>, I<ty>)

=back

A demonstration of most of the filters can be found at:

  http://www.develop-help.com/imager/filters.html

(This is a slow link.)

=head2 Color transformations

You can use the convert method to transform the color space of an
image using a matrix.  For ease of use some presets are provided.

The convert method can be used to:

=over 4

=item *

convert an RGB or RGBA image to grayscale.

=item *

convert a grayscale image to RGB.

=item *

extract a single channel from an image.

=item *

set a given channel to a particular value (or from another channel)

=back

The currently defined presets are:

=over

=item gray

=item grey

converts an RGBA image into a grayscale image with alpha channel, or
an RGB image into a grayscale image without an alpha channel.

This weights the RGB channels at 22.2%, 70.7% and 7.1% respectively.

=item noalpha

removes the alpha channel from a 2 or 4 channel image.  An identity
for other images.

=item red

=item channel0

extracts the first channel of the image into a single channel image

=item green

=item channel1

extracts the second channel of the image into a single channel image

=item blue

=item channel2

extracts the third channel of the image into a single channel image

=item alpha

extracts the alpha channel of the image into a single channel image.

If the image has 1 or 3 channels (assumed to be grayscale of RGB) then
the resulting image will be all white.

=item rgb

converts a grayscale image to RGB, preserving the alpha channel if any

=item addalpha

adds an alpha channel to a grayscale or RGB image.  Preserves an
existing alpha channel for a 2 or 4 channel image.

=back

For example, to convert an RGB image into a greyscale image:

  $new = $img->convert(preset=>'grey'); # or gray

or to convert a grayscale image to an RGB image:

  $new = $img->convert(preset=>'rgb');

The presets aren't necessary simple constants in the code, some are
generated based on the number of channels in the input image.

If you want to perform some other colour transformation, you can use
the 'matrix' parameter.

For each output pixel the following matrix multiplication is done:

     channel[0]       [ [ $c00, $c01, ...  ]        inchannel[0]
   [     ...      ] =          ...              x [     ...        ]
     channel[n-1]       [ $cn0, ...,  $cnn ] ]      inchannel[max]
                                                          1

So if you want to swap the red and green channels on a 3 channel image:

  $new = $img->convert(matrix=>[ [ 0, 1, 0 ],
                                 [ 1, 0, 0 ],
                                 [ 0, 0, 1 ] ]);

or to convert a 3 channel image to greyscale using equal weightings:

  $new = $img->convert(matrix=>[ [ 0.333, 0.333, 0.334 ] ])

=head2 Color Mappings

You can use the map method to map the values of each channel of an
image independently using a list of lookup tables.  It's important to
realize that the modification is made inplace.  The function simply
returns the input image again or undef on failure.

Each channel is mapped independently through a lookup table with 256
entries.  The elements in the table should not be less than 0 and not
greater than 255.  If they are out of the 0..255 range they are
clamped to the range.  If a table does not contain 256 entries it is
silently ignored.

Single channels can mapped by specifying their name and the mapping
table.  The channel names are C<red>, C<green>, C<blue>, C<alpha>.

  @map = map { int( $_/2 } 0..255;
  $img->map( red=>\@map );

It is also possible to specify a single map that is applied to all
channels, alpha channel included.  For example this applies a gamma
correction with a gamma of 1.4 to the input image.

  $gamma = 1.4;
  @map = map { int( 0.5 + 255*($_/255)**$gamma ) } 0..255;
  $img->map(all=> \@map);

The C<all> map is used as a default channel, if no other map is
specified for a channel then the C<all> map is used instead.  If we
had not wanted to apply gamma to the alpha channel we would have used:

  $img->map(all=> \@map, alpha=>[]);

Since C<[]> contains fewer than 256 element the gamma channel is
unaffected.

It is also possible to simply specify an array of maps that are
applied to the images in the rgba order.  For example to apply
maps to the C<red> and C<blue> channels one would use:

  $img->map(maps=>[\@redmap, [], \@bluemap]);



=head2 Transformations

Another special image method is transform.  It can be used to generate
warps and rotations and such features.  It can be given the operations
in postfix notation or the module Affix::Infix2Postfix can be used.
Look in the test case t/t55trans.t for an example.

transform() needs expressions (or opcodes) that determine the source
pixel for each target pixel.  Source expressions are infix expressions
using any of the +, -, *, / or ** binary operators, the - unary
operator, ( and ) for grouping and the sin() and cos() functions.  The
target pixel is input as the variables x and y.

You specify the x and y expressions as xexpr and yexpr respectively.
You can also specify opcodes directly, but that's magic deep enough
that you can look at the source code.

You can still use the transform() function, but the transform2()
function is just as fast and is more likely to be enhanced and
maintained.

Later versions of Imager also support a transform2() class method
which allows you perform a more general set of operations, rather than
just specifying a spatial transformation as with the transform()
method, you can also perform colour transformations, image synthesis
and image combinations.

transform2() takes an reference to an options hash, and a list of
images to operate one (this list may be empty):

  my %opts;
  my @imgs;
  ...
  my $img = Imager::transform2(\%opts, @imgs)
      or die "transform2 failed: $Imager::ERRSTR";

The options hash may define a transformation function, and optionally:

=over 4

=item *

width - the width of the image in pixels.  If this isn't supplied the
width of the first input image is used.  If there are no input images
an error occurs.

=item *

height - the height of the image in pixels.  If this isn't supplied
the height of the first input image is used.  If there are no input
images an error occurs.

=item *

constants - a reference to hash of constants to define for the
expression engine.  Some extra constants are defined by Imager

=back

The tranformation function is specified using either the expr or
rpnexpr member of the options.

=over 4

=item Infix expressions

You can supply infix expressions to transform 2 with the expr keyword.

$opts{expr} = 'return getp1(w-x, h-y)'

The 'expression' supplied follows this general grammar:

   ( identifier '=' expr ';' )* 'return' expr

This allows you to simplify your expressions using variables.

A more complex example might be:

$opts{expr} = 'pix = getp1(x,y); return if(value(pix)>0.8,pix*0.8,pix)'

Currently to use infix expressions you must have the Parse::RecDescent
module installed (available from CPAN).  There is also what might be a
significant delay the first time you run the infix expression parser
due to the compilation of the expression grammar.

=item Postfix expressions

You can supply postfix or reverse-polish notation expressions to
transform2() through the rpnexpr keyword.

The parser for rpnexpr emulates a stack machine, so operators will
expect to see their parameters on top of the stack.  A stack machine
isn't actually used during the image transformation itself.

You can store the value at the top of the stack in a variable called
foo using !foo and retrieve that value again using @foo.  The !foo
notation will pop the value from the stack.

An example equivalent to the infix expression above:

 $opts{rpnexpr} = 'x y getp1 !pix @pix value 0.8 gt @pix 0.8 * @pix ifp'

=back

transform2() has a fairly rich range of operators.

=over 4

=item +, *, -, /, %, **

multiplication, addition, subtraction, division, remainder and
exponentiation.  Multiplication, addition and subtraction can be used
on colour values too - though you need to be careful - adding 2 white
values together and multiplying by 0.5 will give you grey, not white.

Division by zero (or a small number) just results in a large number.
Modulo zero (or a small number) results in zero.

=item sin(N), cos(N), atan2(y,x)

Some basic trig functions.  They work in radians, so you can't just
use the hue values.

=item distance(x1, y1, x2, y2)

Find the distance between two points.  This is handy (along with
atan2()) for producing circular effects.

=item sqrt(n)

Find the square root.  I haven't had much use for this since adding
the distance() function.

=item abs(n)

Find the absolute value.

=item getp1(x,y), getp2(x,y), getp3(x, y)

Get the pixel at position (x,y) from the first, second or third image
respectively.  I may add a getpn() function at some point, but this
prevents static checking of the instructions against the number of
images actually passed in.

=item value(c), hue(c), sat(c), hsv(h,s,v)

Separates a colour value into it's value (brightness), hue (colour)
and saturation elements.  Use hsv() to put them back together (after
suitable manipulation).

=item red(c), green(c), blue(c), rgb(r,g,b)

Separates a colour value into it's red, green and blue colours.  Use
rgb(r,g,b) to put it back together.

=item int(n)

Convert a value to an integer.  Uses a C int cast, so it may break on
large values.

=item if(cond,ntrue,nfalse), if(cond,ctrue,cfalse)

A simple (and inefficient) if function.

=item <=,<,==,>=,>,!=

Relational operators (typically used with if()).  Since we're working
with floating point values the equalities are 'near equalities' - an
epsilon value is used.

=item &&, ||, not(n)

Basic logical operators.

=back

A few examples:

=over 4

=item rpnexpr=>'x 25 % 15 * y 35 % 10 * getp1 !pat x y getp1 !pix @pix sat 0.7 gt @pat @pix ifp'

tiles a smaller version of the input image over itself where the
colour has a saturation over 0.7.

=item rpnexpr=>'x 25 % 15 * y 35 % 10 * getp1 !pat y 360 / !rat x y getp1 1 @rat - pmult @pat @rat pmult padd'

tiles the input image over itself so that at the top of the image the
full-size image is at full strength and at the bottom the tiling is
most visible.

=item rpnexpr=>'x y getp1 !pix @pix value 0.96 gt @pix sat 0.1 lt and 128 128 255 rgb @pix ifp'

replace pixels that are white or almost white with a palish blue

=item rpnexpr=>'x 35 % 10 * y 45 % 8 * getp1 !pat x y getp1 !pix @pix sat 0.2 lt @pix value 0.9 gt and @pix @pat @pix value 2 / 0.5 + pmult ifp'

Tiles the input image overitself where the image isn't white or almost
white.

=item rpnexpr=>'x y 160 180 distance !d y 180 - x 160 - atan2 !a @d 10 / @a + 3.1416 2 * % !a2 @a2 180 * 3.1416 / 1 @a2 sin 1 + 2 / hsv'

Produces a spiral.

=item rpnexpr=>'x y 160 180 distance !d y 180 - x 160 - atan2 !a @d 10 / @a + 3.1416 2 * % !a2 @a 180 * 3.1416 / 1 @a2 sin 1 + 2 / hsv'

A spiral built on top of a colour wheel.

=back

For details on expression parsing see L<Imager::Expr>.  For details on
the virtual machine used to transform the images, see
L<Imager::regmach.pod>.

=head2 Matrix Transformations

Rather than having to write code in a little language, you can use a
matrix to perform transformations, using the matrix_transform()
method:

  my $im2 = $im->matrix_transform(matrix=>[ -1, 0, $im->getwidth-1,
                                            0,  1, 0,
                                            0,  0, 1 ]);

By default the output image will be the same size as the input image,
but you can supply the xsize and ysize parameters to change the size.

Rather than building matrices by hand you can use the Imager::Matrix2d
module to build the matrices.  This class has methods to allow you to
scale, shear, rotate, translate and reflect, and you can combine these
with an overloaded multiplication operator.

WARNING: the matrix you provide in the matrix operator transforms the
co-ordinates within the B<destination> image to the co-ordinates
within the I<source> image.  This can be confusing.

Since Imager has 3 different fairly general ways of transforming an
image spatially, this method also has a yatf() alias.  Yet Another
Transformation Function.

=head2 Masked Images

Masked images let you control which pixels are modified in an
underlying image.  Where the first channel is completely black in the
mask image, writes to the underlying image are ignored.

For example, given a base image called $img:

  my $mask = Imager->new(xsize=>$img->getwidth, ysize=>getheight,
                         channels=>1);
  # ... draw something on the mask
  my $maskedimg = $img->masked(mask=>$mask);

You can specifiy the region of the underlying image that is masked
using the left, top, right and bottom options.

If you just want a subset of the image, without masking, just specify
the region without specifying a mask.

=head2 Plugins

It is possible to add filters to the module without recompiling the
module itself.  This is done by using DSOs (Dynamic shared object)
avaliable on most systems.  This way you can maintain our own filters
and not have to get me to add it, or worse patch every new version of
the Module.  Modules can be loaded AND UNLOADED at runtime.  This
means that you can have a server/daemon thingy that can do something
like:

  load_plugin("dynfilt/dyntest.so")  || die "unable to load plugin\n";
  %hsh=(a=>35,b=>200,type=>lin_stretch);
  $img->filter(%hsh);
  unload_plugin("dynfilt/dyntest.so") || die "unable to load plugin\n";
  $img->write(type=>'pnm',file=>'testout/t60.jpg')
    || die "error in write()\n";

Someone decides that the filter is not working as it should -
dyntest.c modified and recompiled.

  load_plugin("dynfilt/dyntest.so") || die "unable to load plugin\n";
  $img->filter(%hsh);

An example plugin comes with the module - Please send feedback to
addi@umich.edu if you test this.

Note: This seems to test ok on the following systems:
Linux, Solaris, HPUX, OpenBSD, FreeBSD, TRU64/OSF1, AIX.
If you test this on other systems please let me know.

=head2 Tags

Image tags contain meta-data about the image, ie. information not
stored as pixels of the image.

At the perl level each tag has a name or code and a value, which is an
integer or an arbitrary string.  An image can contain more than one
tag with the same name or code.

You can retrieve tags from an image using the tags() method, you can
get all of the tags in an image, as a list of array references, with
the code or name of the tag followed by the value of the tag:

  my @alltags = $img->tags;

or you can get all tags that have a given name:

  my @namedtags = $img->tags(name=>$name);

or a given code:

  my @tags = $img->tags(code=>$code);

You can add tags using the addtag() method, either by name:

  my $index = $img->addtag(name=>$name, value=>$value);

or by code:

  my $index = $img->addtag(code=>$code, value=>$value);

You can remove tags with the deltag() method, either by index:

  $img->deltag(index=>$index);

or by name:

  $img->deltag(name=>$name);

or by code:

  $img->deltag(code=>$code);

In each case deltag() returns the number of tags deleted.

When you read a GIF image using read_multi(), each image can include
the following tags:

=over

=item gif_left

the offset of the image from the left of the "screen" ("Image Left
Position")

=item gif_top

the offset of the image from the top of the "screen" ("Image Top Position")

=item gif_interlace

non-zero if the image was interlaced ("Interlace Flag")

=item gif_screen_width

=item gif_screen_height

the size of the logical screen ("Logical Screen Width", 
"Logical Screen Height")

=item gif_local_map

Non-zero if this image had a local color map.

=item gif_background

The index in the global colormap of the logical screen's background
color.  This is only set if the current image uses the global
colormap.

=item gif_trans_index

The index of the color in the colormap used for transparency.  If the
image has a transparency then it is returned as a 4 channel image with
the alpha set to zero in this palette entry. ("Transparent Color Index")

=item gif_delay

The delay until the next frame is displayed, in 1/100 of a second. 
("Delay Time").

=item gif_user_input

whether or not a user input is expected before continuing (view dependent) 
("User Input Flag").

=item gif_disposal

how the next frame is displayed ("Disposal Method")

=item gif_loop

the number of loops from the Netscape Loop extension.  This may be zero.

=item gif_comment

the first block of the first gif comment before each image.

=back

Where applicable, the ("name") is the name of that field from the GIF89 
standard.

The following tags are set in a TIFF image when read, and can be set
to control output:

=over

=item tiff_resolutionunit

The value of the ResolutionUnit tag.  This is ignored on writing if
the i_aspect_only tag is non-zero.

=item tiff_documentname

=item tiff_imagedescription

=item tiff_make

=item tiff_model

=item tiff_pagename

=item tiff_software

=item tiff_datetime

=item tiff_artist

=item tiff_hostcomputer

Various strings describing the image.  tiff_datetime must be formatted
as "YYYY:MM:DD HH:MM:SS".  These correspond directly to the mixed case
names in the TIFF specification.  These are set in images read from a
TIFF and save when writing a TIFF image.

=back

The following tags are set when a Windows BMP file is read:

=over

=item bmp_compression

The type of compression, if any.

=item bmp_important_colors

The number of important colors as defined by the writer of the image.

=back

Some standard tags will be implemented as time goes by:

=over

=item i_xres

=item i_yres

The spatial resolution of the image in pixels per inch.  If the image
format uses a different scale, eg. pixels per meter, then this value
is converted.  A floating point number stored as a string.

=item i_aspect_only

If this is non-zero then the values in i_xres and i_yres are treated
as a ratio only.  If the image format does not support aspect ratios
then this is scaled so the smaller value is 72dpi.

=item i_incomplete

If this tag is present then the whole image could not be read.  This
isn't implemented for all images yet.

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