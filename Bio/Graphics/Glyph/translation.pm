package Bio::Graphics::Glyph::translation;

use strict;
use Bio::Graphics::Glyph::generic;
use Bio::Graphics::Util qw(frame_and_offset);
use vars '@ISA';
@ISA = qw(Bio::Graphics::Glyph::generic);

# turn off description
sub description { 0 }

# turn off label
# sub label { 1 }

sub height {
  my $self = shift;
  my $font = $self->font;
  my $lines = $self->translation_type eq '3frame' ? 3
            : $self->translation_type eq '6frame' ? 6
            : 1;
  return $self->protein_fits ? $lines*$font->height
       : $self->SUPER::height;
}

sub pixels_per_base {
  my $self = shift;
  return $self->scale;
}

sub pixels_per_residue {
  my $self = shift;
  return $self->scale * 3;
}

sub protein_fits {
  my $self = shift;

  my $pixels_per_base = $self->pixels_per_residue;
  my $font            = $self->font;
  my $font_width      = $font->width;

  return $pixels_per_base >= $font_width;
}

sub translation_type {
  my $self = shift;
  return $self->option('translation') || '1frame';
}

sub strand {
  my $self = shift;
  return $self->option('strand') || '+1';
}

sub draw_component {
  my $self = shift;
  my $gd = shift;
  my ($x1,$y1,$x2,$y2) = $self->bounds(@_);

  my $type   = $self->translation_type;
  my $strand = $self->strand;

  my @strands =  $type eq '6frame' ? (1,-1)
	       : $strand > 0       ? (1)
	       : -1;
  my @phase = (0,2,1);   # looks weird, but gives correct effect
  for my $s (@strands) {
    for (my $i=0; $i < @phase; $i++) {
      $self->draw_frame($self->feature,$s,$i,$phase[$i],$gd,$x1,$y1,$x2,$y2);
    }
  }

}

sub draw_frame {
  my $self = shift;
  my ($feature,$strand,$base_offset,$phase,$gd,$x1,$y1,$x2,$y2) = @_;
  my ($seq,$pos) = $strand < 0 ? ($feature->revcom,$feature->end) 
                               : ($feature,$feature->start);
  my ($frame,$offset) = frame_and_offset($pos,$strand,$phase);
  ($strand >= 0 ? $x1 : $x2) += $self->pixels_per_base * $offset;
  my $lh = $self->height / 3;
  $y1 += $lh * $frame;
  $y2 = $y1;

  my $protein = $seq->translate(undef,undef,$base_offset)->seq;
  my $color   = $self->color("frame$frame") || $self->fgcolor;
  if ($self->protein_fits) {
    $self->draw_protein(\$protein,$color,$gd,$x1,$y1,$x2,$y2);
  } else {
    $self->draw_orfs(\$protein,$color,$gd,$x1,$y1,$x2,$y2);
  }
}

sub draw_protein {
  my $self = shift;
  my ($protein,$color,$gd,$x1,$y1,$x2,$y2) = @_;
  my $pixels_per_base = $self->pixels_per_base;
  my $font   = $self->font;
  my $strand = $self->strand;

  my @residues = split '',$$protein;
  for (my $i=0;$i<@residues;$i++) {
    my $x = $strand > 0 
      ? $x1 + 3 * $i * $pixels_per_base
      : $x2 - 3 * $i * $pixels_per_base;
    $gd->char($font,$x,$y1,$residues[$i],$color);
  }
}

sub draw_orfs {
  my $self     = shift;
  my ($protein,$color,$gd,$x1,$y1,$x2,$y2) = @_;
  my $pixels_per_base = $self->pixels_per_base * 3;
  $y1++;

  my $strand   = $self->strand;

  my $stops = $self->find_stop_codons($protein);

  for my $stop (@$stops) {
      my $pos = $strand > 0 
	? $x1 + $stop * $pixels_per_base
        : $x2 - $stop * $pixels_per_base;
      $gd->line($pos,$y1-2,$pos,$y1+2,$color);
    }
  $gd->line($x1,$y1,$x2,$y1,$color);
  $strand > 0 ? $self->arrowhead($gd,$x2-1,$y1,3,+1)
              : $self->arrowhead($gd,$x1,$y1,3,-1)
}

