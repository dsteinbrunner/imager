package Imager::Font::Truetype;
use strict;
use vars qw(@ISA);
@ISA = qw(Imager::Font);

sub new {
  my $class = shift;
  my %hsh=(color=>Imager::Color->new(255,0,0,0),
	   size=>15,
	   @_);

  unless ($hsh{file}) {
    $Imager::ERRSTR = "No font file specified";
    return;
  }
  unless (-e $hsh{file}) {
    $Imager::ERRSTR = "Font file $hsh{file} not found";
    return;
  }
  unless ($Imager::formats{tt}) {
    $Imager::ERRSTR = "Type 1 fonts not supported in this build";
    return;
  }
  my $id = Imager::i_tt_new($hsh{file});
  unless ($id >= 0) { # the low-level code may miss some error handling
    $Imager::ERRSTR = "Could not load font ($id)";
    return;
  }
  return bless {
		id    => $id,
		aa    => $hsh{aa} || 0,
		file  => $hsh{file},
		type  => 'tt',
		size  => $hsh{size},
		color => $hsh{color},
	       }, $class;
}

sub _draw {
  my $self = shift;
  my %input = @_;
  if ( exists $input{channel} ) {
    Imager::i_tt_cp($self->{id},$input{image}{IMG},
		    $input{'x'}, $input{'y'}, $input{channel}, $input{size},
		    $input{string}, length($input{string}),$input{aa}); 
  } else {
    Imager::i_tt_text($self->{id}, $input{image}{IMG}, 
		      $input{'x'}, $input{'y'}, $input{color},
		      $input{size}, $input{string}, 
		      length($input{string}), $input{aa}); 
  }
}

sub _bounding_box {
  my $self = shift;
  my %input = @_;
  return Imager::i_tt_bbox($self->{id}, $input{size},
			   $input{string}, length($input{string}));
}

1;

__END__

=head1 NAME

  Imager::Font::Truetype - low-level functions for Truetype fonts

=head1 DESCRIPTION

Imager::Font creates a Imager::Font::Truetype object when asked to create
a font object based on a .ttf file.

See Imager::Font to see how to use this type.

This class provides low-level functions that require the caller to
perform data validation.

=head1 AUTHOR

Addi, Tony

=cut