sub find_stop_codons {
  my $self    = shift;
  my $protein = shift;
  my $pos = -1;
  my @stops;
  while ( ($pos = index($$protein,'*',$pos+1)) >= 0) {
    push @stops,$pos;
  }
  \@stops;
}

sub make_key_feature {
  my $self = shift;
  my $offset = $self->panel->offset;
  my $scale = 1/$self->scale;  # base pairs/pixel
  my $start = $offset;
  my $stop  = $offset + 100 * $scale;
  my $feature =
    Bio::Graphics::Feature->new(-start=> $start,
				-stop => $stop,
				-seq  => join('',map{qw(g a t c)[rand 4]} ($start..$stop)),
				-name => $self->option('key'),
				-strand => '+1',
			       );
  $feature;
}

1;

__END__

=head1 NAME

Bio::Graphics::Glyph::translation - The "6-frame translation" glyph

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph draws the conceptual translation of DNA sequences.  At high
magnifications, it simply draws lines indicating open reading frames.
At low magnifications, it draws a conceptual protein translation.
Options can be used to set 1-frame, 3-frame or 6-frame translations.

=head2 OPTIONS

The following options are standard among all Glyphs.  See
L<Bio::Graphics::Glyph> for a full explanation.

  Option      Description                      Default
  ------      -----------                      -------

  -fgcolor      Foreground color	       black

  -outlinecolor	Synonym for -fgcolor

  -bgcolor      Background color               turquoise

  -fillcolor    Synonym for -bgcolor

  -linewidth    Line width                     1

  -height       Height of glyph		       10

  -font         Glyph font		       gdSmallFont

  -connector    Connector type                 0 (false)

  -connector_color
                Connector color                black

  -label        Whether to draw a label	       0 (false)

  -description  Whether to draw a description  0 (false)

In addition to the common options, the following glyph-specific
options are recognized:

  Option        Description                 Default
  ------        -----------                 -------

  -translation  Type of translation to      1frame
                perform.  One of "1frame",
                "3frame", or "6frame"

  -strand       Forward (+1) or reverse (-1) +1
                translation.

  -frame0       Color for the first frame    fgcolor

  -frame1       Color for the second frame   fgcolor

  -frame2       Color for the third frame    fgcolor

=head1 SUGGESTED STANZA FOR GENOME BROWSER

This produces a nice gbrowse display in which the DNA/GC Content glyph
is sandwiched between the forward and reverse three-frame
translations.  The frames are color-coordinated with the example
configuration for the "cds" glyph.

 [TranslationF]
 glyph        = translation
 global feature = 1
 frame0       = cadetblue
 frame1       = blue
 frame2       = darkblue
 height       = 20
 fgcolor      = purple
 strand       = +1
 translation  = 3frame
 key          = 3-frame translation (forward)

 [DNA/GC Content]
 glyph        = dna
 global feature = 1
 height       = 40
 do_gc        = 1
 fgcolor      = red
 axis_color   = blue

 [TranslationR]
 glyph        = translation
 global feature = 1
 frame0       = darkred
 frame1       = red
 frame2       = crimson
 height       = 20
 fgcolor      = blue
 strand       = -1
 translation  = 3frame
 key          = 3-frame translation (reverse)

=head1 BUGS

Please report them.

=head1 SEE ALSO

L<Bio::Graphics::Panel>,
L<Bio::Graphics::Glyph::anchored_arrow>,
L<Bio::Graphics::Glyph::arrow>,
L<Bio::Graphics::Glyph::box>,
L<Bio::Graphics::Glyph::cds>,
L<Bio::Graphics::Glyph::dna>,
L<Bio::Graphics::Glyph::primers>,
L<Bio::Graphics::Glyph::segments>,
L<Bio::Graphics::Glyph::toomany>,
L<Bio::Graphics::Glyph::transcript>,

=head1 AUTHOR

Lincoln Stein E<lt>lstein@cshl.orgE<gt>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
